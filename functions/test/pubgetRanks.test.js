"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  computeAutoSeatAssignments,
  canAssignRole,
  normalizeRole,
  ROLE_PERMISSIONS,
  hasPermission,
  manualSeatsRemaining,
} = require("../src/pubgetRanks");

const DAY = 24 * 60 * 60 * 1000;
const now = Date.UTC(2026, 8, 10);

function member(uid, extras) {
  return Object.assign({
    uid,
    role: "ronin",
    invitedBy: null,
    joinedAt: now - 2 * DAY,
    isManualRole: false,
  }, extras || {});
}

test("legacy roles normalize to mikado edition", () => {
  assert.equal(normalizeRole("founder"), "mikado");
  assert.equal(normalizeRole("commander"), "daimyo");
  assert.equal(normalizeRole("captain"), "hatamoto");
  assert.equal(normalizeRole("sensei"), "samurai");
  assert.equal(normalizeRole("senpai"), "gokenin");
  assert.equal(normalizeRole("member"), "ronin");
  assert.equal(normalizeRole(null), "ronin");
  assert.equal(normalizeRole("garbage"), "ronin");
});

test("mikado permissions include manageRoles and kickBan", () => {
  assert.ok(ROLE_PERMISSIONS.mikado.includes("manageRoles"));
  assert.ok(ROLE_PERMISSIONS.mikado.includes("kickBan"));
  assert.ok(ROLE_PERMISSIONS.shogun.includes("unban"));
  assert.ok(!ROLE_PERMISSIONS.daimyo.includes("unban"));
  assert.ok(!ROLE_PERMISSIONS.hatamoto.includes("kickBan"));
  assert.deepEqual(ROLE_PERMISSIONS.ronin, []);
});

test("assignment ceiling: mikado up to shogun, shogun up to daimyo", () => {
  assert.equal(canAssignRole("mikado", "ronin", "shogun"), true);
  assert.equal(canAssignRole("mikado", "ronin", "mikado"), false);
  assert.equal(canAssignRole("shogun", "ronin", "daimyo"), true);
  assert.equal(canAssignRole("shogun", "ronin", "shogun"), false);
  assert.equal(canAssignRole("daimyo", "ronin", "gokenin"), false);
});

test("zero invites never fill auto seats", () => {
  const members = [
    member("m1"),
    member("m2"),
    member("owner", { role: "mikado", isManualRole: true }),
  ];
  const result = computeAutoSeatAssignments(members, new Set(), now);
  assert.equal(Object.keys(result.assignments).length, 0);
  assert.equal(result.vacantAuto.daimyo, true);
  assert.equal(result.vacantAuto.gokenin, true);
});

test("top inviter takes highest auto seat only", () => {
  const members = [
    member("owner", { role: "mikado", isManualRole: true }),
    member("a", { joinedAt: now - 10 * DAY }),
    member("b", { joinedAt: now - 9 * DAY }),
    member("c1", { invitedBy: "a", joinedAt: now - 3 * DAY }),
    member("c2", { invitedBy: "a", joinedAt: now - 3 * DAY }),
    member("c3", { invitedBy: "b", joinedAt: now - 3 * DAY }),
  ];
  const result = computeAutoSeatAssignments(members, new Set(), now);
  assert.equal(result.effectiveInvites.a, 2);
  assert.equal(result.effectiveInvites.b, 1);
  assert.equal(result.assignments.a, "daimyo");
  assert.equal(result.assignments.b, "hatamoto");
  assert.equal(result.vacantAuto.daimyo, false);
});

test("invites younger than 24h do not count", () => {
  const members = [
    member("owner", { role: "mikado", isManualRole: true }),
    member("a", { joinedAt: now - 10 * DAY }),
    member("fresh", { invitedBy: "a", joinedAt: now - 60 * 60 * 1000 }),
  ];
  const result = computeAutoSeatAssignments(members, new Set(), now);
  assert.equal(result.effectiveInvites.a, 0);
  assert.equal(Object.keys(result.assignments).length, 0);
});

test("tie-break prefers earlier joinedAt then smaller uid", () => {
  const members = [
    member("owner", { role: "mikado", isManualRole: true }),
    member("b", { joinedAt: now - 5 * DAY }),
    member("a", { joinedAt: now - 5 * DAY }),
    member("x1", { invitedBy: "a", joinedAt: now - 2 * DAY }),
    member("x2", { invitedBy: "b", joinedAt: now - 2 * DAY }),
  ];
  const result = computeAutoSeatAssignments(members, new Set(), now);
  assert.equal(result.effectiveInvites.a, 1);
  assert.equal(result.effectiveInvites.b, 1);
  assert.equal(result.assignments.a, "daimyo");
});

test("banned invitees do not count toward effective invites", () => {
  const members = [
    member("owner", { role: "mikado", isManualRole: true }),
    member("a"),
    member("banned", { invitedBy: "a", joinedAt: now - 3 * DAY }),
  ];
  const result = computeAutoSeatAssignments(
    members,
    new Set(["banned"]),
    now,
  );
  assert.equal(result.effectiveInvites.a, 0);
});

test("manual seat remaining math", () => {
  assert.equal(manualSeatsRemaining("daimyo", 0), 2);
  assert.equal(manualSeatsRemaining("daimyo", 2), 0);
  assert.equal(manualSeatsRemaining("shogun", 1), 0);
});

test("hasPermission respects mikado apex and aliases", () => {
  assert.equal(
    hasPermission({ role: "mikado" }, { permissions: [] }, "kickBan", {}),
    true,
  );
  assert.equal(
    hasPermission(
      { role: "hatamoto" },
      { permissions: ["manageMembers"] },
      "kickBan",
      {},
    ),
    true,
  );
  assert.equal(
    hasPermission(
      { role: "gokenin" },
      { permissions: ["invite"] },
      "kickBan",
      {},
    ),
    false,
  );
});
