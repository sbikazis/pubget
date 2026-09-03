"use strict";

// Games domain (PROMPT 12) — reusable game infrastructure only.
//
// Architecture: UI → Provider → Repository → this engine → Firestore.
// Game-specific rules (Mafia roles, guess scoring, etc.) do NOT belong here.
// Chat is never written from this module. Callers may later consume
// toGameActivity(event) through the existing system-activity contract.

const { ROLE_PERMISSIONS } = require("./groupsDomain");
const { engineFor } = require("./gameEngines");
const { secretRef, isExpired } = require("./gameEngines/helpers");

const TITLE_MAX = 80;
const DESCRIPTION_MAX = 500;
const GAME_ID_MAX = 128;
const ACTION_TYPE_MAX = 64;
const PAYLOAD_JSON_MAX = 8192;
const RECIPIENT_CAP = 200;

const GAME_TYPES = [
  "guessCharacter",
  "animeChain",
  "emojiAnimeGuess",
  "mafia",
];

const GAME_TYPE_REGISTRY = {
  guessCharacter: {
    name: "Guess the Character",
    version: 1,
    implemented: true,
    capabilities: {
      usesRounds: true, usesScoring: true, minPlayers: 2, maxPlayers: 2,
      defaultRounds: 5, defaultTimer: 20,
    },
  },
  animeChain: {
    name: "Anime Chain",
    version: 1,
    implemented: true,
    capabilities: {
      usesRounds: true, usesScoring: true, minPlayers: 2, maxPlayers: 8,
      defaultRounds: 8, defaultTimer: 25,
    },
  },
  emojiAnimeGuess: {
    name: "Emoji Anime Guess",
    version: 1,
    implemented: true,
    capabilities: {
      usesRounds: true, usesScoring: true, minPlayers: 2, maxPlayers: 4,
      defaultRounds: 1, defaultTimer: 25,
    },
  },
  mafia: {
    name: "Mafia",
    version: 1,
    implemented: false,
    capabilities: { usesRounds: true, usesScoring: false, minPlayers: 4, maxPlayers: 16 },
  },
};

const STATUSES = [
  "draft", "waiting", "active", "paused", "completed", "cancelled",
];

const TRANSITIONS = {
  draft: new Set(["waiting", "cancelled"]),
  waiting: new Set(["active", "cancelled"]),
  active: new Set(["paused", "completed", "cancelled"]),
  paused: new Set(["active", "cancelled"]),
  completed: new Set(),
  cancelled: new Set(),
};

const TERMINAL = new Set(["completed", "cancelled"]);

const EVENT_SCHEMA_VERSION = 1;

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

function gameRef(db, gameId) {
  return db.collection("games").doc(gameId);
}

function participantRef(db, gameId, uid) {
  return gameRef(db, gameId).collection("participants").doc(uid);
}

function actionRef(db, gameId, actionId) {
  return gameRef(db, gameId).collection("actions").doc(actionId);
}

function eventRef(db, gameId, eventId) {
  return gameRef(db, gameId).collection("events").doc(eventId);
}

function groupRef(db, groupId) {
  return db.collection("groups").doc(groupId);
}

function memberRef(db, groupId, uid) {
  return groupRef(db, groupId).collection("members").doc(uid);
}

function roleRef(db, groupId, role) {
  return groupRef(db, groupId).collection("roles").doc(role);
}

function canTransition(from, to) {
  return STATUSES.includes(from) && STATUSES.includes(to) &&
    TRANSITIONS[from] && TRANSITIONS[from].has(to);
}

function assertTransition(from, to, HttpsError) {
  if (!canTransition(from, to)) {
    const code = from === "completed" && to === "completed"
      ? "failed-precondition"
      : "failed-precondition";
    throw new HttpsError(
      code,
      `Cannot move a game from ${from} to ${to}.`,
    );
  }
}

function searchNameOf(title) {
  return title.trim().toLowerCase();
}

function displayNameOf(user, uid) {
  if (user && validString(user.username, 80)) return user.username.trim();
  if (user && validString(user.displayName, 80)) return user.displayName.trim();
  return uid;
}

function clampInt(value, fallback, min, max) {
  const n = Number.isInteger(value) ? value : Number.parseInt(value, 10);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

function normalizeConfiguration(raw, spec) {
  const input = raw && typeof raw === "object" ? raw : {};
  const caps = spec.capabilities || {};
  const extra = input.extra && typeof input.extra === "object" &&
    !Array.isArray(input.extra)
    ? Object.fromEntries(
      Object.entries(input.extra).slice(0, 20).map(([key, value]) => {
        if (typeof key !== "string" || key.length > 32) return null;
        if (typeof value === "string") return [key, value.slice(0, 200)];
        if (typeof value === "number" || typeof value === "boolean") {
          return [key, value];
        }
        return null;
      }).filter(Boolean),
    )
    : {};
  const minCap = caps.minPlayers || 1;
  const maxCap = caps.maxPlayers || 16;
  const minPlayers = clampInt(input.minPlayers, minCap, minCap, maxCap);
  const maxPlayers = clampInt(input.maxPlayers, maxCap, minPlayers, maxCap);
  const difficultySource = input.difficulty || extra.difficulty;
  const difficulty = ["easy", "normal", "hard"].includes(difficultySource)
    ? difficultySource
    : "normal";
  return {
    minPlayers,
    maxPlayers,
    usesRounds: input.usesRounds === true || caps.usesRounds === true,
    roundCount: clampInt(
      input.roundCount ?? extra.roundCount,
      caps.defaultRounds || 5,
      3,
      10,
    ),
    timerSeconds: clampInt(
      input.timerSeconds ?? extra.timerSeconds,
      caps.defaultTimer || 20,
      10,
      60,
    ),
    difficulty,
    extra,
  };
}

function validateActionShape(input, HttpsError) {
  if (!validString(input.actionType, ACTION_TYPE_MAX)) {
    throw new HttpsError("invalid-argument", "actionType is invalid.");
  }
  const payload = input.payload && typeof input.payload === "object" &&
    !Array.isArray(input.payload)
    ? input.payload
    : {};
  let serialized;
  try {
    serialized = JSON.stringify(payload);
  } catch (_) {
    throw new HttpsError("invalid-argument", "Action payload is invalid.");
  }
  if (serialized.length > PAYLOAD_JSON_MAX) {
    throw new HttpsError("invalid-argument", "Action payload is too large.");
  }
  if (input.clientActionId != null &&
      !validString(input.clientActionId, GAME_ID_MAX)) {
    throw new HttpsError("invalid-argument", "clientActionId is invalid.");
  }
  if (input.playerId != null && !validString(input.playerId, 128)) {
    throw new HttpsError("invalid-argument", "playerId is invalid.");
  }
  return {
    actionType: input.actionType.trim(),
    payload,
    clientActionId: input.clientActionId ? input.clientActionId.trim() : null,
  };
}

function buildGameEvent({
  eventId, gameId, type, actorId, payload = {}, createdAt,
}) {
  return {
    eventId,
    gameId,
    type,
    actorId,
    payload,
    schemaVersion: EVENT_SCHEMA_VERSION,
    createdAt: createdAt || null,
  };
}

function toGameActivity(event, game) {
  if (!event || !game) return null;
  return {
    gameId: game.id || event.gameId,
    gameType: game.type,
    groupId: game.groupId || null,
    eventType: event.type,
    actor: event.actorId,
    metadata: event.payload || {},
    timestamp: event.createdAt || null,
  };
}

async function loadPermissions(transaction, db, groupId, uid) {
  if (!groupId) return { member: false, manageGames: false, role: null };
  const [member, group] = await Promise.all([
    transaction.get(memberRef(db, groupId, uid)),
    transaction.get(groupRef(db, groupId)),
  ]);
  if (!group.exists) {
    return { member: false, manageGames: false, role: null, missingGroup: true };
  }
  if (!member.exists) return { member: false, manageGames: false, role: null };
  const role = member.data().role || "member";
  const roleSnap = await transaction.get(roleRef(db, groupId, role));
  const permissions = roleSnap.exists && Array.isArray(roleSnap.data().permissions)
    ? roleSnap.data().permissions
    : (ROLE_PERMISSIONS[role] || []);
  return {
    member: true,
    manageGames: role === "founder" || permissions.includes("manageGames"),
    role,
  };
}

function notifySafe(builder, payload) {
  if (!builder || typeof builder.build !== "function") return Promise.resolve();
  return builder.build(payload).catch(() => {});
}

async function listCollectionDocs(collectionRef, limit = RECIPIENT_CAP) {
  if (!collectionRef) return [];
  if (typeof collectionRef.limit === "function") {
    const snapshot = await collectionRef.limit(limit).get();
    return snapshot.docs;
  }
  const snapshot = await collectionRef.get();
  return snapshot.docs.slice(0, limit);
}

async function listGroupMemberIds(db, groupId) {
  if (!validString(groupId, 128)) return [];
  const docs = await listCollectionDocs(groupRef(db, groupId).collection("members"));
  return docs.map((doc) => doc.id).filter((id) => validString(id, 128));
}

async function listActiveParticipantIds(db, gameId) {
  if (!validString(gameId, GAME_ID_MAX)) return [];
  const docs = await listCollectionDocs(
    gameRef(db, gameId).collection("participants"),
  );
  return docs
    .filter((doc) => {
      const data = doc.data() || {};
      return data.status !== "left" && !data.leftAt;
    })
    .map((doc) => doc.id)
    .filter((id) => validString(id, 128));
}

function uniqueRecipientIds(ids) {
  return [...new Set((ids || []).filter((id) => validString(id, 128)))]
    .slice(0, RECIPIENT_CAP);
}

function writeEvent(transaction, db, FieldValue, {
  gameId, eventId, type, actorId, payload,
}) {
  const ref = eventId
    ? eventRef(db, gameId, eventId)
    : gameRef(db, gameId).collection("events").doc();
  transaction.create(ref, buildGameEvent({
    eventId: eventId || ref.id,
    gameId,
    type,
    actorId,
    payload,
    createdAt: FieldValue.serverTimestamp(),
  }));
}

function createGamesDomain({
  db, FieldValue, HttpsError, notificationBuilder, economy, achievements,
  clock, random,
}) {
  const nowOf = () => (clock && typeof clock.now === "function" ? clock.now() : new Date());
  const rng = typeof random === "function" ? random : Math.random;

  async function notifyGame({ kind, gameId, groupId, actorId, title, type }) {
    if (!validString(gameId, GAME_ID_MAX)) return;
    let recipientIds;
    let notificationType;
    let destination;
    let id;
    let body;
    let pushWorthy;
    if (kind === "invite") {
      recipientIds = await listGroupMemberIds(db, groupId);
      recipientIds = uniqueRecipientIds(recipientIds.filter((uid) => uid !== actorId));
      notificationType = "game_invite";
      id = `game-invite-${gameId}`;
      destination = `/game/${gameId}`;
      body = title || "A new game is waiting.";
      pushWorthy = true;
    } else if (kind === "started") {
      recipientIds = uniqueRecipientIds(await listGroupMemberIds(db, groupId));
      notificationType = "game_started";
      id = `game-start-${gameId}`;
      destination = `/game/${gameId}`;
      body = title || "A game just started.";
      pushWorthy = true;
    } else {
      recipientIds = uniqueRecipientIds(await listActiveParticipantIds(db, gameId));
      notificationType = "game_completed";
      id = `game-completed-${gameId}`;
      destination = `/game/${gameId}`;
      body = title || "A game has finished.";
      pushWorthy = false;
    }
    if (recipientIds.length === 0) return;
    await notifySafe(notificationBuilder, {
      id,
      recipientIds,
      type: notificationType,
      actorId: actorId || null,
      targetId: gameId,
      action: kind,
      destination,
      metadata: { groupId: groupId || "", gameType: type || "" },
      title: kind === "invite" ? "Game invite" : (kind === "started" ? "Game started" : "Game completed"),
      body,
      pushWorthy,
    });
  }

  async function activePlayerIds(gameId) {
    return uniqueRecipientIds(await listActiveParticipantIds(db, gameId)).sort();
  }

  async function afterComplete(gameId, game, result) {
    if (!game) return;
    await notifyGame({
      kind: "completed",
      gameId,
      groupId: game.groupId,
      actorId: game.creatorId,
      title: game.title,
      type: game.type,
    });
    const winnerIds = Array.isArray(result && result.winnerIds)
      ? result.winnerIds
      : (Array.isArray(game.result && game.result.winnerIds) ? game.result.winnerIds : []);
    const participants = await activePlayerIds(gameId);
    if (economy && typeof economy.grantDomainRewards === "function" && winnerIds.length > 0) {
      await economy.grantDomainRewards(winnerIds, {
        type: "earn_game",
        referenceId: gameId,
        source: "game",
        metadata: { gameType: game.type || "" },
      });
    }
    if (achievements && typeof achievements.evaluate === "function") {
      if (winnerIds.length > 0) {
        await achievements.evaluate({
          type: "game_won",
          userIds: winnerIds,
          source: "game",
          metadata: { gameId, gameType: game.type || "" },
        });
      }
      await achievements.evaluate({
        type: "game_completed",
        userIds: participants.length ? participants : winnerIds,
        source: "game",
        metadata: { gameId },
      });
    }
  }

  async function initializeEngine(gameId) {
    const playerIds = await activePlayerIds(gameId);
    await db.runTransaction(async (transaction) => {
      const ref = gameRef(db, gameId);
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      const current = snapshot.data() || {};
      if (current.status !== "active") return;
      if (current.publicState && current.publicState.engine) return;
      const engine = engineFor(current.type);
      if (!engine || typeof engine.initialize !== "function") return;
      engine.initialize({
        transaction,
        db,
        gameRef: ref,
        FieldValue,
        game: current,
        gameId,
        playerIds,
        random: rng,
        now: nowOf(),
      });
    });
  }

  async function resolveExpiredGame(gameId) {
    const playerIds = await activePlayerIds(gameId);
    let outcome = { completed: false, result: null, game: null };
    await db.runTransaction(async (transaction) => {
      const ref = gameRef(db, gameId);
      const [snapshot, secretSnap] = await Promise.all([
        transaction.get(ref),
        transaction.get(secretRef(ref)),
      ]);
      if (!snapshot.exists) return;
      const current = snapshot.data() || {};
      if (current.status !== "active") return;
      if (!isExpired(current.deadlineAt, nowOf())) return;
      const engine = engineFor(current.type);
      if (!engine || typeof engine.onTimeout !== "function") return;
      const result = engine.onTimeout({
        transaction,
        db,
        gameRef: ref,
        FieldValue,
        HttpsError,
        game: current,
        gameId,
        playerIds,
        random: rng,
        now: nowOf(),
        secretSnap,
      }) || { completed: false };
      outcome = {
        completed: result.completed === true,
        result: result.result || current.result,
        game: current,
      };
    });
    if (outcome.completed) {
      await afterComplete(gameId, outcome.game, outcome.result);
    }
    return outcome;
  }

  async function createGame(request) {
    const uid = requireAuth(request, HttpsError);
    const input = request.data || {};
    const spec = GAME_TYPE_REGISTRY[input.type];
    if (!spec || !GAME_TYPES.includes(input.type)) {
      throw new HttpsError("invalid-argument", "Unknown game type.");
    }
    if (!spec.implemented) {
      throw new HttpsError("failed-precondition", "This game is not available yet.");
    }
    if (!validString(input.title, TITLE_MAX)) {
      throw new HttpsError("invalid-argument", "A valid title is required.");
    }
    if (typeof input.description === "string" && input.description.length > DESCRIPTION_MAX) {
      throw new HttpsError("invalid-argument", "Description is too long.");
    }
    if (!validString(input.groupId, 128)) {
      throw new HttpsError("invalid-argument", "groupId is required.");
    }
    const configuration = normalizeConfiguration(input.configuration, spec);
    const asDraft = input.asDraft === true;
    const status = asDraft ? "draft" : "waiting";
    const ref = db.collection("games").doc();
    const title = input.title.trim();
    await db.runTransaction(async (transaction) => {
      const access = await loadPermissions(transaction, db, input.groupId.trim(), uid);
      if (access.missingGroup) throw new HttpsError("not-found", "Group not found.");
      if (!access.member) {
        throw new HttpsError("permission-denied", "Join the group to create a game.");
      }
      if (!access.manageGames) {
        throw new HttpsError("permission-denied", "You need Manage Games to create a game.");
      }
      const user = await transaction.get(db.collection("users").doc(uid));
      const now = FieldValue.serverTimestamp();
      transaction.create(ref, {
        type: input.type,
        title,
        description: typeof input.description === "string" ? input.description.trim() : "",
        version: spec.version,
        status,
        creatorId: uid,
        groupId: input.groupId.trim(),
        configuration,
        participantsCount: asDraft ? 0 : 1,
        result: null,
        currentRoundNumber: null,
        publicState: null,
        currentPhase: status,
        stateVersion: 0,
        deadlineAt: null,
        createdAt: now,
        updatedAt: now,
        startedAt: null,
        endedAt: null,
        searchName: searchNameOf(title),
      });
      if (!asDraft) {
        transaction.create(participantRef(db, ref.id, uid), {
          gameId: ref.id,
          userId: uid,
          displayName: displayNameOf(user.exists ? user.data() : {}, uid),
          status: "active",
          joinedAt: now,
          leftAt: null,
          metadata: {},
        });
      }
      writeEvent(transaction, db, FieldValue, {
        gameId: ref.id,
        eventId: `${ref.id}_created`,
        type: "game_created",
        actorId: uid,
        payload: { status, type: input.type },
      });
    });
    if (!asDraft) {
      await notifyGame({
        kind: "invite",
        gameId: ref.id,
        groupId: input.groupId.trim(),
        actorId: uid,
        title,
        type: input.type,
      });
    }
    return { gameId: ref.id, status };
  }

  async function initializeGame(request) {
    const uid = requireAuth(request, HttpsError);
    const gameId = request.data && request.data.gameId;
    if (!validString(gameId, GAME_ID_MAX)) {
      throw new HttpsError("invalid-argument", "gameId is required.");
    }
    const ref = gameRef(db, gameId.trim());
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw new HttpsError("not-found", "Game not found.");
      const current = snapshot.data() || {};
      if (current.status === "waiting") return;
      const access = await loadPermissions(transaction, db, current.groupId, uid);
      if (current.creatorId !== uid && !access.manageGames) {
        throw new HttpsError("permission-denied", "You cannot initialize this game.");
      }
      assertTransition(current.status, "waiting", HttpsError);
      const user = await transaction.get(db.collection("users").doc(uid));
      const person = await transaction.get(participantRef(db, ref.id, uid));
      const now = FieldValue.serverTimestamp();
      transaction.update(ref, {
        status: "waiting",
        updatedAt: now,
        participantsCount: person.exists && !person.data().leftAt
          ? current.participantsCount
          : (current.participantsCount || 0) + 1,
      });
      if (!person.exists || person.data().leftAt) {
        transaction.set(participantRef(db, ref.id, uid), {
          gameId: ref.id,
          userId: uid,
          displayName: displayNameOf(user.exists ? user.data() : {}, uid),
          status: "active",
          joinedAt: now,
          leftAt: null,
          metadata: {},
        });
      }
    });
    return { ok: true };
  }

  async function joinGame(request) {
    const uid = requireAuth(request, HttpsError);
    const gameId = request.data && request.data.gameId;
    if (!validString(gameId, GAME_ID_MAX)) {
      throw new HttpsError("invalid-argument", "gameId is required.");
    }
    const ref = gameRef(db, gameId.trim());
    const person = participantRef(db, gameId.trim(), uid);
    await db.runTransaction(async (transaction) => {
      const [snapshot, existing, user] = await Promise.all([
        transaction.get(ref),
        transaction.get(person),
        transaction.get(db.collection("users").doc(uid)),
      ]);
      if (!snapshot.exists) throw new HttpsError("not-found", "Game not found.");
      const current = snapshot.data() || {};
      const access = await loadPermissions(transaction, db, current.groupId, uid);
      if (!access.member) {
        throw new HttpsError("permission-denied", "Join the group to participate.");
      }
      if (current.status === "active" || current.status === "paused") {
        throw new HttpsError("failed-precondition", "This game has already started.");
      }
      if (current.status !== "waiting") {
        throw new HttpsError("failed-precondition", "This game is not open to join.");
      }
      if (existing.exists && existing.data().status !== "left" && !existing.data().leftAt) {
        return;
      }
      const maxPlayers = (current.configuration && current.configuration.maxPlayers) || 16;
      if ((current.participantsCount || 0) >= maxPlayers &&
          !(existing.exists && existing.data().leftAt)) {
        throw new HttpsError("failed-precondition", "This game is full.");
      }
      const now = FieldValue.serverTimestamp();
      transaction.set(person, {
        gameId: ref.id,
        userId: uid,
        displayName: displayNameOf(user.exists ? user.data() : {}, uid),
        status: "active",
        joinedAt: now,
        leftAt: null,
        metadata: {},
      });
      transaction.update(ref, {
        participantsCount: FieldValue.increment(1),
        updatedAt: now,
      });
      writeEvent(transaction, db, FieldValue, {
        gameId: ref.id,
        type: "player_joined",
        actorId: uid,
        payload: {},
      });
    });
    return { ok: true };
  }

  async function leaveGame(request) {
    const uid = requireAuth(request, HttpsError);
    const gameId = request.data && request.data.gameId;
    if (!validString(gameId, GAME_ID_MAX)) {
      throw new HttpsError("invalid-argument", "gameId is required.");
    }
    const ref = gameRef(db, gameId.trim());
    const person = participantRef(db, gameId.trim(), uid);
    await db.runTransaction(async (transaction) => {
      const [snapshot, existing] = await Promise.all([
        transaction.get(ref),
        transaction.get(person),
      ]);
      if (!snapshot.exists) throw new HttpsError("not-found", "Game not found.");
      const current = snapshot.data() || {};
      if (TERMINAL.has(current.status)) {
        throw new HttpsError("failed-precondition", "This game is already finished.");
      }
      if (!existing.exists) {
        throw new HttpsError("permission-denied", "You are not a participant in this game.");
      }
      if (existing.data().status === "left" || existing.data().leftAt) return;
      const now = FieldValue.serverTimestamp();
      transaction.update(person, {
        status: "left",
        leftAt: now,
      });
      transaction.update(ref, {
        participantsCount: FieldValue.increment(-1),
        updatedAt: now,
      });
      writeEvent(transaction, db, FieldValue, {
        gameId: ref.id,
        type: "player_left",
        actorId: uid,
        payload: {},
      });
    });
    return { ok: true };
  }

  async function mutateStatus(request, {
    target, eventType, extra, fromStatuses, oneShotEvent = true,
  }) {
    const uid = requireAuth(request, HttpsError);
    const gameId = request.data && request.data.gameId;
    if (!validString(gameId, GAME_ID_MAX)) {
      throw new HttpsError("invalid-argument", "gameId is required.");
    }
    const ref = gameRef(db, gameId.trim());
    let skipped = false;
    let snapshotData;
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw new HttpsError("not-found", "Game not found.");
      const current = snapshot.data() || {};
      snapshotData = current;
      if (current.status === target) {
        skipped = true;
        return;
      }
      const access = await loadPermissions(transaction, db, current.groupId, uid);
      if (current.creatorId !== uid && !access.manageGames) {
        throw new HttpsError("permission-denied", "You cannot change this game.");
      }
      if (fromStatuses && !fromStatuses.includes(current.status)) {
        assertTransition(current.status, target, HttpsError);
        throw new HttpsError(
          "failed-precondition",
          `Cannot move a game from ${current.status} to ${target}.`,
        );
      }
      assertTransition(current.status, target, HttpsError);
      if (target === "active" && current.status === "waiting") {
        const minPlayers = (current.configuration && current.configuration.minPlayers) || 1;
        if ((current.participantsCount || 0) < minPlayers) {
          throw new HttpsError("failed-precondition", "Not enough players to start.");
        }
      }
      const now = FieldValue.serverTimestamp();
      const update = {
        status: target,
        updatedAt: now,
        ...(typeof extra === "function" ? extra(current, now) : {}),
      };
      transaction.update(ref, update);
      writeEvent(transaction, db, FieldValue, {
        gameId: ref.id,
        eventId: oneShotEvent ? `${ref.id}_${eventType}` : undefined,
        type: eventType,
        actorId: uid,
        payload: { from: current.status, to: target },
      });
    });
    return { ok: true, skipped, game: snapshotData };
  }

  async function startGame(request) {
    const result = await mutateStatus(request, {
      target: "active",
      eventType: "game_started",
      fromStatuses: ["waiting"],
      extra: (current, now) => ({
        startedAt: current.startedAt || now,
      }),
    });
    if (!result.skipped && result.game) {
      await notifyGame({
        kind: "started",
        gameId: request.data.gameId.trim(),
        groupId: result.game.groupId,
        actorId: request.auth.uid,
        title: result.game.title,
        type: result.game.type,
      });
    }
    await initializeEngine(request.data.gameId.trim());
    return { ok: true };
  }

  async function pauseGame(request) {
    await mutateStatus(request, {
      target: "paused",
      eventType: "game_paused",
      fromStatuses: ["active"],
      oneShotEvent: false,
      extra: () => ({}),
    });
    return { ok: true };
  }

  async function resumeGame(request) {
    await mutateStatus(request, {
      target: "active",
      eventType: "game_resumed",
      fromStatuses: ["paused"],
      oneShotEvent: false,
      extra: () => ({}),
    });
    return { ok: true };
  }

  async function endGame(request) {
    const result = await mutateStatus(request, {
      target: "completed",
      eventType: "game_completed",
      fromStatuses: ["active", "paused"],
      extra: (current, now) => ({
        endedAt: now,
        result: current.result || {
          kind: current.type,
          winnerIds: [],
          scores: {},
          summary: {},
        },
      }),
    });
    if (!result.skipped && result.game) {
      await afterComplete(
        request.data.gameId.trim(),
        result.game,
        result.game.result,
      );
    }
    return { ok: true };
  }

  async function cancelGame(request) {
    await mutateStatus(request, {
      target: "cancelled",
      eventType: "game_cancelled",
      fromStatuses: ["draft", "waiting", "active", "paused"],
      extra: (_, now) => ({ endedAt: now }),
    });
    return { ok: true };
  }

  async function submitGameAction(request) {
    const uid = requireAuth(request, HttpsError);
    const input = request.data || {};
    if (!validString(input.gameId, GAME_ID_MAX)) {
      throw new HttpsError("invalid-argument", "gameId is required.");
    }
    if (input.playerId && input.playerId.trim() !== uid) {
      throw new HttpsError("permission-denied", "You cannot submit an action as another player.");
    }
    const action = validateActionShape(input, HttpsError);
    const gameId = input.gameId.trim();
    const ref = gameRef(db, gameId);
    const person = participantRef(db, gameId, uid);
    const actionId = action.clientActionId || db.collection("_").doc().id;
    const stored = actionRef(db, gameId, actionId);
    const refSecret = secretRef(ref);
    let completed = null;
    let completedGame = null;
    await db.runTransaction(async (transaction) => {
      const [snapshot, existing, prior, secretSnap] = await Promise.all([
        transaction.get(ref),
        transaction.get(person),
        transaction.get(stored),
        transaction.get(refSecret),
      ]);
      if (!snapshot.exists) throw new HttpsError("not-found", "Game not found.");
      const current = snapshot.data() || {};
      const access = await loadPermissions(transaction, db, current.groupId, uid);
      if (!access.member) {
        throw new HttpsError("permission-denied", "Join the group to participate.");
      }
      if (current.status === "completed" || current.status === "cancelled") {
        throw new HttpsError("failed-precondition", "This game is already finished.");
      }
      if (current.status !== "active") {
        throw new HttpsError("failed-precondition", "Actions can only be submitted while the game is active.");
      }
      if (!existing.exists || existing.data().status === "left" || existing.data().leftAt) {
        throw new HttpsError("permission-denied", "You are not a participant in this game.");
      }
      if (prior.exists) return;
      const now = FieldValue.serverTimestamp();
      transaction.create(stored, {
        actionId,
        gameId,
        playerId: uid,
        actionType: action.actionType,
        payload: action.payload,
        clientActionId: action.clientActionId,
        schemaVersion: EVENT_SCHEMA_VERSION,
        createdAt: now,
      });
      writeEvent(transaction, db, FieldValue, {
        gameId,
        type: "action_submitted",
        actorId: uid,
        payload: { actionType: action.actionType, actionId },
      });
      const engine = engineFor(current.type);
      if (engine && typeof engine.applyAction === "function") {
        const outcome = engine.applyAction({
          transaction,
          db,
          gameRef: ref,
          FieldValue,
          HttpsError,
          game: current,
          gameId,
          uid,
          action,
          now: nowOf(),
          secretSnap,
          random: rng,
        }) || {};
        if (outcome.completed) {
          completed = outcome.result;
          completedGame = current;
        }
      } else {
        transaction.update(ref, { updatedAt: now });
      }
    });
    if (completed && completedGame) {
      await afterComplete(gameId, completedGame, completed);
    }
    return { ok: true, actionId };
  }

  async function processExpiredGames() {
    const now = nowOf();
    const snapshot = await db.collection("games")
      .where("status", "==", "active")
      .where("deadlineAt", "<=", now)
      .orderBy("deadlineAt", "asc")
      .limit(50)
      .get();
    const docs = snapshot.docs || [];
    for (const doc of docs) {
      await resolveExpiredGame(doc.id);
    }
    return {
      ok: true,
      scanned: docs.length,
      expired: docs.length,
      limit: 50,
    };
  }

  return {
    createGame,
    initializeGame,
    joinGame,
    leaveGame,
    startGame,
    pauseGame,
    resumeGame,
    submitGameAction,
    endGame,
    cancelGame,
    processExpiredGames,
  };
}

module.exports = {
  GAME_TYPES,
  GAME_TYPE_REGISTRY,
  STATUSES,
  TRANSITIONS,
  EVENT_SCHEMA_VERSION,
  assertTransition,
  canTransition,
  createGamesDomain,
  buildGameEvent,
  toGameActivity,
  validateActionShape,
  normalizeConfiguration,
};
