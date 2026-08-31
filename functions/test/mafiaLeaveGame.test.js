const test = require("node:test");
const assert = require("node:assert/strict");
const { leaveTransition, validGameId } = require("../src/mafia/leaveTransition");

test("mafia leave transition validates bounded identifiers", () => {
  assert.equal(validGameId("game-1"), true);
  assert.equal(validGameId(" "), false);
  assert.equal(validGameId("x".repeat(129)), false);
});

test("mafia leave transition decrements once and cancels undersized starts", () => {
  assert.deepEqual(
    leaveTransition("starting", { hasLeft: false }, 3, 3),
    { kind: "cancelled", nextCount: 2 },
  );
  assert.deepEqual(
    leaveTransition("night", { hasLeft: false }, 8, 3),
    { kind: "active-left" },
  );
  assert.deepEqual(
    leaveTransition("voting", { hasLeft: true }, 8, 3),
    { kind: "already-left" },
  );
});