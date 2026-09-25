"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const engine = require("../src/gameEngines/animeChain");
const {
  FAKE_ANIME,
  relatedAnimeId,
  titleOf,
} = require("./support/fakeAnimeCatalog");

// The domain resolves the seed and every submitted title against the canonical
// repository before the engine runs, so these tests drive the engine with the
// resolved context instead of the offline snapshot.
function fakeCatalog() {
  return {
    FAKE_ANIME,
    relatedAnimeId,
    get(id) {
      return FAKE_ANIME.find((item) => item.id === id) || null;
    },
  };
}

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
      chain: [{ animeId: "jikan:1002", title: "Naruto" }],
      scores: { alice: 0, bob: 0 },
    },
    ...overrides,
  };
}

test("Anime Chain rejects a title that resolves to nothing and awards direct opponent win", () => {
  const h = harness(game());
  const outcome = engine.applyAction({
    ...h,
    FieldValue,
    gameId: "g1",
    uid: "alice",
    action: { actionType: "submit", payload: { title: "A made up anime" } },
    now: new Date(),
    HttpsError: class extends Error {},
    resolvedAnime: null,
    resolvedPreviousAnime: fakeCatalog().get("jikan:1002"),
    chainValid: false,
  });
  assert.equal(outcome.completed, true);
  assert.deepEqual(outcome.result.winnerIds, ["bob"]);
  assert.equal(outcome.result.summary.reason, "invalid_anime");
});

test("Anime Chain uses canonical IDs, relation validation, and no repeats", () => {
  const h = harness(game());
  const relatedId = relatedAnimeId("jikan:1002");
  assert.ok(relatedId, "the fixture catalog must contain a related title");
  const first = engine.applyAction({
    ...h,
    FieldValue,
    gameId: "g1",
    uid: "alice",
    action: { actionType: "submit", payload: { animeId: relatedId } },
    now: new Date(),
    HttpsError: class extends Error {},
    resolvedAnime: fakeCatalog().get(relatedId),
    resolvedPreviousAnime: fakeCatalog().get("jikan:1002"),
    chainValid: true,
  });
  assert.equal(first.completed, false);
  const next = h.writes.find((write) => write.type === "update").value.publicState;
  assert.equal(next.chain[1].animeId, relatedId);
  assert.equal(next.chain[1].title, titleOf(relatedId));
  assert.equal(next.currentPlayerId, "bob");

  const duplicateGame = game({ publicState: next, stateVersion: 1 });
  const duplicate = harness(duplicateGame);
  const result = engine.applyAction({
    ...duplicate,
    FieldValue,
    gameId: "g1",
    uid: "bob",
    action: { actionType: "submit", payload: { animeId: relatedId } },
    now: new Date(),
    HttpsError: class extends Error {},
    resolvedAnime: fakeCatalog().get(relatedId),
    resolvedPreviousAnime: fakeCatalog().get("jikan:1002"),
    chainValid: false,
  });
  assert.equal(result.completed, true);
  assert.deepEqual(result.result.winnerIds, ["alice"]);
});

test("Anime Chain picks its seed from the canonical pool, not the snapshot", () => {
  const h = harness(game({ publicState: null, stateVersion: 3 }));
  engine.initialize({
    ...h,
    FieldValue,
    playerIds: ["alice", "bob"],
    random: () => 0,
    now: new Date("2026-01-01T00:00:00Z"),
    animePool: FAKE_ANIME,
  });
  const state = h.writes.at(-1).value.publicState;
  assert.equal(state.chain[0].animeId, FAKE_ANIME[0].id);
  assert.equal(state.chain[0].title, titleOf(FAKE_ANIME[0].id));
  assert.equal(state.chain.length, 1);
});

test("Anime Chain refuses a 3+ player match", () => {
  const h = harness(game({ publicState: null }));
  assert.throws(
    () => engine.initialize({
      ...h,
      FieldValue,
      playerIds: ["alice", "bob", "charlie"],
      random: () => 0,
      now: new Date(),
      animePool: FAKE_ANIME,
    }),
    /exactly two players/,
  );
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
