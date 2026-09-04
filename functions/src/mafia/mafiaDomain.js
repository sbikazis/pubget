"use strict";

const { ROLE_PERMISSIONS } = require("../groupsDomain");

const TITLE_MAX = 80;
const DEFAULT_MIN = 4;
const DEFAULT_MAX = 8;
const LOBBY_SECONDS = 120;
const STARTING_SECONDS = 10;

function validString(value, max) {
  return typeof value === "string" && value.trim().length > 0 &&
    value.trim().length <= max;
}

function requireAuth(request, HttpsError) {
  if (!request || !request.auth || !validString(request.auth.uid, 128)) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return request.auth.uid;
}

function clampInt(value, fallback, min, max) {
  const n = Number.isInteger(value) ? value : Number.parseInt(value, 10);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

function displayNameOf(user, uid) {
  if (user && validString(user.username, 80)) return user.username.trim();
  if (user && validString(user.displayName, 80)) return user.displayName.trim();
  return uid;
}

function publicPlayer(uid, name, avatar, FieldValue) {
  return {
    userId: uid,
    username: name,
    avatar: avatar || "",
    isAlive: true,
    isDisconnected: false,
    isMuted: false,
    hasLeft: false,
    joinedAt: FieldValue.serverTimestamp(),
    lastSeenAt: null,
    coinsEarned: 0,
    votesReceived: 0,
    canSpeak: true,
    canVote: true,
    canUseAbility: true,
    revealedRole: false,
  };
}

function createMafiaDomain({ db, FieldValue, Timestamp, HttpsError, notificationBuilder }) {
  function gameRef(gameId) {
    return db.collection("mafia_games").doc(gameId);
  }

  async function loadAccess(transaction, groupId, uid) {
    const [member, group] = await Promise.all([
      transaction.get(db.collection("groups").doc(groupId).collection("members").doc(uid)),
      transaction.get(db.collection("groups").doc(groupId)),
    ]);
    if (!group.exists) return { member: false, manageGames: false, missingGroup: true };
    if (!member.exists) return { member: false, manageGames: false, group };
    const role = member.data().role || "member";
    const roleSnap = await transaction.get(
      db.collection("groups").doc(groupId).collection("roles").doc(role),
    );
    const permissions = roleSnap.exists && Array.isArray(roleSnap.data().permissions)
      ? roleSnap.data().permissions
      : (ROLE_PERMISSIONS[role] || []);
    return {
      member: true,
      manageGames: role === "founder" || permissions.includes("manageGames"),
      role,
      group,
    };
  }

  function notifySafe(payload) {
    if (!notificationBuilder || typeof notificationBuilder.build !== "function") {
      return Promise.resolve();
    }
    return notificationBuilder.build(payload).catch(() => {});
  }

  async function listGroupMemberIds(groupId) {
    if (!validString(groupId, 128)) return [];
    try {
      const snapshot = await db.collection("groups").doc(groupId)
        .collection("members").get();
      return (snapshot.docs || [])
        .map((doc) => doc.id)
        .filter((id) => validString(id, 128));
    } catch (_) {
      return [];
    }
  }

  async function createMafiaGame(request) {
    const uid = requireAuth(request, HttpsError);
    const input = request.data || {};
    if (!validString(input.groupId, 128)) {
      throw new HttpsError("invalid-argument", "groupId is required.");
    }
    const groupId = input.groupId.trim();
    const minPlayers = clampInt(input.minPlayers, DEFAULT_MIN, 4, 16);
    const maxPlayers = clampInt(input.maxPlayers, DEFAULT_MAX, minPlayers, 16);
    const ref = db.collection("mafia_games").doc();
    const now = Timestamp ? Timestamp.now() : new Date();
    const countdownEndsAt = Timestamp
      ? Timestamp.fromMillis(now.toMillis() + LOBBY_SECONDS * 1000)
      : new Date(now.getTime() + LOBBY_SECONDS * 1000);
    await db.runTransaction(async (transaction) => {
      const access = await loadAccess(transaction, groupId, uid);
      if (access.missingGroup) throw new HttpsError("not-found", "Group not found.");
      if (!access.member) {
        throw new HttpsError("permission-denied", "Join the group to create Mafia.");
      }
      if (!access.manageGames) {
        throw new HttpsError("permission-denied", "You need Manage Games to create Mafia.");
      }
      if (access.group.data().hasRunningGame === true) {
        throw new HttpsError("failed-precondition", "This group already has a running Mafia game.");
      }
      const user = await transaction.get(db.collection("users").doc(uid));
      const name = displayNameOf(user.exists ? user.data() : {}, uid);
      const avatar = (user.exists && user.data().avatarUrl) || "";
      transaction.create(ref, {
        groupId,
        createdBy: uid,
        createdAt: FieldValue.serverTimestamp(),
        version: 1,
        status: "waiting",
        currentPhase: "waiting",
        currentDay: 0,
        currentNight: 0,
        playersCount: 1,
        maxPlayers,
        minPlayers,
        winner: null,
        countdownEndsAt,
        phaseEndsAt: null,
        isLocked: false,
        startedAt: null,
        endedAt: null,
        rewardsDistributed: false,
        historyWritten: false,
      });
      transaction.create(ref.collection("players").doc(uid), publicPlayer(uid, name, avatar, FieldValue));
      transaction.set(ref.collection("players").doc(uid).collection("private").doc("data"), {
        assigned: false,
      });
      transaction.update(db.collection("groups").doc(groupId), {
        activeGameId: ref.id,
        gameStatus: "waiting",
        hasRunningGame: true,
      });
      transaction.create(ref.collection("events").doc(`${ref.id}_created`), {
        type: "GameCreated",
        message: "A Mafia lobby is waiting for players.",
        createdAt: FieldValue.serverTimestamp(),
        payload: { minPlayers, maxPlayers },
      });
    });
    const recipientIds = (await listGroupMemberIds(groupId))
      .filter((id) => id !== uid)
      .slice(0, 200);
    await notifySafe({
      id: `mafia-invite-${ref.id}`,
      recipientIds,
      type: "game_invite",
      actorId: uid,
      targetId: ref.id,
      action: "invite",
      destination: `/mafia/${ref.id}`,
      metadata: { groupId, gameType: "mafia" },
      title: "Mafia lobby",
      body: "A Mafia game is waiting.",
      pushWorthy: true,
    });
    return { gameId: ref.id, status: "waiting" };
  }

  async function joinMafiaGame(request) {
    const uid = requireAuth(request, HttpsError);
    const gameId = request.data && request.data.gameId;
    if (!validString(gameId, 128)) {
      throw new HttpsError("invalid-argument", "gameId is required.");
    }
    const ref = gameRef(gameId.trim());
    await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "Game not found.");
      const current = snap.data() || {};
      const access = await loadAccess(transaction, current.groupId, uid);
      if (!access.member) {
        throw new HttpsError("permission-denied", "Join the group to participate.");
      }
      if (current.status !== "waiting") {
        throw new HttpsError("failed-precondition", "This lobby is not open.");
      }
      const person = await transaction.get(ref.collection("players").doc(uid));
      if (person.exists) return;
      if ((current.playersCount || 0) >= (current.maxPlayers || DEFAULT_MAX)) {
        throw new HttpsError("failed-precondition", "This lobby is full.");
      }
      const user = await transaction.get(db.collection("users").doc(uid));
      const name = displayNameOf(user.exists ? user.data() : {}, uid);
      const avatar = (user.exists && user.data().avatarUrl) || "";
      const nextCount = (current.playersCount || 0) + 1;
      const fills = nextCount >= (current.maxPlayers || DEFAULT_MAX);
      const now = Timestamp ? Timestamp.now() : new Date();
      transaction.set(ref.collection("players").doc(uid), publicPlayer(uid, name, avatar, FieldValue));
      transaction.set(ref.collection("players").doc(uid).collection("private").doc("data"), {
        assigned: false,
      });
      const update = {
        playersCount: nextCount,
      };
      if (fills) {
        update.isLocked = true;
        update.status = "starting";
        update.currentPhase = "starting";
        update.countdownEndsAt = Timestamp
          ? Timestamp.fromMillis(now.toMillis ? now.toMillis() : Date.now() + STARTING_SECONDS * 1000)
          : new Date(Date.now() + STARTING_SECONDS * 1000);
      }
      transaction.update(ref, update);
    });
    return { ok: true };
  }

  async function startMafiaGame(request) {
    const uid = requireAuth(request, HttpsError);
    const gameId = request.data && request.data.gameId;
    if (!validString(gameId, 128)) {
      throw new HttpsError("invalid-argument", "gameId is required.");
    }
    const ref = gameRef(gameId.trim());
    await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "Game not found.");
      const current = snap.data() || {};
      if (current.createdBy !== uid) {
        throw new HttpsError("permission-denied", "Only the host can start Mafia.");
      }
      if (current.status === "starting") return;
      if (current.status !== "waiting") {
        throw new HttpsError("failed-precondition", "This lobby cannot start.");
      }
      if ((current.playersCount || 0) < (current.minPlayers || DEFAULT_MIN)) {
        throw new HttpsError("failed-precondition", "Not enough players to start.");
      }
      const now = Timestamp ? Timestamp.now() : new Date();
      transaction.update(ref, {
        status: "starting",
        currentPhase: "starting",
        isLocked: true,
        countdownEndsAt: Timestamp
          ? Timestamp.fromMillis((now.toMillis ? now.toMillis() : Date.now()) + STARTING_SECONDS * 1000)
          : new Date(Date.now() + STARTING_SECONDS * 1000),
      });
      transaction.create(ref.collection("events").doc(`${ref.id}_starting`), {
        type: "GameStarting",
        message: "Mafia is starting. Roles will be assigned privately.",
        createdAt: FieldValue.serverTimestamp(),
        payload: {},
      });
    });
    return { ok: true };
  }

  return {
    createMafiaGame,
    joinMafiaGame,
    startMafiaGame,
  };
}

module.exports = {
  createMafiaDomain,
};
