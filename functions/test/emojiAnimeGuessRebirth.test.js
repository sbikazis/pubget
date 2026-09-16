"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const engine = require("../src/gameEngines/emojiAnimeGuess");

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
    random: () => 0, now: new Date(),
  });
  const state = h.writes.get("games/g1").publicState;
  assert.deepEqual(state.playerOrder, ["a", "b", "c", "d"]);
  assert.equal(state.currentPlayerId, "a");
  assert.equal(state.totalTurns, 4);
  assert.equal(state.emojis.length, 3);
  assert.throws(() => engine.applyAction({
    ...h, game, gameRef: h.gameRef, uid: "a", now: new Date(),
    HttpsError: class extends Error { constructor(code, message) { super(message); this.code = code; } },
    action: { actionType: "guess", payload: { animeId: "naruto" } },
    secretSnap: { exists: true, data: () => ({ targetAnimeId: "one_piece", title: "One Piece" }) },
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
    secretSnap: { exists: true, data: () => ({
      targetAnimeId: "naruto", title: "Naruto", usedAnimeIds: ["naruto"],
    }) },
    random: () => 0,
  });
  assert.equal(result.completed, false);
  const after = h.writes.get("games/g1");
  assert.equal(after.publicState.scores.b, 1);
  assert.equal(after.publicState.currentPlayerId, "b");
  assert.deepEqual(after.publicState.answeredPlayerIds, []);
});
