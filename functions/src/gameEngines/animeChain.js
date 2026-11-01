"use strict";

const {
  CHAIN_RULE_TEXT,
} = require("../animeCatalogDomain");
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
  snapshot,
} = require("./helpers");

const CHAIN_RULE = CHAIN_RULE_TEXT;

function configOf(game) {
  const configuration = game.configuration || {};
  return {
    timerSeconds: clampInt(configuration.timerSeconds, 25, 12, 60),
    maxChain: clampInt(configuration.roundCount, 8, 2, 16),
  };
}

function playersOf(state) {
  return Array.isArray(state.playerOrder)
    ? state.playerOrder
    : Object.keys(state.scores || {});
}

function opponentOf(state, playerId) {
  return playersOf(state).find((id) => id !== playerId) || null;
}

function complete(transaction, {
  db, gameRef, FieldValue, game, gameId, scores, now, reason, winnerIds,
}) {
  const outcome = winnerIds
    ? { winnerIds, draw: false }
    : winnersFromScores(scores);
  const chain = (game.publicState && game.publicState.chain) || [];
  const result = {
    kind: "animeChain",
    winnerIds: outcome.winnerIds,
    scores,
    summary: {
      draw: outcome.draw,
      chainLength: chain.length,
      reason: reason || "completed",
      rule: CHAIN_RULE,
    },
  };
  transaction.update(gameRef, {
    status: "COMPLETED",
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

function initialize(ctx) {
  const { transaction, gameRef, FieldValue, game, playerIds, random, now } = ctx;
  // The domain admits only two players for Anime Chain. Keep this guard in the
  // engine too, so a malformed server-side start can never become a 3+ player match.
  if (!Array.isArray(playerIds) || playerIds.length !== 2) {
    throw new Error("Anime Chain requires exactly two players.");
  }
  if (game.publicState && game.publicState.engine === "animeChain") return;
  // The pool is resolved from the canonical repository before the transaction
  // opens, so a real popularity-ranked title is always chosen. The offline
  // snapshot is the degraded-mode fallback only.
  const pool = Array.isArray(ctx.animePool) && ctx.animePool.length > 1
    ? ctx.animePool
    : snapshot.ANIME;
  const seed = pickOne(pool, random);
  const cfg = configOf(game);
  const publicState = {
    engine: "animeChain",
    phase: "turn",
    rule: CHAIN_RULE,
    chain: [{ animeId: seed.id, title: seed.title }],
    currentPlayerId: playerIds[0],
    turnIndex: 0,
    playerOrder: [...playerIds],
    scores: emptyScores(playerIds),
    lastMove: null,
    failedTurns: [],
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
  return order[(index + 1) % order.length];
}

function failedTurn(transaction, ctx, reason) {
  const { game, gameRef, FieldValue, db, gameId, now, uid } = ctx;
  const state = game.publicState || {};
  const scores = { ...(state.scores || {}) };
  const winnerId = opponentOf(state, uid);
  const failedTurns = [...(state.failedTurns || []), { playerId: uid, reason }];
  game.publicState = { ...state, failedTurns };
  return complete(transaction, {
    db, gameRef, FieldValue, game, gameId, scores, now,
    reason,
    winnerIds: winnerId ? [winnerId] : [],
  });
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
    return failedTurn(transaction, { ...ctx, db, gameId }, "invalid_action");
  }
  // Both titles are resolved by the domain against real catalog data before
  // the transaction opens; the engine only evaluates the chain rule.
  const match = ctx.resolvedAnime;
  const previous = ctx.resolvedPreviousAnime;
  if (!match) {
    return failedTurn(transaction, { ...ctx, db, gameId }, "invalid_anime");
  }
  const chain = state.chain || [];
  if (chain.some((item) => item.animeId === match.id)) {
    return failedTurn(transaction, { ...ctx, db, gameId }, "duplicate_anime");
  }
  const last = chain[chain.length - 1];
  if (!last || !previous || !ctx.chainValid) {
    return failedTurn(transaction, { ...ctx, db, gameId }, "broken_chain");
  }
  if (last.animeId !== previous.id) {
    // The chain advanced while this submission was being validated. The move is
    // not wrong, it is stale, so it must not cost the player the turn.
    throw new HttpsError("aborted", "This game state is stale. Refresh and try again.");
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
  const { game, now } = ctx;
  const state = game.publicState || {};
  if (state.phase !== "turn") return { completed: false, result: null };
  return failedTurn(ctx.transaction, { ...ctx, uid: state.currentPlayerId, now }, "timeout");
}

module.exports = { initialize, applyAction, onTimeout, CHAIN_RULE };