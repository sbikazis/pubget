"use strict";

const catalog = require("../gameCatalog");
const {
  clampInt,
  isExpired,
  deadlineAt,
  pickOne,
  secretRef,
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

function pickTarget(usedIds, random) {
  const used = usedIds || [];
  const pool = catalog.ANIME.filter((item) => !used.includes(item.id));
  const source = pool.length ? pool : catalog.ANIME;
  return pickOne(source, random);
}

function publicEmojis(target) {
  const clues = Array.isArray(target.emojiClues) ? target.emojiClues : [];
  return clues.map((item) => String(item)).filter(Boolean).slice(0, 4);
}

function writeTurn(transaction, {
  gameRef, FieldValue, game, now, random, scores, playerOrder,
  currentPlayerId, turnIndex, totalTurns, lastReveal, usedIds,
}) {
  const target = pickTarget(usedIds, random);
  const emojis = publicEmojis(target);
  const nextUsed = (usedIds || []).includes(target.id)
    ? usedIds
    : [...(usedIds || []), target.id];
  const publicState = {
    engine: "emojiAnimeGuess",
    phase: "guess",
    emojis,
    currentPlayerId,
    playerOrder,
    scores,
    turnIndex,
    totalTurns,
    lastReveal: lastReveal || null,
    answeredPlayerIds: [],
  };
  transaction.set(secretRef(gameRef), {
    targetAnimeId: target.id,
    title: target.title,
    turnIndex,
    usedAnimeIds: nextUsed,
  });
  transaction.update(gameRef, {
    publicState,
    currentPhase: "guess",
    currentRoundNumber: turnIndex + 1,
    stateVersion: bumpVersion(game),
    deadlineAt: deadlineAt(now, configOf(game).timerSeconds),
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
      currentPlayerId: null,
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

function nextPlayer(order, currentId) {
  const index = order.indexOf(currentId);
  if (index < 0) return order[0];
  return order[(index + 1) % order.length];
}

function advanceTurn(transaction, ctx, { lastReveal, scores, usedIds }) {
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
  writeTurn(transaction, {
    gameRef, FieldValue, game, now, random, scores,
    playerOrder: order,
    currentPlayerId: nextPlayer(order, state.currentPlayerId),
    turnIndex: nextIndex,
    totalTurns,
    lastReveal,
    usedIds,
  });
  return { completed: false, result: null };
}

function initialize({
  transaction, gameRef, FieldValue, game, playerIds, random, now,
}) {
  if (game.publicState && game.publicState.engine === "emojiAnimeGuess") return;
  const cfg = configOf(game);
  const totalTurns = playerIds.length * cfg.roundsPerPlayer;
  writeTurn(transaction, {
    gameRef, FieldValue, game, now, random,
    scores: emptyScores(playerIds),
    playerOrder: playerIds,
    currentPlayerId: playerIds[0],
    turnIndex: 0,
    totalTurns,
    lastReveal: null,
    usedIds: [],
  });
}

function applyAction(ctx) {
  const {
    transaction, game, uid, action, now, HttpsError, secretSnap,
  } = ctx;
  rejectStale(action.payload, game, HttpsError);
  const state = game.publicState || {};
  if (state.phase !== "guess") {
    throw new HttpsError("failed-precondition", "Guesses are not being accepted.");
  }
  if (isExpired(game.deadlineAt, now)) {
    throw new HttpsError("failed-precondition", "This turn has already ended.");
  }
  if (uid !== state.currentPlayerId) {
    throw new HttpsError("failed-precondition", "It is not your turn.");
  }
  if ((state.answeredPlayerIds || []).includes(uid)) {
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
  const secret = secretSnap && secretSnap.exists ? secretSnap.data() : null;
  if (!secret) {
    throw new HttpsError("failed-precondition", "This turn is still being prepared.");
  }
  const correct = catalog.normalizeTitle(title) === catalog.normalizeTitle(secret.title);
  const scores = { ...(state.scores || {}) };
  if (correct) {
    scores[uid] = (scores[uid] || 0) + 1;
  }
  const lastReveal = {
    title: secret.title,
    animeId: secret.targetAnimeId,
    winnerId: correct ? uid : null,
    guessedTitle: match ? match.title : title,
    correct,
  };
  return advanceTurn(transaction, ctx, {
    lastReveal,
    scores,
    usedIds: secret.usedAnimeIds || [],
  });
}

function onTimeout(ctx) {
  const { game, secretSnap } = ctx;
  const state = game.publicState || {};
  if (state.phase !== "guess") {
    return { completed: false, result: null };
  }
  const secret = secretSnap && secretSnap.exists ? secretSnap.data() : null;
  const lastReveal = {
    title: (secret && secret.title) || "",
    animeId: (secret && secret.targetAnimeId) || "",
    winnerId: null,
    correct: false,
    reason: "timeout",
  };
  return advanceTurn(ctx.transaction, ctx, {
    lastReveal,
    scores: state.scores || {},
    usedIds: (secret && secret.usedAnimeIds) || [],
  });
}

module.exports = {
  initialize,
  applyAction,
  onTimeout,
};
