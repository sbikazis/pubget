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

// The catalog is authoritative. These aliases cover the common search names
// used by anime databases while still resolving to a canonical catalog item.
const ALIASES = Object.freeze({
  haikyuu: "haikyuu",
  "haikyuu!!": "haikyuu",
  "the melancholy of haruhi suzumiya": null,
  "frieren beyond journey's end": "frieren",
  "frieren beyond journeys end": "frieren",
});

function resolveAnime(value) {
  if (value && typeof value === "object") {
    return resolveAnime(value.animeId || value.id || value.title || value.value);
  }
  if (typeof value !== "string" || !value.trim()) return null;
  const byId = catalog.byAnimeId(value.trim());
  if (byId) return byId;
  const normalized = catalog.normalizeTitle(value);
  const aliasId = ALIASES[normalized];
  if (aliasId) return catalog.byAnimeId(aliasId);
  return catalog.animeByTitle(value);
}

function pickTarget(usedIds, random) {
  const used = usedIds || [];
  const pool = catalog.ANIME.filter((item) => !used.includes(item.id));
  return pickOne(pool.length ? pool : catalog.ANIME, random);
}

function publicEmojis(target) {
  return (Array.isArray(target && target.emojiClues) ? target.emojiClues : [])
    .map((item) => String(item))
    .filter(Boolean)
    .slice(0, 4);
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
    status: "COMPLETED",
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
  return order[(index < 0 ? 0 : index + 1) % order.length];
}

function advanceTurn(transaction, ctx, { lastReveal, scores, usedIds }) {
  const { gameRef, FieldValue, game, now, random, db, gameId } = ctx;
  const state = game.publicState || {};
  const order = state.playerOrder || Object.keys(scores);
  const nextIndex = (state.turnIndex || 0) + 1;
  const totalTurns = state.totalTurns || order.length;
  game.publicState = { ...state, lastReveal, scores };
  if (nextIndex >= totalTurns) {
    return complete(transaction, {
      db, gameRef, FieldValue, game, gameId, scores, now, lastReveal,
    });
  }
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
    playerOrder: [...playerIds],
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
    throw new HttpsError("failed-precondition", "This round has already ended.");
  }
  // The turn owner supplies the clue; every other player may guess.
  if (uid === state.currentPlayerId) {
    throw new HttpsError("failed-precondition", "The turn owner cannot guess.");
  }
  if ((state.answeredPlayerIds || []).includes(uid)) {
    throw new HttpsError("already-exists", "You already guessed this round.");
  }
  if (action.actionType !== "guess" && action.actionType !== "submit") {
    throw new HttpsError("invalid-argument", "Submit an anime selection.");
  }
  const payload = action.payload || {};
  const submitted = payload.animeId || payload.selection || payload.title ||
    payload.value;
  const match = resolveAnime(submitted);
  if (!match) {
    throw new HttpsError("invalid-argument", "Select an anime from the catalog.");
  }
  const secret = secretSnap && secretSnap.exists ? secretSnap.data() : null;
  if (!secret) {
    throw new HttpsError("failed-precondition", "This round is still being prepared.");
  }
  const answered = [...(state.answeredPlayerIds || []), uid];
  const scores = { ...(state.scores || {}) };
  const correct = match.id === secret.targetAnimeId;
  if (correct) scores[uid] = (scores[uid] || 0) + 1;
  const lastReveal = {
    title: secret.title,
    animeId: secret.targetAnimeId,
    winnerId: correct ? uid : null,
    guessedTitle: match.title,
    correct,
  };
  // A correct answer closes immediately. A round with no correct answer
  // closes once every eligible guesser has answered.
  const guessers = (state.playerOrder || Object.keys(scores))
    .filter((id) => id !== state.currentPlayerId);
  if (correct || answered.length >= guessers.length) {
    return advanceTurn(transaction, ctx, {
      lastReveal, scores, usedIds: secret.usedAnimeIds || [],
    });
  }
  game.publicState = { ...state, scores, answeredPlayerIds: answered };
  transaction.update(ctx.gameRef, {
    publicState: game.publicState,
    stateVersion: bumpVersion(game),
    updatedAt: ctx.FieldValue.serverTimestamp(),
  });
  return { completed: false, result: null };
}

function onTimeout(ctx) {
  const { game, secretSnap } = ctx;
  const state = game.publicState || {};
  if (state.phase !== "guess") return { completed: false, result: null };
  const secret = secretSnap && secretSnap.exists ? secretSnap.data() : null;
  return advanceTurn(ctx.transaction, ctx, {
    lastReveal: {
      title: (secret && secret.title) || "",
      animeId: (secret && secret.targetAnimeId) || "",
      winnerId: null,
      correct: false,
      reason: "timeout",
    },
    scores: state.scores || {},
    usedIds: (secret && secret.usedAnimeIds) || [],
  });
}

module.exports = { initialize, applyAction, onTimeout };