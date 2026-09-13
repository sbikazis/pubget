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
    timerSeconds: clampInt(configuration.timerSeconds, 25, 12, 60),
    roundsPerPlayer: clampInt(configuration.roundCount, 1, 1, 3),
  };
}

function publicEmojis(target) {
  return (Array.isArray(target.emojiClues) ? target.emojiClues : [])
    .map((item) => String(item))
    .filter(Boolean)
    .slice(0, 4);
}

function complete(transaction, {
  db,
  gameRef,
  FieldValue,
  game,
  gameId,
  playerIds,
  scores,
  now,
  lastReveal,
  reason,
}) {
  const outcome = winnersFromScores(scores);
  const result = {
    kind: "emojiAnimeGuess",
    winnerIds: outcome.winnerIds,
    scores,
    summary: { draw: outcome.draw, reason: reason || "completed" },
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
      turnOwnerId: null,
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
    participants: playerIds,
    result,
    endedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  });
  return { completed: true, result };
}

function nextTurn(transaction, ctx, {
  scores,
  lastReveal,
  reason,
}) {
  const {
    gameRef,
    FieldValue,
    game,
    now,
    random,
    playerIds,
    gameId,
    db,
  } = ctx;
  const state = game.publicState || {};
  const order = state.playerOrder || playerIds;
  const nextTurnIndex = (state.turnIndex || 0) + 1;
  const totalTurns = state.totalTurns || order.length;
  if (nextTurnIndex >= totalTurns) {
    return complete(ctx.transaction, {
      ...ctx,
      db,
      gameRef,
      FieldValue,
      game,
      gameId,
      playerIds: order,
      scores,
      now,
      lastReveal,
      reason,
    });
  }
  const owner = order[nextTurnIndex % order.length];
  const targetPool = catalog.ANIME;
  const target = pickOne(targetPool, random);
  const emojis = publicEmojis(target);
  ctx.transaction.set(secretRef(gameRef), {
    targetAnimeId: target.id,
    title: target.title,
    turnIndex: nextTurnIndex,
  });
  ctx.transaction.update(gameRef, {
    publicState: {
      engine: "emojiAnimeGuess",
      phase: "guess",
      emojis,
      currentPlayerId: owner,
      turnOwnerId: owner,
      playerOrder: order,
      eligibleGuesserIds: order.filter((id) => id !== owner),
      guessedPlayerIds: [],
      scores,
      turnIndex: nextTurnIndex,
      totalTurns,
      lastReveal: lastReveal || null,
      lastMove: reason ? { reason } : null,
    },
    currentPhase: "guess",
    currentRoundNumber: nextTurnIndex + 1,
    stateVersion: bumpVersion(game),
    deadlineAt: deadlineAt(now, configOf(game).timerSeconds),
    updatedAt: FieldValue.serverTimestamp(),
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
  if (playerIds.length < 2 || playerIds.length > 4) {
    throw new Error("Emoji Anime Guess requires two to four players.");
  }
  if (game.publicState && game.publicState.engine === "emojiAnimeGuess") return;
  const cfg = configOf(game);
  const owner = playerIds[0];
  const target = pickOne(catalog.ANIME, random);
  const totalTurns = playerIds.length * cfg.roundsPerPlayer;
  transaction.set(secretRef(gameRef), {
    targetAnimeId: target.id,
    title: target.title,
    turnIndex: 0,
  });
  transaction.update(gameRef, {
    publicState: {
      engine: "emojiAnimeGuess",
      phase: "guess",
      emojis: publicEmojis(target),
      currentPlayerId: owner,
      turnOwnerId: owner,
      playerOrder: playerIds,
      eligibleGuesserIds: playerIds.filter((id) => id !== owner),
      guessedPlayerIds: [],
      scores: emptyScores(playerIds),
      turnIndex: 0,
      totalTurns,
      lastReveal: null,
      lastMove: null,
    },
    currentPhase: "guess",
    currentRoundNumber: 1,
    stateVersion: bumpVersion(game),
    deadlineAt: deadlineAt(now, cfg.timerSeconds),
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
  } = ctx;
  const state = game.publicState || {};
  rejectStale(action.payload, game, HttpsError);
  if (state.phase !== "guess") {
    throw new HttpsError("failed-precondition", "This round is not accepting guesses.");
  }
  if (isExpired(game.deadlineAt, now)) {
    throw new HttpsError("failed-precondition", "This round has already ended.");
  }
  if (uid === state.turnOwnerId) {
    throw new HttpsError(
      "failed-precondition",
      "The turn owner presents the clue; other players guess.",
    );
  }
  if (!(state.eligibleGuesserIds || []).includes(uid)) {
    throw new HttpsError("permission-denied", "You are not an active player.");
  }
  if ((state.guessedPlayerIds || []).includes(uid)) {
    throw new HttpsError("already-exists", "You already guessed this round.");
  }
  if (action.actionType !== "guess" && action.actionType !== "submit") {
    throw new HttpsError("invalid-argument", "Submit an anime title.");
  }
  const raw = action.payload && (
    action.payload.title || action.payload.value || action.payload.animeId
  );
  const match = catalog.byAnimeId(raw) || catalog.animeByTitle(raw);
  if (!match) {
    throw new HttpsError("invalid-argument", "That anime is not in the catalog.");
  }
  const secret = secretSnap && secretSnap.exists ? secretSnap.data() : null;
  if (!secret) {
    throw new HttpsError("failed-precondition", "This clue is still being prepared.");
  }
  const guessedPlayerIds = [...(state.guessedPlayerIds || []), uid];
  const scores = { ...(state.scores || {}) };
  const correct = match.id === secret.targetAnimeId;
  if (correct) scores[uid] = (scores[uid] || 0) + 1;
  const lastReveal = {
    animeId: secret.targetAnimeId,
    title: secret.title,
    winnerId: correct ? uid : null,
    guessedTitle: match.title,
    correct,
  };
  if (correct) {
    return nextTurn(transaction, {
      ...ctx,
      playerIds: state.playerOrder || Object.keys(scores),
    }, { scores, lastReveal, reason: "correct_guess" });
  }
  const eligible = state.eligibleGuesserIds || [];
  if (guessedPlayerIds.length >= eligible.length) {
    return nextTurn(transaction, {
      ...ctx,
      playerIds: state.playerOrder || Object.keys(scores),
    }, { scores, lastReveal, reason: "no_winner" });
  }
  transaction.update(gameRef, {
    publicState: {
      ...state,
      guessedPlayerIds,
      scores,
      lastMove: { type: "wrong_guess", playerId: uid },
    },
    stateVersion: bumpVersion(game),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { completed: false, result: null };
}

function onTimeout(ctx) {
  const { game } = ctx;
  const state = game.publicState || {};
  if (state.phase !== "guess") return { completed: false, result: null };
  return nextTurn(ctx.transaction, {
    ...ctx,
    playerIds: state.playerOrder || [],
  }, {
    scores: state.scores || {},
    lastReveal: {
      animeId: "",
      title: "",
      winnerId: null,
      correct: false,
      reason: "timeout",
    },
    reason: "timeout",
  });
}

module.exports = {
  initialize,
  applyAction,
  onTimeout,
};