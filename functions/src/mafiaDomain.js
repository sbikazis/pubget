"use strict";

// Mafia domain (PROMPT 13).
//
// Generic Games Engine stays responsible for create/join/leave/start/end.
// This module owns Mafia-only rules: roles, phases, night/day, voting,
// elimination, and win conditions. Hidden data lives under
// games/{id}/secret (client-unreadable) and games/{id}/private/{uid}
// (self-only).
//
// Tie-breaking (not specified by Pubget 1.0, documented here):
//   Night: plurality of living Mafia kill votes; a tie means no kill.
//   Day vote: plurality of living players; a tie means no elimination.
// Mafia cannot target themselves or living teammates.
// Detective cannot investigate themselves.
// Doctor may protect themselves.
// Night actions are locked after the first valid submit for that round.
// Votes may be changed until voting ends; the latest vote counts.

const { randomBytes: nodeRandomBytes } = require("node:crypto");

const ROLES = ["mafia", "civilian", "detective", "doctor"];
const TEAMS = { mafia: "mafia", civilian: "town", detective: "town", doctor: "town" };

const PHASES = [
  "setup", "night", "day", "discussion", "voting", "resolution", "finished",
];

const PHASE_TRANSITIONS = {
  setup: new Set(["night"]),
  night: new Set(["day", "finished"]),
  day: new Set(["discussion", "finished"]),
  discussion: new Set(["voting", "finished"]),
  voting: new Set(["resolution", "finished"]),
  resolution: new Set(["night", "finished"]),
  finished: new Set(),
};

const MIN_PLAYERS = 4;
const MAX_PLAYERS = 16;
const DEFAULT_NIGHT_SECONDS = 45;
const DEFAULT_DAY_SECONDS = 20;
const DEFAULT_DISCUSSION_SECONDS = 90;
const DEFAULT_VOTING_SECONDS = 45;

const NIGHT_ACTIONS = new Set(["mafia_kill", "mafia_investigate", "mafia_protect"]);

function clampInt(value, fallback, min, max) {
  const n = Number.isInteger(value) ? value : Number.parseInt(value, 10);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

function defaultRoleCounts(playerCount) {
  const mafiaCount = Math.max(1, Math.floor(playerCount / 4));
  const doctorCount = playerCount >= 5 ? 1 : 0;
  const detectiveCount = playerCount >= 6 ? 1 : 0;
  const civilianCount = playerCount - mafiaCount - doctorCount - detectiveCount;
  return { mafiaCount, doctorCount, detectiveCount, civilianCount };
}

function validateMafiaConfig(raw, specCaps = {}) {
  const input = raw && typeof raw === "object" ? raw : {};
  const extra = input.extra && typeof input.extra === "object" ? input.extra : input;
  const minPlayers = clampInt(
    input.minPlayers ?? extra.minPlayers,
    specCaps.minPlayers || MIN_PLAYERS,
    MIN_PLAYERS,
    MAX_PLAYERS,
  );
  const maxPlayers = clampInt(
    input.maxPlayers ?? extra.maxPlayers,
    specCaps.maxPlayers || MAX_PLAYERS,
    minPlayers,
    MAX_PLAYERS,
  );
  const nightDurationSeconds = clampInt(
    extra.nightDurationSeconds, DEFAULT_NIGHT_SECONDS, 10, 600,
  );
  const dayDurationSeconds = clampInt(
    extra.dayDurationSeconds, DEFAULT_DAY_SECONDS, 5, 600,
  );
  const discussionDurationSeconds = clampInt(
    extra.discussionDurationSeconds, DEFAULT_DISCUSSION_SECONDS, 10, 600,
  );
  const votingDurationSeconds = clampInt(
    extra.votingDurationSeconds, DEFAULT_VOTING_SECONDS, 10, 600,
  );
  const mafiaCount = extra.mafiaCount == null ? null
    : clampInt(extra.mafiaCount, 1, 1, MAX_PLAYERS - 1);
  const detectiveCount = extra.detectiveCount == null ? null
    : clampInt(extra.detectiveCount, 0, 0, 2);
  const doctorCount = extra.doctorCount == null ? null
    : clampInt(extra.doctorCount, 0, 0, 2);
  return {
    minPlayers,
    maxPlayers,
    usesRounds: true,
    extra: {
      mafiaCount,
      detectiveCount,
      doctorCount,
      nightDurationSeconds,
      dayDurationSeconds,
      discussionDurationSeconds,
      votingDurationSeconds,
      deadCanSpectate: extra.deadCanSpectate !== false,
      deadCanChat: false,
    },
  };
}

function resolveRoleCounts(playerCount, extra = {}) {
  const auto = defaultRoleCounts(playerCount);
  const mafiaCount = extra.mafiaCount == null ? auto.mafiaCount : extra.mafiaCount;
  const detectiveCount = extra.detectiveCount == null
    ? auto.detectiveCount : extra.detectiveCount;
  const doctorCount = extra.doctorCount == null ? auto.doctorCount : extra.doctorCount;
  const civilianCount = playerCount - mafiaCount - detectiveCount - doctorCount;
  if (mafiaCount < 1 || civilianCount < 1 || detectiveCount < 0 || doctorCount < 0) {
    return null;
  }
  if (mafiaCount + detectiveCount + doctorCount + civilianCount !== playerCount) {
    return null;
  }
  return { mafiaCount, detectiveCount, doctorCount, civilianCount };
}

function canTransitionPhase(from, to) {
  return PHASES.includes(from) && PHASES.includes(to) &&
    PHASE_TRANSITIONS[from] && PHASE_TRANSITIONS[from].has(to);
}

function assertPhaseTransition(from, to, HttpsError) {
  if (!canTransitionPhase(from, to)) {
    throw new HttpsError(
      "failed-precondition",
      `Cannot move Mafia from ${from} to ${to}.`,
    );
  }
}

function shuffle(items, randomBytesFn) {
  const bytes = randomBytesFn || nodeRandomBytes;
  const result = [...items];
  for (let i = result.length - 1; i > 0; i -= 1) {
    const buf = bytes(4);
    const n = Buffer.isBuffer(buf) ? buf.readUInt32BE(0) : buf[0];
    const j = n % (i + 1);
    const tmp = result[i];
    result[i] = result[j];
    result[j] = tmp;
  }
  return result;
}

function assignRoles(userIds, counts, randomBytesFn) {
  const ids = [...userIds].sort();
  const deck = [
    ...Array(counts.mafiaCount).fill("mafia"),
    ...Array(counts.detectiveCount).fill("detective"),
    ...Array(counts.doctorCount).fill("doctor"),
    ...Array(counts.civilianCount).fill("civilian"),
  ];
  if (deck.length !== ids.length) {
    throw new Error("Role deck does not match participant count.");
  }
  const shuffled = shuffle(deck, randomBytesFn);
  const roles = {};
  ids.forEach((id, index) => {
    roles[id] = shuffled[index];
  });
  return roles;
}

function livingIds(roles, alive) {
  return Object.keys(roles).filter((id) => alive[id] !== false);
}

function checkWinner(roles, alive) {
  const living = livingIds(roles, alive);
  let mafiaCount = 0;
  let townCount = 0;
  for (const id of living) {
    if (roles[id] === "mafia") mafiaCount += 1;
    else townCount += 1;
  }
  if (mafiaCount === 0) return "town";
  if (mafiaCount >= townCount) return "mafia";
  return null;
}

function plurality(votesByActor, eligibleActors, eligibleTargets) {
  const tally = {};
  for (const [actor, target] of Object.entries(votesByActor || {})) {
    if (!eligibleActors.has(actor) || !eligibleTargets.has(target)) continue;
    tally[target] = (tally[target] || 0) + 1;
  }
  let best = 0;
  const leaders = [];
  for (const [target, count] of Object.entries(tally)) {
    if (count > best) {
      best = count;
      leaders.length = 0;
      leaders.push(target);
    } else if (count === best && count > 0) {
      leaders.push(target);
    }
  }
  if (best === 0 || leaders.length !== 1) {
    return { tally, winnerId: null, tied: leaders.length > 1 };
  }
  return { tally, winnerId: leaders[0], tied: false };
}

function resolveNight({ roles, alive, kills, protect }) {
  const livingMafia = new Set(
    livingIds(roles, alive).filter((id) => roles[id] === "mafia"),
  );
  const living = new Set(livingIds(roles, alive));
  const { tally, winnerId } = plurality(kills || {}, livingMafia, living);
  const protectedId = living.has(protect) ? protect : null;
  const saved = Boolean(winnerId && protectedId && winnerId === protectedId);
  const eliminatedUserId = saved || !winnerId ? null : winnerId;
  return {
    tally,
    mafiaTargetId: winnerId,
    protectedId,
    saved,
    eliminatedUserId,
  };
}

function resolveVotes({ roles, alive, votes }) {
  const living = new Set(livingIds(roles, alive));
  return plurality(votes || {}, living, living);
}

function durationSecondsFor(phase, extra) {
  if (phase === "night") return extra.nightDurationSeconds || DEFAULT_NIGHT_SECONDS;
  if (phase === "day") return extra.dayDurationSeconds || DEFAULT_DAY_SECONDS;
  if (phase === "discussion") {
    return extra.discussionDurationSeconds || DEFAULT_DISCUSSION_SECONDS;
  }
  if (phase === "voting") return extra.votingDurationSeconds || DEFAULT_VOTING_SECONDS;
  return 0;
}

function publicMafiaState({
  phase, roundNumber, phaseStartedAt, phaseEndsAt,
  deadUserIds = [], lastNight = null, lastVote = null, winner = null,
}) {
  return {
    phase,
    roundNumber,
    phaseStartedAt,
    phaseEndsAt,
    deadUserIds,
    lastNight,
    lastVote,
    winner,
  };
}

function dateOf(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === "function") return value.toDate();
  if (typeof value === "string" || typeof value === "number") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  return null;
}

function gameRef(db, gameId) {
  return db.collection("games").doc(gameId);
}

function participantRef(db, gameId, uid) {
  return gameRef(db, gameId).collection("participants").doc(uid);
}

function privateRef(db, gameId, uid) {
  return gameRef(db, gameId).collection("private").doc(uid);
}

function secretRef(db, gameId) {
  return gameRef(db, gameId).collection("secret").doc("state");
}

function eventCollection(db, gameId) {
  return gameRef(db, gameId).collection("events");
}

function writeEvent(transaction, db, FieldValue, {
  gameId, eventId, type, actorId, payload,
}) {
  const ref = eventId
    ? eventCollection(db, gameId).doc(eventId)
    : eventCollection(db, gameId).doc();
  // Deterministic IDs make duplicate lifecycle ticks no-ops.
  transaction.set(ref, {
    eventId: eventId || ref.id,
    gameId,
    type,
    actorId: actorId || "system",
    payload: payload || {},
    schemaVersion: 1,
    createdAt: FieldValue.serverTimestamp(),
  }, { merge: true });
}

function notifySafe(builder, payload) {
  if (!builder || typeof builder.build !== "function") return Promise.resolve();
  return builder.build(payload).catch(() => {});
}

function createMafiaDomain({
  db, FieldValue, HttpsError, notificationBuilder,
  randomBytes = nodeRandomBytes,
}) {
  function endsAt(seconds) {
    return new Date(Date.now() + seconds * 1000);
  }

  function loadAliveMap(people) {
    const alive = {};
    const active = [];
    for (const doc of people) {
      const data = doc.data() || {};
      if (data.status === "left" || data.leftAt) continue;
      active.push(doc);
      alive[doc.id] = data.isAlive !== false;
    }
    return { alive, active };
  }

  async function listParticipants(transaction, gameId) {
    const col = gameRef(db, gameId).collection("participants");
    if (typeof transaction.get === "function") {
      const snap = await transaction.get(col);
      if (snap && Array.isArray(snap.docs)) return snap.docs;
      if (snap && snap.docs) return snap.docs;
    }
    const fallback = await col.get();
    return fallback.docs;
  }

  function applyPhase(transaction, ref, current, {
    phase, roundNumber, now, extra, lastNight, lastVote, winner, deadUserIds,
  }) {
    const seconds = durationSecondsFor(phase, extra);
    const mafia = publicMafiaState({
      phase,
      roundNumber,
      phaseStartedAt: now,
      phaseEndsAt: seconds > 0 ? endsAt(seconds) : null,
      deadUserIds: deadUserIds || (current.mafia && current.mafia.deadUserIds) || [],
      lastNight: lastNight === undefined
        ? (current.mafia && current.mafia.lastNight) : lastNight,
      lastVote: lastVote === undefined
        ? (current.mafia && current.mafia.lastVote) : lastVote,
      winner: winner === undefined ? (current.mafia && current.mafia.winner) : winner,
    });
    transaction.update(ref, {
      mafia,
      currentRoundNumber: roundNumber,
      updatedAt: now,
    });
    return mafia;
  }

  function finishGame(transaction, ref, current, {
    winner, roles, now, lastNight, lastVote, deadUserIds,
  }) {
    const mafia = publicMafiaState({
      phase: "finished",
      roundNumber: (current.mafia && current.mafia.roundNumber) || 1,
      phaseStartedAt: now,
      phaseEndsAt: null,
      deadUserIds: deadUserIds || (current.mafia && current.mafia.deadUserIds) || [],
      lastNight: lastNight === undefined
        ? (current.mafia && current.mafia.lastNight) : lastNight,
      lastVote: lastVote === undefined
        ? (current.mafia && current.mafia.lastVote) : lastVote,
      winner,
    });
    transaction.update(ref, {
      status: "completed",
      mafia,
      result: {
        kind: "mafia",
        winnerIds: winner ? [winner] : [],
        scores: {},
        summary: { winner, roles },
      },
      endedAt: now,
      updatedAt: now,
    });
    return mafia;
  }

  async function onStart(transaction, {
    ref, current, uid, now, gameId,
  }) {
    const extra = (current.configuration && current.configuration.extra) || {};
    const people = await listParticipants(transaction, gameId);
    const { alive, active } = loadAliveMap(people);
    const ids = active.map((doc) => doc.id);
    const minPlayers = (current.configuration && current.configuration.minPlayers)
      || MIN_PLAYERS;
    if (ids.length < minPlayers) {
      throw new HttpsError("failed-precondition", "Not enough players to start.");
    }
    if (ids.length > ((current.configuration && current.configuration.maxPlayers)
        || MAX_PLAYERS)) {
      throw new HttpsError("failed-precondition", "Too many players to start.");
    }
    const counts = resolveRoleCounts(ids.length, extra);
    if (!counts) {
      throw new HttpsError("failed-precondition", "Mafia role configuration is invalid.");
    }
    const roles = assignRoles(ids, counts, randomBytes);
    const secret = {
      roles,
      night: {},
      votes: {},
      resolvedNights: {},
      resolvedVotes: {},
    };
    transaction.set(secretRef(db, gameId), secret);
    for (const doc of active) {
      const role = roles[doc.id];
      const teammates = role === "mafia"
        ? ids.filter((id) => roles[id] === "mafia" && id !== doc.id)
        : [];
      transaction.set(privateRef(db, gameId, doc.id), {
        userId: doc.id,
        role,
        team: TEAMS[role],
        teammates,
        investigations: [],
        investigation: null,
      });
      transaction.update(participantRef(db, gameId, doc.id), {
        isAlive: true,
      });
      alive[doc.id] = true;
    }
    const mafia = applyPhase(transaction, ref, current, {
      phase: "night",
      roundNumber: 1,
      now,
      extra,
      deadUserIds: [],
      lastNight: null,
      lastVote: null,
      winner: null,
    });
    writeEvent(transaction, db, FieldValue, {
      gameId,
      eventId: `${gameId}_mafia_started`,
      type: "mafia_game_started",
      actorId: uid,
      payload: { roundNumber: 1 },
    });
    writeEvent(transaction, db, FieldValue, {
      gameId,
      eventId: `${gameId}_mafia_night_1`,
      type: "mafia_night_started",
      actorId: "system",
      payload: { roundNumber: 1 },
    });
    return { mafia, roles, alive };
  }

  function actionKindForRole(role) {
    if (role === "mafia") return "mafia_kill";
    if (role === "detective") return "mafia_investigate";
    if (role === "doctor") return "mafia_protect";
    return null;
  }

  async function submitAction(transaction, {
    gameId, uid, actionType, payload, current, person,
  }) {
    const mafia = current.mafia || {};
    const phase = mafia.phase;
    if (current.status !== "active" || phase === "finished") {
      throw new HttpsError("failed-precondition", "This game is already finished.");
    }
    if (person.isAlive === false) {
      throw new HttpsError("failed-precondition", "Eliminated players cannot act.");
    }
    const secretSnap = await transaction.get(secretRef(db, gameId));
    if (!secretSnap.exists) {
      throw new HttpsError("failed-precondition", "Mafia state is missing.");
    }
    const secret = secretSnap.data() || {};
    const roles = secret.roles || {};
    const role = roles[uid];
    if (!role) {
      throw new HttpsError("permission-denied", "You are not a participant in this game.");
    }
    const targetId = payload && typeof payload.targetId === "string"
      ? payload.targetId.trim() : "";
    const roundNumber = mafia.roundNumber || 1;

    if (NIGHT_ACTIONS.has(actionType)) {
      if (phase !== "night") {
        throw new HttpsError("failed-precondition", "Night actions are closed.");
      }
      const expected = actionKindForRole(role);
      if (!expected || expected !== actionType) {
        throw new HttpsError("permission-denied", "Your role cannot submit that action.");
      }
      if (!targetId || !roles[targetId]) {
        throw new HttpsError("invalid-argument", "A valid living target is required.");
      }
      const targetPerson = await transaction.get(participantRef(db, gameId, targetId));
      if (!targetPerson.exists || targetPerson.data().status === "left" ||
          targetPerson.data().isAlive === false) {
        throw new HttpsError("failed-precondition", "That player is not a valid target.");
      }
      if (actionType === "mafia_kill") {
        if (targetId === uid || roles[targetId] === "mafia") {
          throw new HttpsError("failed-precondition", "Mafia cannot target that player.");
        }
      }
      if (actionType === "mafia_investigate" && targetId === uid) {
        throw new HttpsError("failed-precondition", "You cannot investigate yourself.");
      }
      const night = { ...(secret.night || {}) };
      const round = { ...(night[roundNumber] || { kills: {}, investigate: {}, protect: {} }) };
      const bucket = actionType === "mafia_kill" ? "kills"
        : (actionType === "mafia_investigate" ? "investigate" : "protect");
      if (round[bucket][uid] && round[bucket][uid] !== targetId) {
        throw new HttpsError("already-exists", "You already submitted a night action.");
      }
      if (round[bucket][uid] === targetId) return { ok: true, duplicate: true };
      round[bucket] = { ...round[bucket], [uid]: targetId };
      night[roundNumber] = round;
      transaction.update(secretRef(db, gameId), { night });
      const privateSnap = await transaction.get(privateRef(db, gameId, uid));
      const prev = privateSnap.exists ? (privateSnap.data() || {}) : {};
      transaction.set(privateRef(db, gameId, uid), {
        ...prev,
        submittedNightAction: true,
        nightActionRound: roundNumber,
      });
      return { ok: true };
    }

    if (actionType === "mafia_vote") {
      if (phase !== "voting") {
        throw new HttpsError("failed-precondition", "Voting is closed.");
      }
      if (!targetId || !roles[targetId]) {
        throw new HttpsError("invalid-argument", "A valid living target is required.");
      }
      const targetPerson = await transaction.get(participantRef(db, gameId, targetId));
      if (!targetPerson.exists || targetPerson.data().isAlive === false) {
        throw new HttpsError("failed-precondition", "That player is not a valid target.");
      }
      const votes = { ...(secret.votes || {}) };
      votes[roundNumber] = { ...(votes[roundNumber] || {}), [uid]: targetId };
      transaction.update(secretRef(db, gameId), { votes });
      const privateSnap = await transaction.get(privateRef(db, gameId, uid));
      const prev = privateSnap.exists ? (privateSnap.data() || {}) : {};
      transaction.set(privateRef(db, gameId, uid), {
        ...prev,
        voteTargetId: targetId,
        voteRound: roundNumber,
      });
      return { ok: true };
    }

    throw new HttpsError("invalid-argument", "Unknown Mafia action.");
  }

  function eliminate(transaction, gameId, userId, now) {
    transaction.update(participantRef(db, gameId, userId), {
      isAlive: false,
      eliminatedAt: now,
    });
  }

  async function resolveNightPhase(transaction, {
    ref, current, gameId, now, extra, secret, people,
  }) {
    const roundNumber = (current.mafia && current.mafia.roundNumber) || 1;
    if (secret.resolvedNights && secret.resolvedNights[roundNumber]) {
      return { skipped: true };
    }
    const { alive } = loadAliveMap(people);
    const round = (secret.night && secret.night[roundNumber]) || {};
    const protectIds = Object.values(round.protect || {});
    const protect = protectIds.length === 1 ? protectIds[0] : (
      protectIds.length > 1 ? protectIds.sort()[0] : null
    );
    const result = resolveNight({
      roles: secret.roles,
      alive,
      kills: round.kills || {},
      protect,
    });
    const deadUserIds = [...((current.mafia && current.mafia.deadUserIds) || [])];
    if (result.eliminatedUserId) {
      alive[result.eliminatedUserId] = false;
      deadUserIds.push(result.eliminatedUserId);
      eliminate(transaction, gameId, result.eliminatedUserId, now);
    }
    const investigations = round.investigate || {};
    for (const [detectiveId, targetId] of Object.entries(investigations)) {
      if (secret.roles[detectiveId] !== "detective") continue;
      const isMafia = secret.roles[targetId] === "mafia";
      const privateDoc = await transaction.get(privateRef(db, gameId, detectiveId));
      const prev = privateDoc.exists ? privateDoc.data() : {};
      const history = Array.isArray(prev.investigations) ? prev.investigations : [];
      transaction.set(privateRef(db, gameId, detectiveId), {
        ...prev,
        investigation: { roundNumber, targetId, isMafia },
        investigations: [...history, { roundNumber, targetId, isMafia }],
      });
    }
    const resolvedNights = { ...(secret.resolvedNights || {}), [roundNumber]: true };
    transaction.update(secretRef(db, gameId), { resolvedNights });
    const lastNight = {
      roundNumber,
      eliminatedUserId: result.eliminatedUserId,
      saved: result.saved,
    };
    writeEvent(transaction, db, FieldValue, {
      gameId,
      eventId: `${gameId}_mafia_night_resolved_${roundNumber}`,
      type: "mafia_night_resolved",
      actorId: "system",
      payload: {
        roundNumber,
        eliminatedUserId: result.eliminatedUserId,
        saved: result.saved,
      },
    });
    if (result.eliminatedUserId) {
      writeEvent(transaction, db, FieldValue, {
        gameId,
        eventId: `${gameId}_mafia_elim_night_${roundNumber}`,
        type: "mafia_player_eliminated",
        actorId: "system",
        payload: { userId: result.eliminatedUserId, cause: "night", roundNumber },
      });
    }
    const winner = checkWinner(secret.roles, alive);
    if (winner) {
      finishGame(transaction, ref, current, {
        winner, roles: secret.roles, now, lastNight, deadUserIds,
      });
      writeEvent(transaction, db, FieldValue, {
        gameId,
        eventId: `${gameId}_mafia_completed`,
        type: "mafia_game_completed",
        actorId: "system",
        payload: { winner },
      });
      return { winner, lastNight, notify: "completed" };
    }
    applyPhase(transaction, ref, current, {
      phase: "day",
      roundNumber,
      now,
      extra,
      lastNight,
      deadUserIds,
    });
    writeEvent(transaction, db, FieldValue, {
      gameId,
      eventId: `${gameId}_mafia_day_${roundNumber}`,
      type: "mafia_day_started",
      actorId: "system",
      payload: { roundNumber },
    });
    return { lastNight, winner: null, notify: "day" };
  }

  async function resolveVotePhase(transaction, {
    ref, current, gameId, now, extra, secret, people,
  }) {
    const roundNumber = (current.mafia && current.mafia.roundNumber) || 1;
    if (secret.resolvedVotes && secret.resolvedVotes[roundNumber]) {
      return { skipped: true };
    }
    const { alive } = loadAliveMap(people);
    const result = resolveVotes({
      roles: secret.roles,
      alive,
      votes: (secret.votes && secret.votes[roundNumber]) || {},
    });
    const deadUserIds = [...((current.mafia && current.mafia.deadUserIds) || [])];
    if (result.winnerId) {
      alive[result.winnerId] = false;
      deadUserIds.push(result.winnerId);
      eliminate(transaction, gameId, result.winnerId, now);
    }
    const resolvedVotes = { ...(secret.resolvedVotes || {}), [roundNumber]: true };
    transaction.update(secretRef(db, gameId), { resolvedVotes });
    const lastVote = {
      roundNumber,
      eliminatedUserId: result.winnerId,
      tied: result.tied,
      tallies: result.tally,
    };
    writeEvent(transaction, db, FieldValue, {
      gameId,
      eventId: `${gameId}_mafia_vote_resolved_${roundNumber}`,
      type: "mafia_vote_resolved",
      actorId: "system",
      payload: {
        roundNumber,
        eliminatedUserId: result.winnerId,
        tied: result.tied,
      },
    });
    if (result.winnerId) {
      writeEvent(transaction, db, FieldValue, {
        gameId,
        eventId: `${gameId}_mafia_elim_vote_${roundNumber}`,
        type: "mafia_player_eliminated",
        actorId: "system",
        payload: { userId: result.winnerId, cause: "vote", roundNumber },
      });
    }
    const winner = checkWinner(secret.roles, alive);
    if (winner) {
      finishGame(transaction, ref, current, {
        winner, roles: secret.roles, now, lastVote, deadUserIds,
      });
      writeEvent(transaction, db, FieldValue, {
        gameId,
        eventId: `${gameId}_mafia_completed`,
        type: "mafia_game_completed",
        actorId: "system",
        payload: { winner },
      });
      return { winner, lastVote, notify: "completed" };
    }
    const nextRound = roundNumber + 1;
    applyPhase(transaction, ref, current, {
      phase: "night",
      roundNumber: nextRound,
      now,
      extra,
      lastVote,
      deadUserIds,
    });
    writeEvent(transaction, db, FieldValue, {
      gameId,
      eventId: `${gameId}_mafia_night_${nextRound}`,
      type: "mafia_night_started",
      actorId: "system",
      payload: { roundNumber: nextRound },
    });
    return { lastVote, winner: null, nextRound, notify: "night" };
  }

  async function advancePhase(transaction, {
    ref, current, gameId, now, force = false,
  }) {
    if (current.type !== "mafia" || current.status !== "active") return { skipped: true };
    const mafia = current.mafia || {};
    const phase = mafia.phase;
    if (!phase || phase === "finished" || phase === "setup") return { skipped: true };
    const ends = dateOf(mafia.phaseEndsAt);
    if (!force && ends && ends.getTime() > Date.now()) {
      return { skipped: true, notExpired: true };
    }
    const extra = (current.configuration && current.configuration.extra) || {};
    const secretSnap = await transaction.get(secretRef(db, gameId));
    if (!secretSnap.exists) {
      throw new HttpsError("failed-precondition", "Mafia state is missing.");
    }
    const secret = secretSnap.data() || {};
    const people = await listParticipants(transaction, gameId);
    if (phase === "night") {
      return resolveNightPhase(transaction, {
        ref, current, gameId, now, extra, secret, people,
      });
    }
    if (phase === "day") {
      assertPhaseTransition("day", "discussion", HttpsError);
      applyPhase(transaction, ref, current, {
        phase: "discussion",
        roundNumber: mafia.roundNumber || 1,
        now,
        extra,
      });
      return { phase: "discussion", notify: "discussion" };
    }
    if (phase === "discussion") {
      assertPhaseTransition("discussion", "voting", HttpsError);
      applyPhase(transaction, ref, current, {
        phase: "voting",
        roundNumber: mafia.roundNumber || 1,
        now,
        extra,
      });
      writeEvent(transaction, db, FieldValue, {
        gameId,
        eventId: `${gameId}_mafia_voting_${mafia.roundNumber || 1}`,
        type: "mafia_voting_started",
        actorId: "system",
        payload: { roundNumber: mafia.roundNumber || 1 },
      });
      return { phase: "voting", notify: "voting", roundNumber: mafia.roundNumber || 1 };
    }
    if (phase === "voting") {
      return resolveVotePhase(transaction, {
        ref, current, gameId, now, extra, secret, people,
      });
    }
    return { skipped: true };
  }

  async function listRecipientIds(gameId) {
    const snapshot = await gameRef(db, gameId).collection("participants").get();
    return snapshot.docs
      .filter((doc) => {
        const data = doc.data() || {};
        return data.status !== "left" && !data.leftAt;
      })
      .map((doc) => doc.id);
  }

  async function livingActionRecipientIds(gameId) {
    const [secretSnap, people] = await Promise.all([
      secretRef(db, gameId).get(),
      gameRef(db, gameId).collection("participants").get(),
    ]);
    const roles = (secretSnap.exists && secretSnap.data().roles) || {};
    const actionRoles = new Set(["mafia", "detective", "doctor"]);
    return people.docs
      .filter((doc) => {
        const data = doc.data() || {};
        if (data.status === "left" || data.leftAt || data.isAlive === false) {
          return false;
        }
        return actionRoles.has(roles[doc.id]);
      })
      .map((doc) => doc.id);
  }

  async function notifyMafia(kind, { gameId, actorId, winner, roundNumber }) {
    const destination = `/game/${gameId}`;
    const metadata = { gameType: "mafia" };
    if (kind === "completed") {
      const recipientIds = await listRecipientIds(gameId);
      if (recipientIds.length === 0) return;
      await notifySafe(notificationBuilder, {
        id: `game-completed-${gameId}`,
        recipientIds,
        type: "game_completed",
        actorId: actorId || "system",
        targetId: gameId,
        action: "completed",
        destination,
        metadata,
        title: "Game completed",
        body: winner === "mafia" ? "Mafia wins." : "Town wins.",
        pushWorthy: false,
      });
      return;
    }
    if (kind === "voting") {
      const recipientIds = await listRecipientIds(gameId);
      if (recipientIds.length === 0) return;
      await notifySafe(notificationBuilder, {
        id: `mafia-voting-${gameId}-${roundNumber || 1}`,
        recipientIds,
        type: "game_started",
        actorId: actorId || "system",
        targetId: gameId,
        action: "voting",
        destination,
        metadata,
        title: "Voting started",
        body: "Alive players can now vote.",
        pushWorthy: true,
      });
      return;
    }
    if (kind === "night") {
      const recipientIds = await livingActionRecipientIds(gameId);
      if (recipientIds.length === 0) return;
      await notifySafe(notificationBuilder, {
        id: `mafia-night-action-${gameId}-${roundNumber || 1}`,
        recipientIds,
        type: "game_started",
        actorId: actorId || "system",
        targetId: gameId,
        action: "night",
        destination,
        metadata,
        title: "Night action required",
        body: "Your night action is required.",
        pushWorthy: true,
      });
    }
  }

  async function notifyAdvanceResult(gameId, result, actorId) {
    if (!result || result.skipped || result.notExpired) return;
    if (result.notify === "completed") {
      await notifyMafia("completed", { gameId, actorId, winner: result.winner });
    } else if (result.notify === "voting") {
      await notifyMafia("voting", { gameId, actorId, roundNumber: result.roundNumber });
    } else if (result.notify === "night") {
      await notifyMafia("night", {
        gameId, actorId, roundNumber: result.nextRound,
      });
    }
  }

  async function advanceMafiaPhase(request) {
    const uid = request && request.auth && request.auth.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Authentication is required.");
    const gameId = request.data && request.data.gameId;
    if (typeof gameId !== "string" || !gameId.trim()) {
      throw new HttpsError("invalid-argument", "gameId is required.");
    }
    const ref = gameRef(db, gameId.trim());
    let advanceResult = null;
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw new HttpsError("not-found", "Game not found.");
      const current = snapshot.data() || {};
      if (current.type !== "mafia") {
        throw new HttpsError("failed-precondition", "This is not a Mafia game.");
      }
      const person = await transaction.get(participantRef(db, ref.id, uid));
      if (!person.exists && current.creatorId !== uid) {
        throw new HttpsError("permission-denied", "You cannot advance this game.");
      }
      const now = FieldValue.serverTimestamp();
      const result = await advancePhase(transaction, {
        ref, current, gameId: ref.id, now, force: false,
      });
      if (result && result.notExpired) {
        throw new HttpsError("failed-precondition", "This phase has not expired.");
      }
      advanceResult = result;
    });
    await notifyAdvanceResult(ref.id, advanceResult, uid);
    return {
      ok: true,
      startedVoting: Boolean(advanceResult && advanceResult.notify === "voting"),
      startedNight: Boolean(advanceResult && advanceResult.notify === "night"),
    };
  }

  async function processMafiaLifecycle() {
    const snapshot = await db.collection("games")
      .where("status", "==", "active")
      .where("type", "==", "mafia")
      .limit(25)
      .get();
    for (const doc of snapshot.docs) {
      const data = doc.data() || {};
      const ends = dateOf(data.mafia && data.mafia.phaseEndsAt);
      if (ends && ends.getTime() > Date.now()) continue;
      try {
        let advanceResult = null;
        await db.runTransaction(async (transaction) => {
          const snap = await transaction.get(doc.ref);
          if (!snap.exists) return;
          const current = snap.data() || {};
          advanceResult = await advancePhase(transaction, {
            ref: doc.ref,
            current,
            gameId: doc.id,
            now: FieldValue.serverTimestamp(),
            force: false,
          });
        });
        await notifyAdvanceResult(doc.id, advanceResult, "system");
      } catch (_) {
        // Skip a busy/invalid game; the next tick retries.
      }
    }
    return { ok: true };
  }

  return {
    onStart,
    submitAction,
    advanceMafiaPhase,
    processMafiaLifecycle,
    notifyMafia,
  };
}

module.exports = {
  ROLES,
  PHASES,
  PHASE_TRANSITIONS,
  MIN_PLAYERS,
  MAX_PLAYERS,
  DEFAULT_NIGHT_SECONDS,
  DEFAULT_DAY_SECONDS,
  DEFAULT_DISCUSSION_SECONDS,
  DEFAULT_VOTING_SECONDS,
  canTransitionPhase,
  assertPhaseTransition,
  defaultRoleCounts,
  resolveRoleCounts,
  validateMafiaConfig,
  assignRoles,
  checkWinner,
  resolveNight,
  resolveVotes,
  durationSecondsFor,
  publicMafiaState,
  createMafiaDomain,
};
