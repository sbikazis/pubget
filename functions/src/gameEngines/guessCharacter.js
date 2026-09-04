"use strict";

const catalog = require("../gameCatalog");
const {
  clampInt,
  isExpired,
  deadlineAt,
  shuffle,
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
    roundCount: clampInt(configuration.roundCount, 5, 3, 8),
    timerSeconds: clampInt(configuration.timerSeconds, 20, 10, 45),
  };
}

function publicChoices(character, distractors, random) {
  const choices = shuffle(
    [character, ...distractors].map((item) => ({
      id: item.id,
      name: item.name,
    })),
    random,
  );
  return choices;
}

function nextRound({ usedIds, random }) {
  const pool = catalog.allCharacters().filter((item) => !usedIds.includes(item.id));
  const source = pool.length >= 4 ? pool : catalog.allCharacters();
  const ordered = shuffle(source, random);
  const character = ordered[0];
  const distractors = ordered
    .filter((item) => item.id !== character.id)
    .slice(0, 3);
  return { character, distractors };
}

function writeRound(transaction, {
  gameRef, FieldValue, game, playerIds, usedIds, random, now, roundNumber, scores,
}) {
  const { character, distractors } = nextRound({ usedIds, random });
  const cfg = configOf(game);
  const nextUsed = usedIds.includes(character.id)
    ? usedIds
    : [...usedIds, character.id];
  const publicState = {
    engine: "guessCharacter",
    phase: "round",
    roundNumber,
    totalRounds: cfg.roundCount,
    prompt: {
      question: "Who is this character?",
      clue: character.clue,
      choices: publicChoices(character, distractors, random),
    },
    scores,
    answeredPlayerIds: [],
    lastReveal: game.publicState && game.publicState.lastReveal
      ? game.publicState.lastReveal
      : null,
  };
  transaction.set(secretRef(gameRef), {
    roundNumber,
    correctId: character.id,
    correctName: character.name,
    usedCharacterIds: nextUsed,
    answers: {},
  });
  transaction.update(gameRef, {
    publicState,
    currentPhase: "round",
    currentRoundNumber: roundNumber,
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
    kind: "guessCharacter",
    winnerIds: outcome.winnerIds,
    scores,
    summary: {
      draw: outcome.draw,
      rounds: (game.publicState && game.publicState.totalRounds) || 0,
    },
  };
  const publicState = {
    ...(game.publicState || {}),
    engine: "guessCharacter",
    phase: "game_over",
    scores,
    answeredPlayerIds: (game.publicState && game.publicState.answeredPlayerIds) || [],
    lastReveal,
    prompt: null,
  };
  transaction.update(gameRef, {
    status: "completed",
    result,
    endedAt: now,
    publicState,
    currentPhase: "game_over",
    deadlineAt: null,
    stateVersion: bumpVersion(game),
    updatedAt: FieldValue.serverTimestamp(),
  });
  transaction.set(historyRef(db, gameId), {
    gameId,
    type: "guessCharacter",
    groupId: game.groupId || null,
    participants: Object.keys(scores),
    result,
    endedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  });
  return { completed: true, result };
}

function resolveRound(transaction, ctx) {
  const {
    db, gameRef, FieldValue, game, gameId, secret, now, random,
  } = ctx;
  const playerIds = Object.keys((game.publicState && game.publicState.scores) || {});
  const scores = { ...(game.publicState && game.publicState.scores) || emptyScores(playerIds) };
  const answers = (secret && secret.answers) || {};
  const correctId = secret.correctId;
  for (const uid of playerIds) {
    if (answers[uid] && answers[uid] === correctId) {
      scores[uid] = (scores[uid] || 0) + 1;
    }
  }
  const lastReveal = {
    roundNumber: secret.roundNumber,
    correctId,
    correctName: secret.correctName,
  };
  const cfg = configOf(game);
  if (secret.roundNumber >= cfg.roundCount) {
    return complete(transaction, {
      db, gameRef, FieldValue, game, gameId, scores, now, lastReveal,
    });
  }
  const usedIds = secret.usedCharacterIds || [];
  game.publicState = { ...(game.publicState || {}), lastReveal, scores };
  writeRound(transaction, {
    gameRef, FieldValue, game, playerIds, usedIds, random, now,
    roundNumber: secret.roundNumber + 1,
    scores,
  });
  return { completed: false, result: null };
}

function initialize({
  transaction, gameRef, FieldValue, game, playerIds, random, now,
}) {
  if (game.publicState && game.publicState.engine === "guessCharacter") return;
  const scores = emptyScores(playerIds);
  writeRound(transaction, {
    gameRef, FieldValue, game, playerIds, usedIds: [], random, now,
    roundNumber: 1, scores,
  });
}

function applyAction(ctx) {
  const {
    transaction, gameRef, FieldValue, game, uid, action, now, HttpsError, secretSnap,
    db, gameId, random,
  } = ctx;
  rejectStale(action.payload, game, HttpsError);
  if (!game.publicState || game.publicState.phase !== "round") {
    throw new HttpsError("failed-precondition", "This round is not accepting answers.");
  }
  if (isExpired(game.deadlineAt, now)) {
    throw new HttpsError("failed-precondition", "This round has already ended.");
  }
  const answered = game.publicState.answeredPlayerIds || [];
  if (answered.includes(uid)) {
    throw new HttpsError("already-exists", "You already answered this round.");
  }
  if (action.actionType !== "guess" && action.actionType !== "select") {
    throw new HttpsError("invalid-argument", "Guess Character expects a guess.");
  }
  const choiceId = action.payload && (action.payload.choiceId || action.payload.value);
  const validIds = (game.publicState.prompt && game.publicState.prompt.choices || [])
    .map((item) => item.id);
  if (typeof choiceId !== "string" || !validIds.includes(choiceId)) {
    throw new HttpsError("invalid-argument", "Choose one of the listed characters.");
  }
  const secret = secretSnap && secretSnap.exists ? secretSnap.data() : null;
  if (!secret || secret.roundNumber !== game.publicState.roundNumber) {
    throw new HttpsError("failed-precondition", "The round is still being prepared.");
  }
  const nextAnswered = [...answered, uid];
  const answers = { ...(secret.answers || {}), [uid]: choiceId };
  const playerIds = Object.keys(game.publicState.scores || {});
  const publicState = {
    ...game.publicState,
    answeredPlayerIds: nextAnswered,
  };
  const nextSecret = { ...secret, answers };
  transaction.set(secretRef(gameRef), nextSecret);
  transaction.update(gameRef, {
    publicState,
    stateVersion: bumpVersion(game),
    updatedAt: FieldValue.serverTimestamp(),
  });
  game.publicState = publicState;
  game.stateVersion = (Number(game.stateVersion) || 0) + 1;
  if (nextAnswered.length >= playerIds.length) {
    return resolveRound(transaction, {
      db, gameRef, FieldValue, game, gameId, secret: nextSecret, now, random,
    });
  }
  return { completed: false, result: null };
}

function onTimeout(ctx) {
  const { transaction, game, secretSnap } = ctx;
  if (!game.publicState || game.publicState.phase !== "round") {
    return { completed: false, result: null };
  }
  const secret = secretSnap && secretSnap.exists ? secretSnap.data() : null;
  if (!secret) return { completed: false, result: null };
  return resolveRound(transaction, { ...ctx, secret });
}

module.exports = {
  initialize,
  applyAction,
  onTimeout,
};
