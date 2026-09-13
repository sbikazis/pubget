"use strict";

const catalog = require("../gameCatalog");
const characterArt = require("../characterArt");
const {
  clampInt,
  isExpired,
  deadlineAt,
  secretRef,
  emptyScores,
  bumpVersion,
  historyRef,
} = require("./helpers");

const GLOBAL_TIMEOUT_SECONDS = 10 * 60;
const SELECTION_TIMEOUT_SECONDS = 45;

function configOf(game) {
  const configuration = game.configuration || {};
  return {
    questionTimerSeconds: clampInt(
      configuration.timerSeconds,
      30,
      10,
      60,
    ),
  };
}

function playersOf(game, fallback) {
  const players = game.publicState && game.publicState.playerIds;
  return Array.isArray(players) && players.length === 2
    ? players
    : fallback;
}

function opponentOf(playerIds, uid) {
  return playerIds.find((playerId) => playerId !== uid) || null;
}

function characterOptions() {
  return catalog.allCharacters().map((character) => ({
    id: character.id,
    name: character.name,
    animeId: character.animeId,
    animeTitle: character.animeTitle,
  }));
}

function publicArtworkFor(characterId) {
  const character = catalog.characterById(characterId);
  if (!character) return null;
  const raw = characterArt.publicArtwork(character.id);
  return raw && characterArt.assertArtworkSafe(raw, character) ? raw : null;
}

function normalizeYesNo(value) {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toLowerCase();
  if (["yes", "y", "true", "نعم", "ن", "oui"].includes(normalized)) {
    return "yes";
  }
  if (["no", "n", "false", "لا", "ل", "non"].includes(normalized)) {
    return "no";
  }
  return null;
}

function scoreFor(playerIds, winnerId) {
  const scores = emptyScores(playerIds);
  if (winnerId && scores[winnerId] != null) scores[winnerId] = 1;
  return scores;
}

function complete(transaction, {
  db,
  gameRef,
  FieldValue,
  game,
  gameId,
  playerIds,
  now,
  winnerIds = [],
  reason,
  scores = scoreFor(playerIds, winnerIds[0]),
}) {
  const result = {
    kind: "guessCharacter",
    winnerIds,
    scores,
    summary: {
      draw: winnerIds.length === 0,
      reason: reason || "completed",
      globalTimeoutSeconds: GLOBAL_TIMEOUT_SECONDS,
    },
  };
  const publicState = {
    ...(game.publicState || {}),
    engine: "guessCharacter",
    phase: "game_over",
    currentPlayerId: null,
    pendingQuestion: null,
    result,
    scores,
  };
  transaction.update(gameRef, {
    status: "completed",
    result,
    endedAt: now,
    publicState,
    currentPhase: "game_over",
    deadlineAt: null,
    globalDeadlineAt: null,
    stateVersion: bumpVersion(game),
    updatedAt: FieldValue.serverTimestamp(),
  });
  transaction.set(historyRef(db, gameId), {
    gameId,
    type: "guessCharacter",
    groupId: game.groupId || null,
    participants: playerIds,
    result,
    endedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  });
  return { completed: true, result };
}

function writeQuestionPhase(transaction, {
  gameRef,
  FieldValue,
  game,
  playerIds,
  now,
  scores,
  currentPlayerId,
  lastMove = null,
  lastAnswer = null,
}) {
  const cfg = configOf(game);
  transaction.update(gameRef, {
    publicState: {
      engine: "guessCharacter",
      phase: "question",
      playerIds,
      selectionStatus: Object.fromEntries(playerIds.map((id) => [id, true])),
      characterOptions: characterOptions(),
      currentPlayerId,
      pendingQuestion: null,
      lastAnswer,
      lastMove,
      scores,
    },
    currentPhase: "question",
    stateVersion: bumpVersion(game),
    deadlineAt: deadlineAt(now, cfg.questionTimerSeconds),
    globalDeadlineAt: game.globalDeadlineAt ||
      deadlineAt(now, GLOBAL_TIMEOUT_SECONDS),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

function initialize({
  transaction,
  gameRef,
  FieldValue,
  playerIds,
  game,
  now,
}) {
  if (playerIds.length !== 2) {
    throw new Error("Guess Character requires exactly two players.");
  }
  if (game.publicState && game.publicState.engine === "guessCharacter") return;
  const publicState = {
    engine: "guessCharacter",
    phase: "selection",
    playerIds,
    selectionStatus: Object.fromEntries(playerIds.map((id) => [id, false])),
    characterOptions: characterOptions(),
    currentPlayerId: null,
    pendingQuestion: null,
    lastAnswer: null,
    lastMove: null,
    scores: emptyScores(playerIds),
  };
  transaction.update(gameRef, {
    publicState,
    currentPhase: "character_selection",
    stateVersion: bumpVersion(game),
    deadlineAt: deadlineAt(now, SELECTION_TIMEOUT_SECONDS),
    globalDeadlineAt: deadlineAt(now, GLOBAL_TIMEOUT_SECONDS),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

function applyAction(ctx) {
  const {
    transaction,
    gameRef,
    FieldValue,
    game,
    uid,
    action,
    now,
    HttpsError,
    secretSnap,
    db,
    gameId,
  } = ctx;
  const state = game.publicState || {};
  const playerIds = playersOf(game, []);
  if (!playerIds.includes(uid)) {
    throw new HttpsError("permission-denied", "You are not a player in this match.");
  }
  if (isExpired(game.globalDeadlineAt, now)) {
    return complete(transaction, {
      ...ctx,
      playerIds,
      now,
      winnerIds: [],
      reason: "global_timeout",
    });
  }
  if (action.actionType === "resign" || action.actionType === "forfeit") {
    return complete(transaction, {
      ...ctx,
      playerIds,
      now,
      winnerIds: [opponentOf(playerIds, uid)].filter(Boolean),
      reason: "resigned",
      scores: scoreFor(playerIds, opponentOf(playerIds, uid)),
    });
  }
  if (isExpired(game.deadlineAt, now)) {
    throw new HttpsError("failed-precondition", "This turn has expired.");
  }

  if (state.phase === "selection") {
    if (action.actionType !== "select" && action.actionType !== "select_character") {
      throw new HttpsError("invalid-argument", "Choose a secret character.");
    }
    const characterId = action.payload && (
      action.payload.characterId || action.payload.value
    );
    const character = catalog.characterById(characterId);
    if (!character) {
      throw new HttpsError("invalid-argument", "Choose a valid catalog character.");
    }
    const secret = secretSnap && secretSnap.exists ? secretSnap.data() : {};
    const selections = { ...(secret.selections || {}) };
    const other = opponentOf(playerIds, uid);
    if (selections[other] === character.id) {
      throw new HttpsError(
        "failed-precondition",
        "Both players must choose different secret characters.",
      );
    }
    selections[uid] = character.id;
    const selectionStatus = { ...(state.selectionStatus || {}), [uid]: true };
    const allSelected = playerIds.every((playerId) => selectionStatus[playerId]);
    transaction.set(secretRef(gameRef), { ...secret, selections });
    const scores = state.scores || emptyScores(playerIds);
    if (!allSelected) {
      transaction.update(gameRef, {
        publicState: { ...state, selectionStatus },
        stateVersion: bumpVersion(game),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { completed: false, result: null };
    }
    writeQuestionPhase(transaction, {
      gameRef,
      FieldValue,
      game,
      playerIds,
      now,
      scores,
      currentPlayerId: playerIds[0],
    });
    return { completed: false, result: null };
  }

  if (state.phase === "answer") {
    if (action.actionType !== "answer") {
      throw new HttpsError("failed-precondition", "Answer the current question first.");
    }
    if (state.currentPlayerId !== uid) {
      throw new HttpsError("failed-precondition", "It is not your answer turn.");
    }
    const answer = normalizeYesNo(action.payload && (
      action.payload.answer || action.payload.value
    ));
    if (!answer) {
      throw new HttpsError("invalid-argument", "Answer yes or no.");
    }
    const nextPlayer = state.questionBy;
    transaction.update(gameRef, {
      publicState: {
        ...state,
        phase: "question",
        currentPlayerId: nextPlayer,
        pendingQuestion: null,
        lastAnswer: { answer, by: uid, question: state.pendingQuestion },
      },
      currentPhase: "question",
      stateVersion: bumpVersion(game),
      deadlineAt: deadlineAt(now, configOf(game).questionTimerSeconds),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { completed: false, result: null };
  }

  if (state.phase !== "question" || state.currentPlayerId !== uid) {
    throw new HttpsError("failed-precondition", "It is not your question turn.");
  }
  if (action.actionType === "question") {
    const question = String(action.payload?.question || action.payload?.value || "").trim();
    if (!question || question.length > 180) {
      throw new HttpsError("invalid-argument", "Ask a short yes/no question.");
    }
    const answerer = opponentOf(playerIds, uid);
    transaction.update(gameRef, {
      publicState: {
        ...state,
        phase: "answer",
        currentPlayerId: answerer,
        questionBy: uid,
        pendingQuestion: question,
      },
      currentPhase: "answer",
      stateVersion: bumpVersion(game),
      deadlineAt: deadlineAt(now, configOf(game).questionTimerSeconds),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { completed: false, result: null };
  }
  if (action.actionType !== "guess") {
    throw new HttpsError("invalid-argument", "Ask a question or make a guess.");
  }
  const guessedId = action.payload && (
    action.payload.characterId || action.payload.value
  );
  const guessed = catalog.characterById(guessedId);
  if (!guessed) {
    throw new HttpsError("invalid-argument", "Choose a valid catalog character.");
  }
  const secret = secretSnap && secretSnap.exists ? secretSnap.data() : null;
  const targetId = secret && secret.selections
    ? secret.selections[opponentOf(playerIds, uid)]
    : null;
  if (guessed.id === targetId) {
    return complete(transaction, {
      ...ctx,
      playerIds,
      now,
      winnerIds: [uid],
      reason: "correct_guess",
      scores: scoreFor(playerIds, uid),
    });
  }
  const nextPlayer = opponentOf(playerIds, uid);
  transaction.update(gameRef, {
    publicState: {
      ...state,
      currentPlayerId: nextPlayer,
      lastMove: { type: "wrong_guess", playerId: uid, characterId: guessed.id },
      pendingQuestion: null,
    },
    currentPhase: "question",
    stateVersion: bumpVersion(game),
    deadlineAt: deadlineAt(now, configOf(game).questionTimerSeconds),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { completed: false, result: null };
}

function onTimeout(ctx) {
  const { game, now, secretSnap, playerIds: fallback = [] } = ctx;
  const state = game.publicState || {};
  const playerIds = playersOf(game, fallback);
  if (isExpired(game.globalDeadlineAt, now)) {
    return complete(ctx.transaction, {
      ...ctx,
      playerIds,
      now,
      winnerIds: [],
      reason: "global_timeout",
    });
  }
  if (state.phase === "selection") {
    const secret = secretSnap && secretSnap.exists ? secretSnap.data() : {};
    const selected = secret.selections || {};
    const missing = playerIds.filter((id) => !selected[id]);
    if (missing.length === 1) {
      return complete(ctx.transaction, {
        ...ctx,
        playerIds,
        now,
        winnerIds: [opponentOf(playerIds, missing[0])].filter(Boolean),
        reason: "selection_forfeit",
      });
    }
    return complete(ctx.transaction, {
      ...ctx,
      playerIds,
      now,
      winnerIds: [],
      reason: "selection_timeout",
    });
  }
  const winner = opponentOf(playerIds, state.currentPlayerId);
  return complete(ctx.transaction, {
    ...ctx,
    playerIds,
    now,
    winnerIds: [winner].filter(Boolean),
    reason: "turn_timeout",
  });
}

module.exports = {
  initialize,
  applyAction,
  onTimeout,
  normalizeYesNo,
};