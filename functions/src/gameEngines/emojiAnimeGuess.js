"use strict";

const catalog = require("../gameCatalog");
const {
  clampInt,
  isExpired,
  deadlineAt,
  pickOne,
  secretRef,
  privateRef,
  emptyScores,
  winnersFromScores,
  rejectStale,
  bumpVersion,
  historyRef,
} = require("./helpers");

function configOf(game) {
  const configuration = game.configuration || {};
  return {
    timerSeconds: clampInt(configuration.timerSeconds, 25, 12, 45),
    roundsPerPlayer: clampInt(configuration.roundCount, 1, 1, 3),
  };
}

function assignTarget(transaction, {
  gameRef, FieldValue, game, clueGiverId, random, now, scores, turnIndex, totalTurns, lastReveal, playerOrder,
}) {
  const target = pickOne(catalog.ANIME, random);
  const cfg = configOf(game);
  const publicState = {
    engine: "emojiAnimeGuess",
    phase: "clue",
    clueGiverId,
    emojis: null,
    guessedPlayerIds: [],
    guesses: {},
    scores,
    turnIndex,
    totalTurns,
    playerOrder: playerOrder || (game.publicState && game.publicState.playerOrder) || Object.keys(scores),
    lastReveal: lastReveal || null,
  };
  transaction.set(secretRef(gameRef), {
    targetAnimeId: target.id,
    title: target.title,
    turnIndex,
  });
  transaction.set(privateRef(gameRef, clueGiverId), {
    targetAnimeId: target.id,
    title: target.title,
    turnIndex,
  });
  transaction.update(gameRef, {
    publicState,
    currentPhase: "clue",
    currentRoundNumber: turnIndex + 1,
    stateVersion: bumpVersion(game),
    deadlineAt: deadlineAt(now, cfg.timerSeconds),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

function complete(transaction, {
  db, gameRef, FieldValue, game, gameId, scores, now, lastReveal,
}) {
  const outcome = winnersFromScores(scores);
  const result = {
    kind: "emojiAnimeGuess",
    winnerIds: outcome.winnerIds,
    scores,
    summary: { draw: outcome.draw },
  };
  transaction.update(gameRef, {
    status: "completed",
    result,
    endedAt: now,
    publicState: {
      ...(game.publicState || {}),
      engine: "emojiAnimeGuess",
      phase: "game_over",
      scores,
      clueGiverId: null,
      emojis: (game.publicState && game.publicState.emojis) || null,
      lastReveal,
    },
    currentPhase: "game_over",
    deadlineAt: null,
    stateVersion: bumpVersion(game),
    updatedAt: FieldValue.serverTimestamp(),
  });
  transaction.set(historyRef(db, gameId), {
    gameId,
    type: "emojiAnimeGuess",
    groupId: game.groupId || null,
    participants: Object.keys(scores),
    result,
    endedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  });
  return { completed: true, result };
}

function advanceTurn(transaction, ctx, lastReveal, scores) {
  const { gameRef, FieldValue, game, now, random, db, gameId } = ctx;
  const state = game.publicState || {};
  const order = state.playerOrder || Object.keys(scores);
  const nextIndex = (state.turnIndex || 0) + 1;
  const totalTurns = state.totalTurns || order.length;
  if (nextIndex >= totalTurns) {
    game.publicState = { ...state, scores };
    return complete(transaction, {
      db, gameRef, FieldValue, game, gameId, scores, now, lastReveal,
    });
  }
  game.publicState = { ...state, lastReveal, scores };
  assignTarget(transaction, {
    gameRef, FieldValue, game,
    clueGiverId: order[nextIndex % order.length],
    random, now, scores,
    turnIndex: nextIndex,
    totalTurns,
    lastReveal,
    playerOrder: order,
  });
  return { completed: false, result: null };
}

function scoreTurn(state, secret) {
  const scores = { ...(state.scores || {}) };
  const guesses = state.guesses || {};
  let winnerId = null;
  for (const [uid, title] of Object.entries(guesses)) {
    if (catalog.normalizeTitle(title) === catalog.normalizeTitle(secret.title)) {
      winnerId = uid;
      scores[uid] = (scores[uid] || 0) + 2;
      if (state.clueGiverId) {
        scores[state.clueGiverId] = (scores[state.clueGiverId] || 0) + 1;
      }
      break;
    }
  }
  return {
    scores,
    lastReveal: {
      title: secret.title,
      animeId: secret.targetAnimeId,
      winnerId,
    },
  };
}

function initialize({
  transaction, gameRef, FieldValue, game, playerIds, random, now,
}) {
  if (game.publicState && game.publicState.engine === "emojiAnimeGuess") return;
  const cfg = configOf(game);
  const totalTurns = playerIds.length * cfg.roundsPerPlayer;
  assignTarget(transaction, {
    gameRef, FieldValue, game,
    clueGiverId: playerIds[0],
    random, now,
    scores: emptyScores(playerIds),
    turnIndex: 0,
    totalTurns,
    lastReveal: null,
    playerOrder: playerIds,
  });
}

function applyAction(ctx) {
  const {
    transaction, gameRef, FieldValue, game, uid, action, now, HttpsError,
    secretSnap,
  } = ctx;
  rejectStale(action.payload, game, HttpsError);
  const state = game.publicState || {};
  if (isExpired(game.deadlineAt, now)) {
    throw new HttpsError("failed-precondition", "This turn has already ended.");
  }
  const secret = secretSnap && secretSnap.exists ? secretSnap.data() : null;
  if (state.phase === "clue") {
    if (uid !== state.clueGiverId) {
      throw new HttpsError("failed-precondition", "Only the clue-giver can submit emojis.");
    }
    if (action.actionType !== "submit" && action.actionType !== "choose") {
      throw new HttpsError("invalid-argument", "Submit 3 or 4 emoji clues.");
    }
    const emojis = action.payload && action.payload.emojis;
    if (!Array.isArray(emojis) || emojis.length < 3 || emojis.length > 4) {
      throw new HttpsError("invalid-argument", "Provide 3 or 4 emoji clues.");
    }
    const cleaned = emojis.map((item) => String(item).trim()).filter(Boolean);
    if (cleaned.length < 3 || cleaned.length > 4) {
      throw new HttpsError("invalid-argument", "Provide 3 or 4 emoji clues.");
    }
    const cfg = configOf(game);
    transaction.update(gameRef, {
      publicState: {
        ...state,
        phase: "guess",
        emojis: cleaned,
        guessedPlayerIds: [],
        guesses: {},
      },
      currentPhase: "guess",
      stateVersion: bumpVersion(game),
      deadlineAt: deadlineAt(now, cfg.timerSeconds),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { completed: false, result: null };
  }
  if (state.phase !== "guess") {
    throw new HttpsError("failed-precondition", "Guesses are not being accepted.");
  }
  if (uid === state.clueGiverId) {
    throw new HttpsError("failed-precondition", "The clue-giver cannot guess this turn.");
  }
  if ((state.guessedPlayerIds || []).includes(uid)) {
    throw new HttpsError("already-exists", "You already guessed this turn.");
  }
  if (action.actionType !== "guess" && action.actionType !== "submit") {
    throw new HttpsError("invalid-argument", "Submit an anime title.");
  }
  const raw = action.payload && (action.payload.title || action.payload.value || action.payload.animeId);
  const match = catalog.byAnimeId(raw) || catalog.animeByTitle(raw);
  const title = match ? match.title : (typeof raw === "string" ? raw.trim() : "");
  if (!title) {
    throw new HttpsError("invalid-argument", "A title is required.");
  }
  const guessedPlayerIds = [...(state.guessedPlayerIds || []), uid];
  const guesses = { ...(state.guesses || {}), [uid]: title };
  const guessers = (state.playerOrder || Object.keys(state.scores || {}))
    .filter((id) => id !== state.clueGiverId);
  const publicState = {
    ...state,
    guessedPlayerIds,
    guesses,
  };
  transaction.update(gameRef, {
    publicState,
    stateVersion: bumpVersion(game),
    updatedAt: FieldValue.serverTimestamp(),
  });
  game.publicState = publicState;
  game.stateVersion = bumpVersion(game);
  if (secret && catalog.normalizeTitle(title) === catalog.normalizeTitle(secret.title)) {
    const scored = scoreTurn(publicState, secret);
    return advanceTurn(transaction, ctx, scored.lastReveal, scored.scores);
  }
  if (guessedPlayerIds.length >= guessers.length) {
    const scored = scoreTurn(publicState, secret || { title: "", targetAnimeId: "" });
    return advanceTurn(transaction, ctx, scored.lastReveal, scored.scores);
  }
  return { completed: false, result: null };
}

function onTimeout(ctx) {
  const { game, secretSnap, transaction } = ctx;
  const state = game.publicState || {};
  if (state.phase !== "clue" && state.phase !== "guess") {
    return { completed: false, result: null };
  }
  const secret = secretSnap && secretSnap.exists ? secretSnap.data() : null;
  const scored = scoreTurn(state, secret || { title: "", targetAnimeId: "" });
  return advanceTurn(transaction, ctx, scored.lastReveal, scored.scores);
}

module.exports = {
  initialize,
  applyAction,
  onTimeout,
};
