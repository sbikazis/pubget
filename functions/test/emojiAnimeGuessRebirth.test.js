"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const engine = require("../src/gameEngines/emojiAnimeGuess");
const { FAKE_ANIME, titleOf } = require("./support/fakeAnimeCatalog");

// `random: () => 0` makes the engine take the first pool entry as the target.
const TARGET = FAKE_ANIME[0];
const OTHER = FAKE_ANIME[3];

const FieldValue = {
  serverTimestamp: () => ({ server: true }),
};

function harness(game) {
  const writes = new Map();
  const transaction = {
    set(ref, value) { writes.set(ref.path, JSON.parse(JSON.stringify(value))); },
    update(ref, value) {
      const old = writes.get(ref.path) || game;
      writes.set(ref.path, { ...old, ...value });
    },
  };
  return { transaction, writes, gameRef: { path: "games/g1", collection: (n) => ({
    doc: (id) => ({ path: `games/g1/${n}/${id}` }),
  }) } };
}

function baseGame(players) {
  return {
    type: "emojiAnimeGuess",
    groupId: "g",
    configuration: { roundCount: 1, timerSeconds: 30 },
    stateVersion: 0,
    deadlineAt: new Date(Date.now() + 30000),
    publicState: {
      engine: "emojiAnimeGuess",
      phase: "guess",
      playerOrder: players,
      currentPlayerId: players[0],
      scores: Object.fromEntries(players.map((id) => [id, 0])),
      answeredPlayerIds: [],
      turnIndex: 0,
      totalTurns: players.length,
    },
  };
}

test("emoji rounds rotate equally and make the owner ineligible to guess", () => {
  const game = baseGame(["a", "b", "c", "d"]);
  game.publicState = null;
  const h = harness(game);
  engine.initialize({
    ...h, game, gameRef: h.gameRef, FieldValue, playerIds: ["a", "b", "c", "d"],
    random: () => 0, now: new Date(), animePool: FAKE_ANIME,
  });
  const state = h.writes.get("games/g1").publicState;
  assert.deepEqual(state.playerOrder, ["a", "b", "c", "d"]);
  assert.equal(state.currentPlayerId, "a");
  assert.equal(state.totalTurns, 4);
  assert.ok(state.emojis.length >= 3 && state.emojis.length <= 4);
  assert.equal(state.currentAnimeId, undefined, "the target must stay private");
  const secret = h.writes.get("games/g1/secret/round");
  assert.equal(secret.targetAnimeId, TARGET.id);
  assert.throws(() => engine.applyAction({
    ...h, game, gameRef: h.gameRef, uid: "a", now: new Date(),
    HttpsError: class extends Error { constructor(code, message) { super(message); this.code = code; } },
    action: { actionType: "guess", payload: { animeId: OTHER.id } },
    resolvedAnime: OTHER,
    animePool: FAKE_ANIME,
    secretSnap: { exists: true, data: () => ({ targetAnimeId: TARGET.id, title: TARGET.title }) },
  }), (error) => error.code === "failed-precondition");
});

test("first correct canonical selection scores and closes the round", () => {
  const game = baseGame(["a", "b", "c"]);
  const h = harness(game);
  const errorType = class extends Error {
    constructor(code, message) { super(message); this.code = code; }
  };
  const result = engine.applyAction({
    ...h, game, gameRef: h.gameRef, uid: "b", now: new Date(),
    FieldValue,
    HttpsError: errorType,
    action: { actionType: "guess", payload: { title: "Naruto!" } },
    // The repository resolved the player's free text to the canonical entry.
    resolvedAnime: TARGET,
    animePool: FAKE_ANIME,
    secretSnap: { exists: true, data: () => ({
      targetAnimeId: TARGET.id, title: TARGET.title, usedAnimeIds: [TARGET.id],
    }) },
    random: () => 0,
  });
  assert.equal(result.completed, false);
  const after = h.writes.get("games/g1");
  assert.equal(after.publicState.scores.b, 1);
  assert.equal(after.publicState.currentPlayerId, "b");
  assert.deepEqual(after.publicState.answeredPlayerIds, []);
  assert.equal(after.publicState.lastReveal.correct, true);
  assert.equal(after.publicState.lastReveal.winnerId, "b");
});

test("a guess that resolves to nothing is rejected as an invalid selection", () => {
  const game = baseGame(["a", "b", "c"]);
  const h = harness(game);
  const errorType = class extends Error {
    constructor(code, message) { super(message); this.code = code; }
  };
  assert.throws(() => engine.applyAction({
    ...h, game, gameRef: h.gameRef, uid: "b", now: new Date(),
    FieldValue,
    HttpsError: errorType,
    action: { actionType: "guess", payload: { title: "A made up anime" } },
    resolvedAnime: null,
    animePool: FAKE_ANIME,
    secretSnap: { exists: true, data: () => ({
      targetAnimeId: TARGET.id, title: TARGET.title, usedAnimeIds: [TARGET.id],
    }) },
    random: () => 0,
  }), (error) => error.code === "invalid-argument");
});

test("the emoji clues never contain the target title", () => {
  const game = baseGame(["a", "b"]);
  game.publicState = null;
  const h = harness(game);
  engine.initialize({
    ...h, game, gameRef: h.gameRef, FieldValue, playerIds: ["a", "b"],
    random: () => 0, now: new Date(), animePool: FAKE_ANIME,
  });
  const state = h.writes.get("games/g1").publicState;
  const blob = JSON.stringify(state.emojis).toLowerCase();
  assert.equal(blob.includes(titleOf(TARGET.id).toLowerCase()), false);
  assert.ok(state.emojis.every((emoji) => !/[a-z]/i.test(emoji.replace(/\u200d/g, ""))));
});
