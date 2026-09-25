const test = require("node:test");
const assert = require("node:assert/strict");
const {
  leaveTransition,
  validGameId,
  activeLeavePlayerUpdate,
  waitingLeavePlayerUpdate,
} = require("../src/mafia/leaveTransition");

test("mafia leave transition validates bounded identifiers", () => {
  assert.equal(validGameId("game-1"), true);
  assert.equal(validGameId(" "), false);
  assert.equal(validGameId("x".repeat(129)), false);
});

test("mafia leave transition decrements once and cancels undersized lobbies", () => {
  // Master Spec 13.2: the waiting room can be left, and dropping under the
  // 7-player minimum closes the lobby instead of starting it short.
  assert.deepEqual(
    leaveTransition("STARTING", { hasLeft: false }, 7, 7),
    { kind: "cancelled", nextCount: 6 },
  );
  assert.deepEqual(
    leaveTransition("STARTING", { hasLeft: false }, 9, 7),
    { kind: "waiting-left", nextCount: 8 },
  );
  assert.deepEqual(
    leaveTransition("WAITING", { hasLeft: false }, 10, 7),
    { kind: "waiting-left", nextCount: 9 },
  );
  assert.deepEqual(
    leaveTransition("WAITING", { hasLeft: false }, 7, 7),
    { kind: "cancelled", nextCount: 6 },
  );
  assert.deepEqual(
    leaveTransition("NIGHT", { hasLeft: false }, 8, 7),
    { kind: "active-left" },
  );
  assert.deepEqual(
    leaveTransition("VOTING", { hasLeft: true }, 8, 7),
    { kind: "already-left" },
  );
  assert.deepEqual(
    leaveTransition("GAME_OVER", { hasLeft: false }, 6, 4),
    { kind: "unsupported" },
  );
  assert.deepEqual(
    leaveTransition("CANCELLED", { hasLeft: false }, 6, 4),
    { kind: "unsupported" },
  );
});

test("active leave eliminates the player and reveals the role", () => {
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
  // Master Spec 13.7: elimination reveals the role; 13.8 says an explicit
  // leave is the same elimination with a different cause. The role value
  // itself is never written here — it comes from the private subcollection on
  // the server, so this patch cannot leak anyone\'s role.
  assert.equal(patch.revealedRole, true);
  assert.equal(patch.eliminatedBy, "leave");
  assert.equal(patch.canSayLastWords, true);
  assert.equal(patch.role, undefined);
});

test("leaving a waiting lobby is not an elimination", () => {
  const patch = waitingLeavePlayerUpdate({
    serverTimestamp: () => "now",
  });
  assert.equal(patch.hasLeft, true);
  assert.equal(patch.isAlive, false);
  assert.equal(patch.revealedRole, undefined, "no roles exist before the start");
  assert.equal(patch.eliminatedBy, undefined);
  assert.equal(patch.isDisconnected, false, "leaving is not a disconnect");
  assert.equal(patch.leftAt, "now");
});