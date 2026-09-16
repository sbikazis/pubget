"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  GAME_TYPE_REGISTRY,
  STATUSES,
  TRANSITIONS,
  canTransition,
  normalizeConfiguration,
} = require("../src/gamesDomain");

test("rebirth exposes only the three generic games and fixed cardinalities", () => {
  assert.deepEqual(STATUSES, [
    "CREATED", "WAITING", "STARTING", "IN_PROGRESS", "COMPLETED", "CANCELLED",
  ]);
  assert.equal(GAME_TYPE_REGISTRY.mafia, undefined);
  assert.deepEqual(
    Object.fromEntries(Object.entries(GAME_TYPE_REGISTRY).map(([type, spec]) => [
      type, [spec.capabilities.minPlayers, spec.capabilities.maxPlayers],
    ])),
    {
      guessCharacter: [2, 2],
      animeChain: [2, 2],
      emojiAnimeGuess: [2, 4],
    },
  );
  assert.deepEqual(
    normalizeConfiguration({ minPlayers: 1, maxPlayers: 99 }, GAME_TYPE_REGISTRY.emojiAnimeGuess)
      .minPlayers,
    2,
  );
});

test("rebirth state machine has no pause/resume or force-complete transitions", () => {
  assert.equal(canTransition("CREATED", "WAITING"), true);
  assert.equal(canTransition("WAITING", "STARTING"), true);
  assert.equal(canTransition("STARTING", "IN_PROGRESS"), true);
  assert.equal(canTransition("IN_PROGRESS", "COMPLETED"), true);
  assert.equal(canTransition("IN_PROGRESS", "CANCELLED"), true);
  assert.equal(canTransition("IN_PROGRESS", "WAITING"), false);
  assert.equal(canTransition("IN_PROGRESS", "PAUSED"), false);
  assert.equal(canTransition("COMPLETED", "IN_PROGRESS"), false);
  assert.equal(TRANSITIONS.COMPLETED.size, 0);
  assert.equal(TRANSITIONS.CANCELLED.size, 0);
});