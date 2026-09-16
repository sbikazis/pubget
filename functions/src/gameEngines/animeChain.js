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
  "Each title must share a character or studio with the immediately previous canonical title.";

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

function initialize({ transaction, gameRef, FieldValue, game, playerIds, random, now }) {
  // The domain admits only two players for Anime Chain. Keep this guard in the
  // engine too, so a malformed server-side start can never become a 3+ player match.
  if (!Array.isArray(playerIds) || playerIds.length !== 2) {
    throw new Error("Anime Chain requires exactly two players.");
  }
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

function canonicalAnime(payload) {
  if (!payload || typeof payload !== "object") return null;
  // IDs are authoritative. Title lookup is retained only as a catalog adapter
  // convenience; an arbitrary title can never enter game state.
  if (typeof payload.animeId === "string") return catalog.byAnimeId(payload.animeId);
  if (typeof payload.title === "string") return catalog.animeByTitle(payload.title);
  if (typeof payload.value === "string") return catalog.animeByTitle(payload.value);
  return null;
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
  const match = canonicalAnime(action.payload);
  if (!match) {
    return failedTurn(transaction, { ...ctx, db, gameId }, "invalid_anime");
  }
  const chain = state.chain || [];
  if (chain.some((item) => item.animeId === match.id)) {
    return failedTurn(transaction, { ...ctx, db, gameId }, "duplicate_anime");
  }
  const last = chain[chain.length - 1];
  if (!last || !catalog.byAnimeId(last.animeId) ||
      !catalog.sharesRelation(last.animeId, match.id)) {
    return failedTurn(transaction, { ...ctx, db, gameId }, "broken_chain");
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