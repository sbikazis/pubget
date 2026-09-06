const test = require("node:test");
const assert = require("node:assert/strict");
const {
  leaveTransition,
  validGameId,
  activeLeavePlayerUpdate,
} = require("../src/mafia/leaveTransition");

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
    leaveTransition("starting", { hasLeft: false }, 5, 4),
    { kind: "starting-left", nextCount: 4 },
  );
  assert.deepEqual(
    leaveTransition("night", { hasLeft: false }, 8, 3),
    { kind: "active-left" },
  );
  assert.deepEqual(
    leaveTransition("voting", { hasLeft: true }, 8, 3),
    { kind: "already-left" },
  );
  assert.deepEqual(
    leaveTransition("waiting", { hasLeft: false }, 3, 4),
    { kind: "unsupported" },
  );
  assert.deepEqual(
    leaveTransition("execution", { hasLeft: false }, 6, 4),
    { kind: "unsupported" },
  );
});

test("active leave marks the player eliminated without reassigning roles", () => {
  const patch = activeLeavePlayerUpdate({
    serverTimestamp: () => "now",
  });
  assert.equal(patch.hasLeft, true);
  assert.equal(patch.isAlive, false);
  assert.equal(patch.canVote, false);
  assert.equal(patch.canSpeak, false);
  assert.equal(patch.canUseAbility, false);
  assert.equal(patch.isDisconnected, true);
  assert.equal(patch.leftAt, "now");
  assert.equal(patch.role, undefined);
});