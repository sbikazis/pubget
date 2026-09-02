"use strict";

const catalog = require("../gameCatalog");
const {
  clampInt,
  isExpired,
  deadlineAt,
  pickOne,
  emptyScores,
  winnersFromScores,
  rejectStale,
  bumpVersion,
  historyRef,
} = require("./helpers");

const CHAIN_RULE =
  "Next title must share at least one character or the same studio, " +
  "and must not already appear in the chain.";

function configOf(game) {
  const configuration = game.configuration || {};
  return {
    timerSeconds: clampInt(configuration.timerSeconds, 25, 12, 60),
    maxChain: clampInt(configuration.roundCount, 8, 5, 16),
  };
}

function complete(transaction, {
  db, gameRef, FieldValue, game, gameId, scores, now, reason,
}) {
  const outcome = winnersFromScores(scores);
  const result = {
    kind: "animeChain",
    winnerIds: outcome.winnerIds,
    scores,
    summary: {
      draw: outcome.draw,
      chainLength: ((game.publicState && game.publicState.chain) || []).length,
      reason: reason || "completed",
      rule: CHAIN_RULE,
    },
  };
  transaction.update(gameRef, {
    status: "completed",
    result,
    endedAt: now,
    publicState: {
      ...(game.publicState || {}),
      engine: "animeChain",
      phase: "game_over",
      scores,
      currentPlayerId: null,
    },
    currentPhase: "game_over",
    deadlineAt: null,
    stateVersion: bumpVersion(game),
    updatedAt: FieldValue.serverTimestamp(),
  });
  transaction.set(historyRef(db, gameId), {
    gameId,
    type: "animeChain",
    groupId: game.groupId || null,
    participants: Object.keys(scores),
    result,
    endedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  });
  return { completed: true, result };
}

function initialize({
  transaction, gameRef, FieldValue, game, playerIds, random, now,
}) {
  if (game.publicState && game.publicState.engine === "animeChain") return;
  const seed = pickOne(catalog.ANIME, random);
  const cfg = configOf(game);
  const publicState = {
    engine: "animeChain",
    phase: "turn",
    rule: CHAIN_RULE,
    chain: [{ animeId: seed.id, title: seed.title }],
    currentPlayerId: playerIds[0],
    turnIndex: 0,
    playerOrder: playerIds,
    scores: emptyScores(playerIds),
    lastMove: null,
  };
  transaction.update(gameRef, {
    publicState,
    currentPhase: "turn",
    stateVersion: bumpVersion(game),
    deadlineAt: deadlineAt(now, cfg.timerSeconds),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

function nextPlayer(order, currentId) {
  const index = order.indexOf(currentId);
  if (index < 0) return order[0];
  return order[(index + 1) % order.length];
}

function applyAction(ctx) {
  const {
    transaction, gameRef, FieldValue, game, uid, action, now, HttpsError,
    db, gameId,
  } = ctx;
  rejectStale(action.payload, game, HttpsError);
  const state = game.publicState || {};
  if (state.phase !== "turn") {
    throw new HttpsError("failed-precondition", "This chain is not accepting titles.");
  }
  if (state.currentPlayerId !== uid) {
    throw new HttpsError("failed-precondition", "It is not your turn.");
  }
  if (isExpired(game.deadlineAt, now)) {
    throw new HttpsError("failed-precondition", "This turn has already ended.");
  }
  if (action.actionType !== "submit" && action.actionType !== "guess") {
    throw new HttpsError("invalid-argument", "Anime Chain expects a title.");
  }
  const raw = action.payload && (action.payload.animeId || action.payload.title || action.payload.value);
  const match = typeof raw === "string" && raw.startsWith && catalog.byAnimeId(raw)
    ? catalog.byAnimeId(raw)
    : catalog.animeByTitle(raw);
  if (!match) {
    throw new HttpsError("invalid-argument", "That title is not in the Anime Chain catalog.");
  }
  const chain = state.chain || [];
  if (chain.some((item) => item.animeId === match.id)) {
    throw new HttpsError("failed-precondition", "That title is already in the chain.");
  }
  const last = chain[chain.length - 1];
  if (!catalog.sharesRelation(last.animeId, match.id)) {
    throw new HttpsError(
      "failed-precondition",
      "That title does not share a character or studio with the last link.",
    );
  }
  const scores = { ...(state.scores || {}) };
  scores[uid] = (scores[uid] || 0) + 1;
  const nextChain = [...chain, { animeId: match.id, title: match.title }];
  const cfg = configOf(game);
  if (nextChain.length >= cfg.maxChain) {
    game.publicState = { ...state, chain: nextChain, scores };
    return complete(transaction, {
      db, gameRef, FieldValue, game, gameId, scores, now, reason: "chain_complete",
    });
  }
  const currentPlayerId = nextPlayer(state.playerOrder || Object.keys(scores), uid);
  const publicState = {
    ...state,
    chain: nextChain,
    scores,
    currentPlayerId,
    turnIndex: (state.turnIndex || 0) + 1,
    lastMove: { playerId: uid, animeId: match.id, title: match.title },
  };
  transaction.update(gameRef, {
    publicState,
    currentPhase: "turn",
    stateVersion: bumpVersion(game),
    deadlineAt: deadlineAt(now, cfg.timerSeconds),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { completed: false, result: null };
}

function onTimeout(ctx) {
  const {
    transaction, gameRef, FieldValue, game, now, db, gameId,
  } = ctx;
  const state = game.publicState || {};
  if (state.phase !== "turn") return { completed: false, result: null };
  const order = state.playerOrder || Object.keys(state.scores || {});
  const skipped = state.currentPlayerId;
  const skips = { ...(state.skips || {}) };
  skips[skipped] = (skips[skipped] || 0) + 1;
  const currentPlayerId = nextPlayer(order, skipped);
  const consecutiveSkips = (state.consecutiveSkips || 0) + 1;
  if (consecutiveSkips >= order.length) {
    game.publicState = { ...state, skips };
    return complete(transaction, {
      db, gameRef, FieldValue, game, gameId,
      scores: state.scores || {},
      now,
      reason: "timeout",
    });
  }
  const cfg = configOf(game);
  transaction.update(gameRef, {
    publicState: {
      ...state,
      currentPlayerId,
      skips,
      consecutiveSkips,
      lastMove: { type: "timeout", playerId: skipped },
    },
    stateVersion: bumpVersion(game),
    deadlineAt: deadlineAt(now, cfg.timerSeconds),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { completed: false, result: null };
}

module.exports = {
  initialize,
  applyAction,
  onTimeout,
  CHAIN_RULE,
};
