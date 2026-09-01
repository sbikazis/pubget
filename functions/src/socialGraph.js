"use strict";

const RESPECT_MIN = 0;
const RESPECT_MAX = 7;
const FAN_THRESHOLD = 5;
const ACTION_COOLDOWN_MS = 3000;

function validUid(value) {
  return typeof value === "string" &&
    value.trim().length > 0 &&
    value.trim().length <= 128 &&
    !value.includes("/");
}

function pairId(userId, otherUserId) {
  const [userA, userB] = [userId, otherUserId].sort();
  return `${userA.length}:${userA}${userB.length}:${userB}`;
}

function respectId(fromUserId, toUserId) {
  return `${fromUserId.length}:${fromUserId}${toUserId.length}:${toUserId}`;
}

function legacyPairId(userId, otherUserId) {
  return [userId, otherUserId].sort().join("_");
}

function legacyRespectId(fromUserId, toUserId) {
  return `${fromUserId}_${toUserId}`;
}

function matchesLegacyRespect(data, fromUserId, toUserId) {
  return Boolean(data) &&
    data.fromUserId === fromUserId &&
    data.toUserId === toUserId;
}

function matchesLegacyFriendship(data, userA, userB) {
  return Boolean(data) &&
    data.userA === userA &&
    data.userB === userB;
}

function createSocialGraph({ db, FieldValue, HttpsError }) {
  function authenticated(request) {
    if (!request || !request.auth || !validUid(request.auth.uid)) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    return request.auth.uid;
  }

  function targetFrom(request, key) {
    const value = request.data && request.data[key];
    if (!validUid(value)) {
      throw new HttpsError("invalid-argument", `${key} is invalid.`);
    }
    return value.trim();
  }

  function preventSelf(uid, otherUserId) {
    if (uid === otherUserId) {
      throw new HttpsError("invalid-argument", "You cannot target yourself.");
    }
  }

  async function requireUsers(transaction, userIds) {
    const snapshots = await Promise.all(
      userIds.map((uid) => transaction.get(db.collection("users").doc(uid))),
    );
    if (snapshots.some((snapshot) => !snapshot.exists)) {
      throw new HttpsError("not-found", "One of the profiles no longer exists.");
    }
    return snapshots;
  }

  async function enforceCooldown(transaction, uid, action) {
    const ref = db.collection("social_rate_limits").doc(`${uid}_${action}`);
    const snapshot = await transaction.get(ref);
    const lastActionAt = snapshot.data() && snapshot.data().lastActionAt;
    const lastMillis = lastActionAt && typeof lastActionAt.toMillis === "function"
      ? lastActionAt.toMillis()
      : 0;
    if (lastMillis > 0 && Date.now() - lastMillis < ACTION_COOLDOWN_MS) {
      throw new HttpsError(
        "resource-exhausted",
        "Please wait a moment before trying again.",
      );
    }
    return ref;
  }

  async function giveRespect(request) {
    const uid = authenticated(request);
    const toUserId = targetFrom(request, "toUserId");
    preventSelf(uid, toUserId);
    const value = request.data && request.data.value;
    if (!Number.isInteger(value) || value < RESPECT_MIN || value > RESPECT_MAX) {
      throw new HttpsError(
        "invalid-argument",
        `value must be an integer from ${RESPECT_MIN} to ${RESPECT_MAX}.`,
      );
    }

    const relationRef = db.collection("respects").doc(respectId(uid, toUserId));
    const legacyRef = db.collection("respects")
      .doc(legacyRespectId(uid, toUserId));
    const targetRef = db.collection("users").doc(toUserId);
    await db.runTransaction(async (transaction) => {
      const [relation, legacy, users, cooldownRef] = await Promise.all([
        transaction.get(relationRef),
        transaction.get(legacyRef),
        requireUsers(transaction, [uid, toUserId]),
        enforceCooldown(transaction, uid, "respect"),
      ]);
      const matchingLegacy = legacy.exists &&
          matchesLegacyRespect(legacy.data(), uid, toUserId)
        ? legacy
        : null;
      const oldValues = [relation, matchingLegacy]
        .filter(Boolean)
        .filter((snapshot) => snapshot.exists)
        .map((snapshot) => snapshot.data().value)
        .filter(Number.isInteger);
      const oldValue = oldValues.reduce((sum, item) => sum + item, 0);
      const target = users[1].data() || {};
      const currentTotal = Number.isInteger(target.totalRespect)
        ? target.totalRespect
        : 0;
      const currentFans = Number.isInteger(target.fansCount)
        ? target.fansCount
        : 0;
      const totalRespect = Math.max(0, currentTotal - oldValue + value);
      const previousFans = oldValues.filter(
        (item) => item >= FAN_THRESHOLD,
      ).length;
      const isFan = value >= FAN_THRESHOLD;
      const fansCount = Math.max(
        0,
        currentFans + (isFan ? 1 : 0) - previousFans,
      );

      transaction.set(relationRef, {
        fromUserId: uid,
        toUserId,
        value,
        createdAt: relation.exists
          ? relation.data().createdAt
          : matchingLegacy
            ? matchingLegacy.data().createdAt
            : FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (matchingLegacy) transaction.delete(legacyRef);
      transaction.set(cooldownRef, {
        uid,
        action: "respect",
        lastActionAt: FieldValue.serverTimestamp(),
      });
      transaction.update(targetRef, { totalRespect, fansCount });
    });
    return { ok: true, value };
  }

  async function sendFriendRequest(request) {
    const uid = authenticated(request);
    const toUserId = targetFrom(request, "toUserId");
    preventSelf(uid, toUserId);
    const [userA, userB] = [uid, toUserId].sort();
    const relationRef = db.collection("friendships").doc(pairId(uid, toUserId));
    const legacyRef = db.collection("friendships")
      .doc(legacyPairId(uid, toUserId));

    const outcome = await db.runTransaction(async (transaction) => {
      const [relation, legacy, , cooldownRef] = await Promise.all([
        transaction.get(relationRef),
        transaction.get(legacyRef),
        requireUsers(transaction, [uid, toUserId]),
        enforceCooldown(transaction, uid, "friend"),
      ]);
      const matchingLegacy = legacy.exists &&
          matchesLegacyFriendship(legacy.data(), userA, userB)
        ? legacy
        : null;
      const existing = relation.exists ? relation : matchingLegacy;
      if (existing.exists) {
        const existingData = existing.data();
        const status = existingData.status;
        if (status === "blocked") {
          throw new HttpsError("permission-denied", "This relationship is blocked.");
        }
        if (matchingLegacy) {
          transaction.set(relationRef, {
            ...existingData,
            userA,
            userB,
            userIds: [userA, userB],
          });
          transaction.delete(legacyRef);
        }
        return { alreadyExists: true, status };
      }
      transaction.create(relationRef, {
        userA,
        userB,
        userIds: [userA, userB],
        status: "pending",
        requestedBy: uid,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(cooldownRef, {
        uid,
        action: "friend",
        lastActionAt: FieldValue.serverTimestamp(),
      });
      return { alreadyExists: false, status: "pending" };
    });
    return { ok: true, ...outcome };
  }

  async function respondToFriendRequest(request) {
    const uid = authenticated(request);
    const otherUserId = targetFrom(request, "otherUserId");
    preventSelf(uid, otherUserId);
    const response = request.data && request.data.response;
    if (response !== "accept" && response !== "reject") {
      throw new HttpsError(
        "invalid-argument",
        "response must be accept or reject.",
      );
    }
    const relationRef = db.collection("friendships").doc(pairId(uid, otherUserId));
    const legacyRef = db.collection("friendships")
      .doc(legacyPairId(uid, otherUserId));
    await db.runTransaction(async (transaction) => {
      const [relation, legacy] = await Promise.all([
        transaction.get(relationRef),
        transaction.get(legacyRef),
      ]);
      const [userA, userB] = [uid, otherUserId].sort();
      const matchingLegacy = legacy.exists &&
          matchesLegacyFriendship(legacy.data(), userA, userB)
        ? legacy
        : null;
      const existing = relation.exists ? relation : matchingLegacy;
      if (!existing.exists || existing.data().status !== "pending") {
        throw new HttpsError("not-found", "The friend request is no longer pending.");
      }
      if (existing.data().requestedBy === uid) {
        if (response === "reject") {
          transaction.delete(relationRef);
          if (matchingLegacy) transaction.delete(legacyRef);
          return;
        }
        throw new HttpsError(
          "permission-denied",
          "Only the recipient can accept this request.",
        );
      }
      const data = existing.data();
      const participants = data.userIds || [data.userA, data.userB];
      if (!participants.includes(uid)) {
        throw new HttpsError("permission-denied", "This request is not yours.");
      }
      if (response === "reject") {
        transaction.delete(relationRef);
        if (matchingLegacy) transaction.delete(legacyRef);
      } else {
        transaction.set(relationRef, {
          ...data,
          userIds: [data.userA, data.userB],
          status: "accepted",
          updatedAt: FieldValue.serverTimestamp(),
        });
        if (matchingLegacy) transaction.delete(legacyRef);
      }
    });
    return { ok: true };
  }

  async function removeFriend(request) {
    const uid = authenticated(request);
    const otherUserId = targetFrom(request, "otherUserId");
    preventSelf(uid, otherUserId);
    const relationRef = db.collection("friendships").doc(pairId(uid, otherUserId));
    const legacyRef = db.collection("friendships")
      .doc(legacyPairId(uid, otherUserId));
    await db.runTransaction(async (transaction) => {
      const [relation, legacy] = await Promise.all([
        transaction.get(relationRef),
        transaction.get(legacyRef),
      ]);
      const [userA, userB] = [uid, otherUserId].sort();
      const matchingLegacy = legacy.exists &&
          matchesLegacyFriendship(legacy.data(), userA, userB)
        ? legacy
        : null;
      const existing = relation.exists ? relation : matchingLegacy;
      if (!existing.exists) {
        return;
      }
      const data = existing.data();
      const participants = data.userIds || [data.userA, data.userB];
      if (!participants.includes(uid)) return;
      if (data.status === "blocked") {
        throw new HttpsError(
          "failed-precondition",
          "Unblock this user before removing the relationship.",
        );
      }
      transaction.delete(relationRef);
      if (matchingLegacy) transaction.delete(legacyRef);
    });
    return { ok: true };
  }

  async function blockUser(request) {
    const uid = authenticated(request);
    const otherUserId = targetFrom(request, "otherUserId");
    preventSelf(uid, otherUserId);
    const [userA, userB] = [uid, otherUserId].sort();
    const relationRef = db.collection("friendships").doc(pairId(uid, otherUserId));
    const legacyRef = db.collection("friendships")
      .doc(legacyPairId(uid, otherUserId));
    await db.runTransaction(async (transaction) => {
      await requireUsers(transaction, [uid, otherUserId]);
      const [relation, legacy] = await Promise.all([
        transaction.get(relationRef),
        transaction.get(legacyRef),
      ]);
      const matchingLegacy = legacy.exists &&
          matchesLegacyFriendship(legacy.data(), userA, userB)
        ? legacy
        : null;
      const existing = relation.exists ? relation : matchingLegacy;
      if (existing.exists &&
          existing.data().status === "blocked" &&
          existing.data().blockedBy !== uid) {
        throw new HttpsError(
          "permission-denied",
          "The other user has blocked this relationship.",
        );
      }
      transaction.set(relationRef, {
        userA,
        userB,
        userIds: [userA, userB],
        status: "blocked",
        requestedBy: existing.exists ? existing.data().requestedBy : uid,
        blockedBy: uid,
        createdAt: existing.exists
          ? existing.data().createdAt
          : FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (matchingLegacy) transaction.delete(legacyRef);
    });
    return { ok: true };
  }

  async function unblockUser(request) {
    const uid = authenticated(request);
    const otherUserId = targetFrom(request, "otherUserId");
    preventSelf(uid, otherUserId);
    const relationRef = db.collection("friendships").doc(pairId(uid, otherUserId));
    const legacyRef = db.collection("friendships")
      .doc(legacyPairId(uid, otherUserId));
    await db.runTransaction(async (transaction) => {
      const [relation, legacy] = await Promise.all([
        transaction.get(relationRef),
        transaction.get(legacyRef),
      ]);
      const [userA, userB] = [uid, otherUserId].sort();
      const matchingLegacy = legacy.exists &&
          matchesLegacyFriendship(legacy.data(), userA, userB)
        ? legacy
        : null;
      const existing = relation.exists ? relation : matchingLegacy;
      if (!existing.exists || existing.data().status !== "blocked") return;
      if (existing.data().blockedBy !== uid) {
        throw new HttpsError(
          "permission-denied",
          "Only the blocker can unblock this relationship.",
        );
      }
      transaction.delete(relationRef);
      if (matchingLegacy) transaction.delete(legacyRef);
    });
    return { ok: true };
  }

  return {
    giveRespect,
    sendFriendRequest,
    respondToFriendRequest,
    removeFriend,
    blockUser,
    unblockUser,
  };
}

module.exports = {
  ACTION_COOLDOWN_MS,
  FAN_THRESHOLD,
  RESPECT_MAX,
  RESPECT_MIN,
  createSocialGraph,
  legacyPairId,
  legacyRespectId,
  matchesLegacyFriendship,
  matchesLegacyRespect,
  pairId,
  respectId,
  validUid,
};