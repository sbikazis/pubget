"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const engine = require("../src/gameEngines/guessCharacter");
const { FAKE_ANIME } = require("./support/fakeAnimeCatalog");

const LUFFY = { id: "jikan:2001", name: "Monkey D. Luffy", animeIds: ["jikan:1001"] };
const NARUTO = { id: "jikan:2003", name: "Naruto Uzumaki", animeIds: ["jikan:1002"] };

const FieldValue = {
  serverTimestamp: () => ({ server: true }),
};

function harness() {
  const writes = [];
  const transaction = {
    set: (ref, value) => writes.push(["set", ref.path || ref, value]),
    update: (ref, value) => writes.push(["update", ref.path || ref, value]),
  };
  const gameRef = {
    path: "games/g1",
    collection: (name) => ({
      doc: (id) => ({ path: `games/g1/${name}/${id}` }),
    }),
  };
  const game = {
    type: "guessCharacter",
    groupId: "g",
    stateVersion: 0,
    startedAt: new Date("2026-01-01T00:00:00Z"),
    publicState: null,
    configuration: { selectionSeconds: 30, timerSeconds: 30 },
  };
  return { writes, transaction, gameRef, game };
}

function error(code, message) {
  const e = new Error(message);
  e.code = code;
  return e;
}

test("Guess Character keeps selections private and enforces the 1v1 turn protocol", () => {
  const h = harness();
  engine.initialize({
    ...h,
    FieldValue,
    playerIds: ["alice", "bob"],
    now: new Date("2026-01-01T00:00:00Z"),
  });
  const initial = h.writes.find((entry) => entry[0] === "update")[2];
  assert.equal(initial.publicState.phase, "selection");
  assert.equal(JSON.stringify(initial.publicState).includes("2001"), false);

  const selection = {
    exists: true,
    data: () => ({ selections: {} }),
  };
  // The domain resolves a submitted ID against the canonical repository before
  // the engine runs, so the engine receives the validated entity.
  const resolveFor = (payload) => {
    if (payload.characterId === LUFFY.id) return LUFFY;
    if (payload.characterId === NARUTO.id) return NARUTO;
    return null;
  };
  const ctx = (uid, action, game, secretSnap) => ({
    ...h,
    FieldValue,
    game,
    uid,
    action: { payload: {}, ...action },
    now: new Date("2026-01-01T00:00:01Z"),
    HttpsError: error,
    secretSnap,
    db: { collection: () => ({ doc: () => ({}) }) },
    gameId: "g1",
    resolvedCharacter: resolveFor({ payload: {}, ...action }.payload),
  });
  const first = engine.applyAction(ctx("alice", {
    actionType: "select",
    payload: { characterId: LUFFY.id },
  }, { ...h.game, stateVersion: 1, publicState: initial.publicState }, selection));
  assert.equal(first.completed, false);
  const publicAfterFirst = h.writes.filter((entry) => entry[0] === "update").at(-1)[2].publicState;
  assert.equal(publicAfterFirst.players.alice.selected, true);
  assert.equal(JSON.stringify(publicAfterFirst).includes("2001"), false);
  assert.throws(() => engine.applyAction(ctx("bob", {
    actionType: "select",
    payload: { characterId: LUFFY.id },
  }, { ...h.game, stateVersion: 2, publicState: publicAfterFirst }, {
    exists: true,
    data: () => ({ selections: { alice: LUFFY.id } }),
  })), (e) => e.code === "invalid-argument");
});

test("Guess Character rejects a guess that resolves to nothing", () => {
  const h = harness();
  engine.initialize({
    ...h,
    FieldValue,
    playerIds: ["alice", "bob"],
    now: new Date("2026-01-01T00:00:00Z"),
  });
  const initial = h.writes.find((entry) => entry[0] === "update")[2];
  const selection = { exists: true, data: () => ({ selections: { bob: NARUTO.id } }) };
  const asking = { ...h.game, stateVersion: 1, publicState: {
    ...initial.publicState,
    phase: "ask",
    currentPlayerId: "alice",
    players: { alice: { selected: true }, bob: { selected: true } },
  } };
  assert.throws(
    () => engine.applyAction({
      ...h,
      FieldValue,
      game: asking,
      uid: "alice",
      action: { actionType: "guess", payload: { characterId: "jikan:404" } },
      now: new Date("2026-01-01T00:00:01Z"),
      HttpsError: error,
      secretSnap: selection,
      db: { collection: () => ({ doc: () => ({}) }) },
      gameId: "g1",
      resolvedCharacter: null,
    }),
    (e) => e.code === "invalid-argument",
  );
});

test("Guess Character pool is untouched by the offline snapshot", () => {
  assert.ok(FAKE_ANIME.length >= 3);
  assert.ok(!FAKE_ANIME.some((item) => item.id === "luffy"));
});
