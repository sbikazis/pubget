"use strict";

function createNotificationCallables({ db, FieldValue, HttpsError }) {
  function counterField(type) {
    if (type === "group_message") return "unreadGroupsCount";
    if (type === "private_message") return "unreadPrivateMessagesCount";
    if (type === "mention") return "unreadMentionsCount";
    return null;
  }
  function auth(request) {
    if (!request.auth || typeof request.auth.uid !== "string") {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    return request.auth.uid;
  }

  function notificationRef(uid, id) {
    return db.collection("users").doc(uid).collection("notifications").doc(id);
  }

  function tokenRef(uid, tokenId) {
    return db.collection("users").doc(uid).collection("fcmTokens").doc(tokenId);
  }

  async function markRead(request) {
    const uid = auth(request);
    const id = request.data && request.data.notificationId;
    if (typeof id !== "string" || !id.trim()) {
      throw new HttpsError("invalid-argument", "notificationId is required.");
    }
    await db.runTransaction(async (tx) => {
      const ref = notificationRef(uid, id.trim());
      const snapshot = await tx.get(ref);
      if (!snapshot.exists || snapshot.data()?.readAt) return;
      const userRef = db.collection("users").doc(uid);
      const user = await tx.get(userRef);
      const count = Number(user.data()?.unreadNotificationsCount || 0);
      const counters = {
        unreadNotificationsCount: Math.max(0, count - 1),
      };
      const domainCounter = counterField(snapshot.data()?.type);
      if (domainCounter) {
        counters[domainCounter] = Math.max(
          0,
          Number(user.data()?.[domainCounter] || 0) - 1,
        );
      }
      tx.update(ref, { readAt: FieldValue.serverTimestamp() });
      tx.set(userRef, counters, { merge: true });
    });
    return { ok: true };
  }

  async function markAllRead(request) {
    const uid = auth(request);
    let total = 0;
    while (true) {
      const query = await db.collection("users").doc(uid)
        .collection("notifications").where("readAt", "==", null).limit(400).get();
      if (query.empty) break;
      const changed = await db.runTransaction(async (tx) => {
        const userRef = db.collection("users").doc(uid);
        const snapshots = await Promise.all(query.docs.map((doc) => tx.get(doc.ref)));
        const user = await tx.get(userRef);
        const unread = snapshots.filter((snapshot) =>
          snapshot.exists && !snapshot.data()?.readAt);
        unread.forEach((snapshot) => tx.update(snapshot.ref, {
          readAt: FieldValue.serverTimestamp(),
        }));
        const count = Number(user.data()?.unreadNotificationsCount || 0);
        const counters = {
          unreadNotificationsCount: Math.max(0, count - unread.length),
        };
        for (const field of [
          "unreadGroupsCount",
          "unreadPrivateMessagesCount",
          "unreadMentionsCount",
        ]) {
          const removed = unread.filter((snapshot) =>
            counterField(snapshot.data()?.type) === field).length;
          if (removed > 0) {
            counters[field] = Math.max(
              0,
              Number(user.data()?.[field] || 0) - removed,
            );
          }
        }
        tx.set(userRef, counters, { merge: true });
        return unread.length;
      });
      total += changed;
      if (query.size < 400) break;
    }
    return { ok: true, count: total };
  }

  async function registerToken(request) {
    const uid = auth(request);
    const data = request.data || {};
    if (typeof data.token !== "string" || data.token.length < 10 ||
        data.token.length > 4096) {
      throw new HttpsError("invalid-argument", "Invalid FCM token.");
    }
    const tokenId = Buffer.from(data.token).toString("base64url").slice(0, 128);
    const ownerRef = db.collection("fcmTokenOwners").doc(tokenId);
    await db.runTransaction(async (tx) => {
      const owner = await tx.get(ownerRef);
      const previousUid = owner.data()?.uid;
      if (typeof previousUid === "string" && previousUid !== uid) {
        tx.delete(tokenRef(previousUid, tokenId));
      }
      tx.set(tokenRef(uid, tokenId), {
        token: data.token,
        platform: typeof data.platform === "string" ?
          data.platform.slice(0, 32) : "unknown",
        uid,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      tx.set(ownerRef, { uid, updatedAt: FieldValue.serverTimestamp() });
    });
    return { ok: true, tokenId };
  }

  async function unregisterToken(request) {
    const uid = auth(request);
    const token = request.data && request.data.token;
    if (typeof token !== "string" || token.length < 10 || token.length > 4096) {
      throw new HttpsError("invalid-argument", "Invalid FCM token.");
    }
    const tokenId = Buffer.from(token).toString("base64url").slice(0, 128);
    const ownerRef = db.collection("fcmTokenOwners").doc(tokenId);
    await db.runTransaction(async (tx) => {
      const owner = await tx.get(ownerRef);
      tx.delete(tokenRef(uid, tokenId));
      if (owner.data()?.uid === uid) tx.delete(ownerRef);
    });
    return { ok: true };
  }

  return { markRead, markAllRead, registerToken, unregisterToken };
}

module.exports = { createNotificationCallables };