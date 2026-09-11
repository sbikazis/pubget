"use strict";

// Games domain (PROMPT 12) — reusable game infrastructure only.
//
// Architecture: UI → Provider → Repository → this engine → Firestore.
// Game-specific rules (Mafia roles, guess scoring, etc.) do NOT belong here.
// Chat documents are never constructed here. Create/complete emit a
// toGameActivity contract; chatCardWriter posts the system card.

const { ROLE_PERMISSIONS, normalizeRole } = require("./groupsDomain");
const { hasPermission } = require("./pubgetRanks");
const { engineFor } = require("./gameEngines");
const { secretRef, isExpired } = require("./gameEngines/helpers");
const { postFromActivity } = require("./chatCardWriter");

const TITLE_MAX = 80;
const DESCRIPTION_MAX = 500;
const GAME_ID_MAX = 128;
const ACTION_TYPE_MAX = 64;
const PAYLOAD_JSON_MAX = 8192;
const RECIPIENT_CAP = 200;

const GAME_TYPES = ["guessCharacter", "animeChain", "emojiAnimeGuess"];

const GAME_TYPE_REGISTRY = {
  guessCharacter: {
    name: "Guess the Character",
    version: 1,
    implemented: true,
    genericCreate: true,
    capabilities: {
      usesRounds: true, usesScoring: true, minPlayers: 2, maxPlayers: 2,
      defaultRounds: 5, defaultTimer: 20,
    },
  },
  animeChain: {
    name: "Anime Chain",
    version: 1,
    implemented: true,
    genericCreate: true,
    capabilities: {
      usesRounds: true, usesScoring: true, minPlayers: 2, maxPlayers: 2,
      defaultRounds: 8, defaultTimer: 25,
    },
  },
  emojiAnimeGuess: {
    name: "Emoji Anime Guess",
    version: 1,
    implemented: true,
    genericCreate: true,
    capabilities: {
      usesRounds: true, usesScoring: true, minPlayers: 2, maxPlayers: 4,
      defaultRounds: 1, defaultTimer: 25,
    },
  },
};

const STATUSES = [
  "CREATED", "WAITING", "STARTING", "IN_PROGRESS", "COMPLETED", "CANCELLED",
];

const TRANSITIONS = {
  CREATED: new Set(["WAITING", "CANCELLED"]),
  WAITING: new Set(["STARTING", "CANCELLED"]),
  STARTING: new Set(["IN_PROGRESS", "CANCELLED"]),
  IN_PROGRESS: new Set(["COMPLETED", "CANCELLED"]),
  COMPLETED: new Set(),
  CANCELLED: new Set(),
};

const TERMINAL = new Set(["COMPLETED", "CANCELLED"]);

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
  // Player cardinality is a property of the game, not a client preference.
  // Keeping this server authoritative also prevents a creator from opening a
  // game which its engine cannot actually play.
  const minPlayers = minCap;
  const maxPlayers = maxCap;
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
  const payload = event.payload || {};
  return {
    domain: "game",
    gameId: game.id || event.gameId,
    gameType: game.type,
    groupId: game.groupId || null,
    eventType: event.type,
    actor: event.actorId,
    metadata: {
      ...payload,
      title: game.title || payload.title,
      winnerIds: (game.result && game.result.winnerIds) || payload.winnerIds,
      winner: payload.winner,
    },
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
  const data = member.data() || {};
  const groupData = group.data() || {};
  const role = normalizeRole(data.rankV2 || data.role || "ronin");
  const roleSnap = await transaction.get(roleRef(db, groupId, role));
  const roleDoc = roleSnap.exists ? roleSnap.data() : { permissions: ROLE_PERMISSIONS[role] || [] };
  return {
    member: true,
    manageGames: hasPermission(data, roleDoc, "manageGames", groupData),
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
  clock, random, postChatCard,
}) {
  const nowOf = () => (clock && typeof clock.now === "function" ? clock.now() : new Date());
  const rng = typeof random === "function" ? random : Math.random;

  async function emitChatCard(event, game) {
    const activity = toGameActivity(event, game);
    if (!activity) return;
    try {
      if (typeof postChatCard === "function") {
        await postChatCard(activity);
        return;
      }
      await postFromActivity(db, FieldValue, activity);
    } catch (_) {
      // Chat cards must not roll back game mutations.
    }
  }

  async function retractAnnouncement(gameId, groupId) {
    if (!validString(gameId, GAME_ID_MAX) || !validString(groupId, 128)) return;
    try {
      await groupRef(db, groupId).collection("messages")
        .doc(`card-game-${gameId}-created`).delete();
    } catch (_) {
      // Retraction is best effort; the authoritative game is already cancelled.
    }
  }

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
    if (economy && typeof economy.grantDomainRewards === "function") {
      const playerIds = Array.isArray(game.playerOrder) && game.playerOrder.length
        ? game.playerOrder : participants;
      const draw = Boolean(result && (result.draw || result.kind === "draw")) ||
        winnerIds.length === 0;
      const winners = new Set(winnerIds);
      const rewardType = draw ? "draw" : "win";
      // The economy service owns the idempotent ledger.  Supplying the
      // outcome in metadata lets deployments with outcome-specific rates
      // apply 5 / 7..10 / 2 without ever issuing a second grant.
      const winAmount = game.configuration &&
          game.configuration.difficulty === "easy" ? 7 :
        game.configuration &&
          game.configuration.difficulty === "hard" ? 10 : 8;
      for (const playerId of playerIds) {
        const amount = draw ? 5 : (winners.has(playerId) ? winAmount : 2);
        await economy.grantDomainRewards([playerId], {
          type: "earn_game",
          referenceId: gameId,
          source: "game",
          metadata: {
            gameType: game.type || "",
            outcome: draw ? "draw" : (winners.has(playerId) ? "win" : "loss"),
            difficulty: (game.configuration && game.configuration.difficulty) || "normal",
            winnerIds,
            amountOverride: amount,
            rewardAmount: winAmount,
            lossAmount: 2,
            winners: [...winners],
          },
        });
      }
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
        metadata: { gameId, winnerIds },
      });
    }
    await emitChatCard(
      buildGameEvent({
        eventId: `${gameId}_completed`,
        gameId,
        type: "game_completed",
        actorId: game.creatorId,
        payload: { winnerIds },
      }),
      {
        ...game,
        id: gameId,
        result: { ...(game.result || {}), winnerIds },
      },
    );
  }

  async function initializeEngine(gameId) {
    const playerIds = await activePlayerIds(gameId);
    await db.runTransaction(async (transaction) => {
      const ref = gameRef(db, gameId);
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      const current = snapshot.data() || {};
      if (current.status !== "IN_PROGRESS") return;
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
      if (current.status !== "IN_PROGRESS") return;
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
    if (!spec.implemented || spec.genericCreate === false) {
      throw new HttpsError(
        "failed-precondition",
        "This game is not available through createGame.",
      );
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
    const status = asDraft ? "CREATED" : "WAITING";
    const ref = db.collection("games").doc();
    const title = input.title.trim();
    const waitingDeadline = new Date(nowOf().getTime() + 2 * 60 * 1000);
    const utcDay = new Date(nowOf()).toISOString().slice(0, 10);
    const limitRef = db.collection("game_creation_limits").doc(`${uid}_${utcDay}`);
    const requestKey = validString(input.requestId, GAME_ID_MAX) ? input.requestId.trim() : null;
    const requestRef = requestKey
      ? db.collection("game_request_idempotency").doc(`${uid}_${requestKey}`)
      : null;
    let replay = null;
    await db.runTransaction(async (transaction) => {
      if (requestRef) {
        const priorRequest = await transaction.get(requestRef);
        if (priorRequest.exists) {
          replay = priorRequest.data() || null;
          return;
        }
      }
      const access = await loadPermissions(transaction, db, input.groupId.trim(), uid);
      if (access.missingGroup) throw new HttpsError("not-found", "Group not found.");
      if (!access.member) {
        throw new HttpsError("permission-denied", "Join the group to create a game.");
      }
      const limitSnap = await transaction.get(limitRef);
      const limitData = limitSnap.exists ? (limitSnap.data() || {}) : {};
      if ((limitData.count || 0) >= 2) {
        throw new HttpsError(
          "resource-exhausted",
          "Daily game creation limit reached (2 games per UTC day).",
        );
      }
      const user = await transaction.get(db.collection("users").doc(uid));
      const now = FieldValue.serverTimestamp();
      transaction.create(ref, {
        schemaVersion: 2,
        type: input.type,
        title,
        description: typeof input.description === "string" ? input.description.trim() : "",
        version: spec.version,
        status,
        creatorId: uid,
        groupId: input.groupId.trim(),
        configuration,
        participantsCount: asDraft ? 0 : 1,
        playerOrder: asDraft ? [] : [uid],
        joinLocked: false,
        result: null,
        currentRoundNumber: null,
        publicState: null,
        currentPhase: status,
        stateVersion: 0,
         deadlineAt: asDraft ? null : waitingDeadline,
        createdAt: now,
        updatedAt: now,
        startedAt: null,
        endedAt: null,
        searchName: searchNameOf(title),
      });
      if (limitSnap.exists) {
        transaction.update(limitRef, { count: (limitData.count || 0) + 1, updatedAt: now });
      } else {
        transaction.create(limitRef, { userId: uid, utcDay, count: 1, updatedAt: now });
      }
      if (requestRef) {
        transaction.create(requestRef, {
          userId: uid,
          requestId: requestKey,
          gameId: ref.id,
          status,
          createdAt: now,
        });
      }
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
      // This is an isolated hand-off to chat; chat never drives game state.
      transaction.create(
        db.collection("game_chat_outbox").doc(`${ref.id}_created`),
        {
          gameId: ref.id,
          groupId: input.groupId.trim(),
          kind: "created",
          status: "pending",
          createdAt: now,
        },
      );
    });
    if (replay && replay.gameId) return { gameId: replay.gameId, status: replay.status };
    if (!asDraft) {
      await notifyGame({
        kind: "invite",
        gameId: ref.id,
        groupId: input.groupId.trim(),
        actorId: uid,
        title,
        type: input.type,
      });
      await emitChatCard(
        buildGameEvent({
          eventId: `${ref.id}_created`,
          gameId: ref.id,
          type: "game_created",
          actorId: uid,
          payload: { status, type: input.type },
        }),
        {
          id: ref.id,
          type: input.type,
          groupId: input.groupId.trim(),
          title,
        },
      );
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
      if (current.status === "WAITING") return;
      const access = await loadPermissions(transaction, db, current.groupId, uid);
      if (current.creatorId !== uid && !access.manageGames) {
        throw new HttpsError("permission-denied", "You cannot initialize this game.");
      }
      assertTransition(current.status, "WAITING", HttpsError);
      const user = await transaction.get(db.collection("users").doc(uid));
      const person = await transaction.get(participantRef(db, ref.id, uid));
      const now = FieldValue.serverTimestamp();
      transaction.update(ref, {
        status: "WAITING",
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
      if (current.joinLocked || current.status === "IN_PROGRESS" || current.status === "STARTING") {
        throw new HttpsError("failed-precondition", "This game has already started.");
      }
      if (current.status !== "WAITING") {
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
        playerOrder: [...(current.playerOrder || []), uid],
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
      if (current.status === "STARTING" || current.status === "IN_PROGRESS") {
        throw new HttpsError("failed-precondition", "Players are frozen after the game starts; resign explicitly.");
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
      // startGame is deliberately idempotent across the two internal
      // transitions (WAITING -> STARTING -> IN_PROGRESS). A retried request
      // may observe the final state after the first transaction committed.
      if (target === "STARTING" && current.status === "IN_PROGRESS") {
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
      if ((target === "STARTING" || target === "IN_PROGRESS") && current.status === "WAITING") {
        const minPlayers = (current.configuration && current.configuration.minPlayers) || 1;
        const maxPlayers = (current.configuration && current.configuration.maxPlayers) || 16;
        if ((current.participantsCount || 0) < minPlayers) {
          throw new HttpsError("failed-precondition", "Not enough players to start.");
        }
        if ((current.participantsCount || 0) > maxPlayers) {
          throw new HttpsError("failed-precondition", "Too many players for this game.");
        }
      }
      const now = FieldValue.serverTimestamp();
      const update = {
        status: target,
        currentPhase: target,
        stateVersion: (current.stateVersion || 0) + 1,
        updatedAt: now,
        ...(typeof extra === "function" ? extra(current, now) : {}),
      };
      transaction.update(ref, update);
      if (target === "CANCELLED") {
        transaction.set(
          db.collection("game_chat_outbox").doc(`${ref.id}_cancelled`),
          {
            gameId: ref.id,
            groupId: current.groupId,
            kind: "cancelled",
            status: "pending",
            createdAt: now,
          },
        );
      }
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
      target: "STARTING",
      eventType: "game_started",
      fromStatuses: ["WAITING"],
      extra: (current, now) => ({
        startedAt: current.startedAt || now,
      }),
    });
    if (!result.skipped && result.game) {
      await db.runTransaction(async (transaction) => {
        const ref = gameRef(db, request.data.gameId.trim());
        const snap = await transaction.get(ref);
        if (!snap.exists || snap.data().status !== "STARTING") return;
        transaction.update(ref, {
          status: "IN_PROGRESS",
          currentPhase: "IN_PROGRESS",
          joinLocked: true,
          playerOrder: Array.isArray(snap.data().playerOrder)
            ? [...snap.data().playerOrder] : [],
          stateVersion: (snap.data().stateVersion || 0) + 1,
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
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
    throw new HttpsError("failed-precondition", "Games cannot be paused.");
  }

  async function resumeGame(request) {
    throw new HttpsError("failed-precondition", "Games cannot be resumed.");
  }

  async function endGame(request) {
    // Completion is exclusively a server/engine operation.  In particular,
    // an administrator must not be able to manufacture a result or reward.
    throw new HttpsError(
      "failed-precondition",
      "Games can only be completed by their engine.",
    );
  }

  async function cancelGame(request) {
    const result = await mutateStatus(request, {
      target: "CANCELLED",
      eventType: "game_cancelled",
      fromStatuses: ["CREATED", "WAITING", "STARTING", "IN_PROGRESS"],
       extra: (current, now) => ({
         endedAt: now,
         currentPhase: "CANCELLED",
         joinLocked: true,
         stateVersion: (current.stateVersion || 0) + 1,
       }),
    });
    if (!result.skipped && result.game) {
      await retractAnnouncement(request.data.gameId.trim(), result.game.groupId);
    }
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
    let replay = false;
    let priorResult = null;
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
      // Idempotency is checked before terminal-state validation: a retried
      // client request must receive the prior action result even if that
      // action completed the game.
      if (prior.exists) {
        replay = true;
        priorResult = (prior.data() || {}).result || null;
        return;
      }
      if (current.status === "COMPLETED" || current.status === "CANCELLED") {
        throw new HttpsError("failed-precondition", "This game is already finished.");
      }
      if (current.status !== "IN_PROGRESS") {
        throw new HttpsError("failed-precondition", "Actions can only be submitted while the game is active.");
      }
      if (Number.isInteger(input.expectedVersion) &&
          input.expectedVersion !== Number(current.stateVersion || 0)) {
        throw new HttpsError(
          "failed-precondition",
          "The game changed; refresh before submitting another action.",
        );
      }
      if (!existing.exists || existing.data().status === "left" || existing.data().leftAt) {
        throw new HttpsError("permission-denied", "You are not a participant in this game.");
      }
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
      if (action.actionType === "resign") {
        const scores = (current.publicState && current.publicState.scores) || {};
        const winnerIds = Object.keys(scores).filter((id) => id !== uid);
        const result = {
          kind: current.type,
          winnerIds,
          scores,
          summary: { reason: "resign", resignedPlayerId: uid },
        };
        transaction.update(ref, {
          status: "COMPLETED",
          currentPhase: "game_over",
          result,
          endedAt: nowOf(),
          deadlineAt: null,
          updatedAt: now,
        });
        transaction.set(db.collection("game_history").doc(gameId), {
          gameId,
          type: current.type,
          groupId: current.groupId,
          participants: Object.keys(scores),
          result,
          endedAt: nowOf(),
          createdAt: now,
        });
        completed = result;
        completedGame = current;
      } else {
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
        transaction.update(stored, { result: outcome.result || null });
        } else {
          transaction.update(ref, { updatedAt: now });
        }
      }
    });
    if (completed && completedGame) {
      await afterComplete(gameId, completedGame, completed);
    }
    return { ok: true, actionId, replay, result: replay ? priorResult : (completed || null) };
  }

  async function processExpiredGames() {
    const now = nowOf();
    const waitingSnapshot = await db.collection("games")
      .where("status", "==", "WAITING")
      .where("deadlineAt", "<=", now)
      .orderBy("deadlineAt", "asc")
      .limit(50)
      .get();
    for (const doc of (waitingSnapshot.docs || [])) {
      let cancelledGame = null;
      await db.runTransaction(async (transaction) => {
        const ref = gameRef(db, doc.id);
        const snap = await transaction.get(ref);
        if (!snap.exists || snap.data().status !== "WAITING") return;
        cancelledGame = snap.data();
        transaction.update(ref, {
          status: "CANCELLED",
          currentPhase: "CANCELLED",
          joinLocked: true,
          stateVersion: (snap.data().stateVersion || 0) + 1,
          endedAt: now,
          updatedAt: FieldValue.serverTimestamp(),
          cancellationReason: "WAITING_TIMEOUT",
        });
        writeEvent(transaction, db, FieldValue, {
          gameId: doc.id,
          eventId: `${doc.id}_waiting_timeout`,
          type: "game_cancelled",
          actorId: null,
          payload: { reason: "WAITING_TIMEOUT" },
        });
      });
      if (cancelledGame) await retractAnnouncement(doc.id, cancelledGame.groupId);
    }
    const snapshot = await db.collection("games")
      .where("status", "==", "IN_PROGRESS")
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
      scanned: docs.length + (waitingSnapshot.docs || []).length,
      expired: docs.length + (waitingSnapshot.docs || []).length,
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
