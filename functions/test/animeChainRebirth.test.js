"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const engine = require("../src/gameEngines/animeChain");
const catalog = require("../src/gameCatalog");

const FieldValue = {
  serverTimestamp: () => ({ server: true }),
};

function harness(game) {
  const writes = [];
  const transaction = {
    update(ref, value) { writes.push({ type: "update", ref, value }); },
    set(ref, value) { writes.push({ type: "set", ref, value }); },
  };
  const db = {
    collection(name) {
      return { doc(id) { return { path: `${name}/${id}` }; } };
    },
  };
  return { writes, transaction, db, gameRef: { path: "games/g1" }, game };
}

function game(overrides = {}) {
  return {
    configuration: { timerSeconds: 25, roundCount: 8 },
    stateVersion: 0,
    deadlineAt: new Date(Date.now() + 60_000),
    publicState: {
      engine: "animeChain",
      phase: "turn",
      playerOrder: ["alice", "bob"],
      currentPlayerId: "alice",
      chain: [{ animeId: "naruto", title: "Naruto" }],
      scores: { alice: 0, bob: 0 },
    },
    ...overrides,
  };
}

test("Anime Chain rejects unknown free text and awards direct opponent win", () => {
  const h = harness(game());
  const outcome = engine.applyAction({
    ...h,
    FieldValue,
    gameId: "g1",
    uid: "alice",
    action: { actionType: "submit", payload: { title: "A made up anime" } },
    now: new Date(),
    HttpsError: class extends Error {},
  });
  assert.equal(outcome.completed, true);
  assert.deepEqual(outcome.result.winnerIds, ["bob"]);
  assert.equal(outcome.result.summary.reason, "invalid_anime");
});

test("Anime Chain uses canonical IDs, relation validation, and no repeats", () => {
  const h = harness(game());
  const related = catalog.ANIME.find((item) =>
    catalog.sharesRelation("naruto", item.id));
  const first = engine.applyAction({
    ...h,
    FieldValue,
    gameId: "g1",
    uid: "alice",
    action: { actionType: "submit", payload: { animeId: related.id } },
    now: new Date(),
    HttpsError: class extends Error {},
  });
  assert.equal(first.completed, false);
  const next = h.writes.find((write) => write.type === "update").value.publicState;
  assert.equal(next.chain[1].animeId, related.id);
  assert.equal(next.currentPlayerId, "bob");

  const duplicateGame = game({ publicState: next, stateVersion: 1 });
  const duplicate = harness(duplicateGame);
  const result = engine.applyAction({
    ...duplicate,
    FieldValue,
    gameId: "g1",
    uid: "bob",
    action: { actionType: "submit", payload: { animeId: related.id } },
    now: new Date(),
    HttpsError: class extends Error {},
  });
  assert.equal(result.completed, true);
  assert.deepEqual(result.result.winnerIds, ["alice"]);
});

test("Anime Chain timeout is a failed turn and direct opponent win", () => {
  const h = harness(game());
  const outcome = engine.onTimeout({
    ...h,
    FieldValue,
    gameId: "g1",
    now: new Date(),
  });
  assert.equal(outcome.completed, true);
  assert.deepEqual(outcome.result.winnerIds, ["bob"]);
  assert.equal(outcome.result.summary.reason, "timeout");
});