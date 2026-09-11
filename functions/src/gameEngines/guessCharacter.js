"use strict";

const catalog = require("../gameCatalog");
const {
  clampInt,
  isExpired,
  deadlineAt,
  secretRef,
  privateRef,
  historyRef,
  rejectStale,
  bumpVersion,
} = require("./helpers");

const GLOBAL_SECONDS = 10 * 60;

function configOf(game) {
  const c = game.configuration || {};
  return {
    selectionSeconds: clampInt(c.selectionSeconds, 45, 10, 120),
    timerSeconds: clampInt(c.timerSeconds, 30, 10, 90),
  };
}

function idsOf(game, playerIds) {
  return playerIds && playerIds.length
    ? playerIds
    : Object.keys((game.publicState && game.publicState.players) || {});
}

function millis(value) {
  if (!value) return 0;
  if (typeof value === "number") return value;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (typeof value.toDate === "function") return value.toDate().getTime();
  if (value instanceof Date) return value.getTime();
  return 0;
}

function globalDeadline(game, now) {
  const started = millis(game.startedAt) || now.getTime();
  return new Date(Math.min(started + GLOBAL_SECONDS * 1000,
    now.getTime() + GLOBAL_SECONDS * 1000));
}

function endGame(transaction, ctx, winnerIds, reason) {
  const { db, gameRef, FieldValue, game, gameId, now } = ctx;
  const players = idsOf(game);
  const scores = {};
  for (const id of players) scores[id] = 0;
  for (const id of winnerIds) scores[id] = 1;
  const result = {
    kind: "guessCharacter",
    winnerIds,
    scores,
    summary: { reason: reason || "completed" },
  };
  const publicState = {
    ...(game.publicState || {}),
    engine: "guessCharacter",
    phase: "game_over",
    currentPlayerId: null,
    question: null,
    answerOptions: null,
    result,
  };
  transaction.update(gameRef, {
    status: "COMPLETED",
    currentPhase: "game_over",
    publicState,
    result,
    endedAt: now,
    deadlineAt: null,
    stateVersion: bumpVersion(game),
    updatedAt: FieldValue.serverTimestamp(),
  });
  transaction.set(historyRef(db, gameId), {
    gameId,
    type: "guessCharacter",
    groupId: game.groupId || null,
    participants: players,
    result,
    endedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  });
  return { completed: true, result };
}

function phaseDeadline(game, now, seconds) {
  const global = globalDeadline(game, now);
  const phase = deadlineAt(now, seconds);
  return phase < global ? phase : global;
}

function initialize({ transaction, gameRef, FieldValue, game, playerIds, now }) {
  if (game.publicState && game.publicState.engine === "guessCharacter") return;
  if (!Array.isArray(playerIds) || playerIds.length !== 2) {
    throw new Error("Guess Character requires exactly two players.");
  }
  const players = {};
  for (const id of playerIds) players[id] = { selected: false };
  transaction.set(secretRef(gameRef), {
    selections: {},
    selectionPlayerIds: playerIds,
  });
  transaction.update(gameRef, {
    publicState: {
      engine: "guessCharacter",
      phase: "selection",
      players,
      currentPlayerId: null,
      question: null,
      answerOptions: null,
      lastAction: null,
      result: null,
    },
    currentPhase: "selection",
    deadlineAt: phaseDeadline(game, now, configOf(game).selectionSeconds),
    stateVersion: bumpVersion(game),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

function applyAction(ctx) {
  const {
    transaction, gameRef, FieldValue, game, uid, action, now, HttpsError,
    secretSnap, db, gameId,
  } = ctx;
  rejectStale(action.payload, game, HttpsError);
  const state = game.publicState;
  if (!state || state.engine !== "guessCharacter") {
    throw new HttpsError("failed-precondition", "Guess Character is not initialized.");
  }
  if (isExpired(game.deadlineAt, now)) {
    throw new HttpsError("failed-precondition", "This game phase has expired.");
  }
  const players = Object.keys(state.players || {});
  if (!players.includes(uid)) throw new HttpsError("permission-denied", "Not a player.");
  const secret = secretSnap && secretSnap.exists ? secretSnap.data() : {};
  const selections = { ...(secret.selections || {}) };
  const cfg = configOf(game);

  if (state.phase === "selection") {
    if (action.actionType !== "select") {
      throw new HttpsError("failed-precondition", "Choose a character first.");
    }
    if (selections[uid]) throw new HttpsError("already-exists", "Character already selected.");
    const characterId = action.payload && (action.payload.characterId || action.payload.value);
    const character = typeof characterId === "string" ? catalog.characterById(characterId) : null;
    if (!character) throw new HttpsError("invalid-argument", "Select a valid Character ID.");
    if (Object.values(selections).includes(character.id)) {
      throw new HttpsError("invalid-argument", "Each secret character must be different.");
    }
    selections[uid] = character.id;
    transaction.set(secretRef(gameRef), { ...secret, selections });
    transaction.set(privateRef(gameRef, uid), {
      selectedCharacterId: character.id,
      opponentOnly: true,
      updatedAt: FieldValue.serverTimestamp(),
    });
    const selected = { ...(state.players || {}) };
    selected[uid] = { selected: true };
    const ready = players.every((id) => selections[id]);
    const next = {
      ...state,
      players: selected,
      phase: ready ? "ask" : "selection",
      currentPlayerId: ready ? players[0] : null,
      question: null,
      answerOptions: null,
    };
    transaction.update(gameRef, {
      publicState: next,
      currentPhase: next.phase,
      deadlineAt: phaseDeadline(game, now, ready ? cfg.timerSeconds : cfg.selectionSeconds),
      stateVersion: bumpVersion(game),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { completed: false, result: null };
  }

  if (state.phase === "ask") {
    if (state.currentPlayerId !== uid) {
      throw new HttpsError("failed-precondition", "It is not your turn.");
    }
    if (action.actionType !== "ask" && action.actionType !== "guess") {
      throw new HttpsError("invalid-argument", "Ask a question or make a guess.");
    }
    const opponent = players.find((id) => id !== uid);
    if (action.actionType === "guess") {
      const guessId = action.payload && (action.payload.characterId || action.payload.value);
      if (typeof guessId !== "string" || !catalog.characterById(guessId)) {
        throw new HttpsError("invalid-argument", "Guess a valid Character ID.");
      }
      if (guessId === selections[opponent]) return endGame(transaction, { ...ctx }, [uid], "correct_guess");
      const next = { ...state, currentPlayerId: opponent, lastAction: { type: "wrong_guess", playerId: uid } };
      transaction.update(gameRef, {
        publicState: next,
        deadlineAt: phaseDeadline(game, now, cfg.timerSeconds),
        stateVersion: bumpVersion(game),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { completed: false, result: null };
    }
    const question = action.payload && action.payload.question;
    if (typeof question !== "string" || !question.trim()) {
      throw new HttpsError("invalid-argument", "A question is required.");
    }
    const next = {
      ...state,
      phase: "answer",
      question: question.trim().slice(0, 300),
      answerOptions: ["yes", "no"],
      answeringPlayerId: opponent,
    };
    transaction.update(gameRef, {
      publicState: next,
      currentPhase: "answer",
      deadlineAt: phaseDeadline(game, now, cfg.timerSeconds),
      stateVersion: bumpVersion(game),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { completed: false, result: null };
  }

  if (state.phase === "answer") {
    if (state.answeringPlayerId !== uid || action.actionType !== "answer") {
      throw new HttpsError("failed-precondition", "Only the other player may answer yes or no.");
    }
    const answer = action.payload && (action.payload.answer || action.payload.value);
    if (answer !== "yes" && answer !== "no") {
      throw new HttpsError("invalid-argument", "Answer must be exactly yes or no.");
    }
    const next = {
      ...state,
      phase: "ask",
      currentPlayerId: uid,
      question: null,
      answerOptions: null,
      answeringPlayerId: null,
      lastAction: { type: "answer", answer },
    };
    transaction.update(gameRef, {
      publicState: next,
      currentPhase: "ask",
      deadlineAt: phaseDeadline(game, now, cfg.timerSeconds),
      stateVersion: bumpVersion(game),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { completed: false, result: null };
  }
  throw new HttpsError("failed-precondition", "This phase is not accepting actions.");
}

function onTimeout(ctx) {
  const { game, now, transaction, HttpsError } = ctx;
  const state = game.publicState || {};
  const players = Object.keys(state.players || {});
  if (state.phase === "selection") {
    const secret = ctx.secretSnap && ctx.secretSnap.exists ? ctx.secretSnap.data() : {};
    const selected = Object.keys(secret.selections || {});
    const forfeiter = players.find((id) => !selected.includes(id));
    if (forfeiter) {
      const winnerIds = selected.length === 1
        ? players.filter((id) => id !== forfeiter)
        : [];
      return endGame(transaction, ctx, winnerIds, "selection_timeout");
    }
  }
  if (globalDeadline(game, now).getTime() <= now.getTime()) {
    return endGame(transaction, ctx, [], "global_timeout");
  }
  if (state.phase === "ask" || state.phase === "answer") {
    const loser = state.phase === "answer" ? state.currentPlayerId : state.currentPlayerId;
    const next = { ...state, phase: "ask", currentPlayerId: players.find((id) => id !== loser), question: null, answerOptions: null, answeringPlayerId: null, lastAction: { type: "timeout", playerId: loser } };
    transaction.update(ctx.gameRef, {
      publicState: next,
      currentPhase: "ask",
      deadlineAt: phaseDeadline(game, now, 30),
      stateVersion: bumpVersion(game),
      updatedAt: ctx.FieldValue.serverTimestamp(),
    });
  }
  return { completed: false, result: null };
}

module.exports = { initialize, applyAction, onTimeout };