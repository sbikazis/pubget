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
  "Next title must share a character or studio with the previous title.";

function configOf(game) {
  const configuration = game.configuration || {};
  return {
    timerSeconds: clampInt(configuration.timerSeconds, 25, 12, 60),
    maxChain: clampInt(configuration.roundCount, 8, 5, 16),
  };
}

function nextActivePlayer(state, currentId) {
  const active = state.activePlayerIds || state.playerOrder || [];
  if (active.length === 0) return null;
  const index = active.indexOf(currentId);
  return active[(index + 1) % active.length];
}

function complete(transaction, {
  db,
  gameRef,
  FieldValue,
  game,
  gameId,
  scores,
  playerIds,
  now,
  reason,
  winnerIds,
}) {
  const outcome = winnerIds
    ? { winnerIds, draw: winnerIds.length === 0 }
    : winnersFromScores(scores);
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
      activePlayerIds: [],
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
    participants: playerIds,
    result,
    endedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  });
  return { completed: true, result };
}

function continueTurn(transaction, {
  gameRef,
  FieldValue,
  game,
  now,
  state,
  currentPlayerId,
  scores,
  lastMove,
}) {
  const cfg = configOf(game);
  transaction.update(gameRef, {
    publicState: {
      ...state,
      phase: "turn",
      currentPlayerId,
      scores,
      lastMove,
    },
    currentPhase: "turn",
    stateVersion: bumpVersion(game),
    deadlineAt: deadlineAt(now, cfg.timerSeconds),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

function eliminateCurrent(transaction, ctx, reason) {
  const {
    game,
    gameRef,
    FieldValue,
    now,
    db,
    gameId,
  } = ctx;
  const state = game.publicState || {};
  const current = state.currentPlayerId;
  const activePlayerIds = (state.activePlayerIds || []).filter((id) => id !== current);
  const playerIds = state.playerOrder || Object.keys(state.scores || {});
  const scores = state.scores || emptyScores(playerIds);
  if (activePlayerIds.length <= 1) {
    return complete(ctx.transaction, {
      ...ctx,
      db,
      gameRef,
      FieldValue,
      game,
      gameId,
      scores,
      playerIds,
      now,
      reason,
      winnerIds: activePlayerIds,
    });
  }
  continueTurn(ctx.transaction, {
    gameRef,
    FieldValue,
    game,
    now,
    state: {
      ...state,
      activePlayerIds,
      eliminatedIds: [...(state.eliminatedIds || []), current],
    },
    currentPlayerId: nextActivePlayer(
      { activePlayerIds },
      current,
    ),
    scores,
    lastMove: { type: "eliminated", playerId: current, reason },
  });
  return { completed: false, result: null };
}

function initialize({
  transaction,
  gameRef,
  FieldValue,
  game,
  playerIds,
  random,
  now,
}) {
  if (playerIds.length !== 2) {
    throw new Error("Anime Chain requires exactly two players.");
  }
  if (game.publicState && game.publicState.engine === "animeChain") return;
  const seed = pickOne(catalog.ANIME, random);
  const publicState = {
    engine: "animeChain",
    phase: "turn",
    rule: CHAIN_RULE,
    chain: [{ animeId: seed.id, title: seed.title }],
    currentPlayerId: playerIds[0],
    playerOrder: playerIds,
    activePlayerIds: playerIds,
    eliminatedIds: [],
    scores: emptyScores(playerIds),
    lastMove: null,
  };
  transaction.update(gameRef, {
    publicState,
    currentPhase: "turn",
    stateVersion: bumpVersion(game),
    deadlineAt: deadlineAt(now, configOf(game).timerSeconds),
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
    db,
    gameId,
  } = ctx;
  const state = game.publicState || {};
  rejectStale(action.payload, game, HttpsError);
  if (state.phase !== "turn") {
    throw new HttpsError("failed-precondition", "This chain is not active.");
  }
  if (state.currentPlayerId !== uid) {
    throw new HttpsError("failed-precondition", "It is not your turn.");
  }
  if (isExpired(game.deadlineAt, now)) {
    throw new HttpsError("failed-precondition", "This turn has expired.");
  }
  if (action.actionType === "resign" || action.actionType === "forfeit") {
    return eliminateCurrent(transaction, ctx, "resigned");
  }
  if (action.actionType !== "submit" && action.actionType !== "guess") {
    throw new HttpsError("invalid-argument", "Submit an anime title.");
  }
  const raw = action.payload && (
    action.payload.animeId || action.payload.title || action.payload.value
  );
  const match = catalog.byAnimeId(raw) || catalog.animeByTitle(raw);
  if (!match) {
    return eliminateCurrent(transaction, ctx, "invalid_anime");
  }
  const chain = state.chain || [];
  if (chain.some((item) => item.animeId === match.id)) {
    return eliminateCurrent(transaction, ctx, "duplicate_anime");
  }
  const last = chain[chain.length - 1];
  if (!catalog.sharesRelation(last.animeId, match.id)) {
    return eliminateCurrent(transaction, ctx, "invalid_chain_link");
  }
  const scores = { ...(state.scores || {}) };
  scores[uid] = (scores[uid] || 0) + 1;
  const nextChain = [...chain, { animeId: match.id, title: match.title }];
  if (nextChain.length >= configOf(game).maxChain) {
    return complete(transaction, {
      ...ctx,
      db,
      gameRef,
      FieldValue,
      game: { ...game, publicState: { ...state, chain: nextChain } },
      gameId,
      scores,
      playerIds: state.playerOrder || Object.keys(scores),
      now,
      reason: "chain_complete",
    });
  }
  const nextState = { ...state, chain: nextChain };
  continueTurn(transaction, {
    gameRef,
    FieldValue,
    game,
    now,
    state: nextState,
    currentPlayerId: nextActivePlayer(state, uid),
    scores,
    lastMove: { type: "valid", playerId: uid, animeId: match.id },
  });
  return { completed: false, result: null };
}

function onTimeout(ctx) {
  const { game } = ctx;
  const state = game.publicState || {};
  if (state.phase !== "turn") return { completed: false, result: null };
  return eliminateCurrent(ctx.transaction, ctx, "timeout");
}

module.exports = {
  initialize,
  applyAction,
  onTimeout,
  CHAIN_RULE,
};