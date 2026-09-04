"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  ROLE_PERMISSIONS,
  createGroupsDomain,
  entitledMaxMembers,
  inviteRankForCount,
} = require("../src/groupsDomain");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function handlers() {
  return createGroupsDomain({
    db: {},
    FieldValue: {},
    HttpsError: TestHttpsError,
    randomUUID: () => "id",
  });
}

test("group callables reject unauthenticated requests before database access", async () => {
  await assert.rejects(
    handlers().createGroup({ data: {} }),
    (error) => error.code === "unauthenticated",
  );
  await assert.rejects(
    handlers().leaveGroup({ data: { groupId: "g1" } }),
    (error) => error.code === "unauthenticated",
  );
});

test("anime roleplay requires a trusted anime identifier", async () => {
  await assert.rejects(
    handlers().createGroup({
      auth: { uid: "alice" },
      data: {
        name: "Roleplay",
        description: "",
        type: "animeRoleplay",
        animeId: null,
        joinPolicy: "open",
        isSearchable: true,
        rules: "",
        maxMembers: 100,
      },
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("invite ranks are delta-based thresholds", () => {
  assert.equal(inviteRankForCount(0), "member");
  assert.equal(inviteRankForCount(5), "senpai");
  assert.equal(inviteRankForCount(20), "sensei");
  assert.equal(inviteRankForCount(50), "captain");
});

test("founder permissions include all sensitive group actions", () => {
  assert.ok(ROLE_PERMISSIONS.founder.includes("manageMembers"));
  assert.ok(ROLE_PERMISSIONS.founder.includes("manageRoles"));
  assert.ok(ROLE_PERMISSIONS.founder.includes("manageSettings"));
  assert.deepEqual(ROLE_PERMISSIONS.member, []);
});

test("group capacity is server-entitled, not client-chosen", () => {
  assert.equal(entitledMaxMembers({}), 100);
  assert.equal(entitledMaxMembers({ customMaxMembersLimit: 0 }), 100);
  assert.equal(entitledMaxMembers({ customMaxMembersLimit: 350 }), 350);
  assert.equal(entitledMaxMembers({ customMaxMembersLimit: 999 }), 500);
  assert.equal(entitledMaxMembers({ customMaxMembersLimit: -4 }), 100);
});

test("group settings, unban, and roleplay callables authenticate first", async () => {
  await assert.rejects(
    handlers().updateGroupSettings({ data: { groupId: "g1", name: "x" } }),
    (error) => error.code === "unauthenticated",
  );
  await assert.rejects(
    handlers().unbanMember({ data: { groupId: "g1", uid: "u2" } }),
    (error) => error.code === "unauthenticated",
  );
  await assert.rejects(
    handlers().reserveRoleplayCharacter({ data: { groupId: "g1" } }),
    (error) => error.code === "unauthenticated",
  );
});

test("group settings validation runs before any database access", async () => {
  await assert.rejects(
    handlers().updateGroupSettings({
      auth: { uid: "alice" },
      data: { groupId: "g1" },
    }),
    (error) => error.code === "invalid-argument",
  );
  await assert.rejects(
    handlers().updateGroupSettings({
      auth: { uid: "alice" },
      data: { groupId: "g1", joinPolicy: "bogus" },
    }),
    (error) => error.code === "invalid-argument",
  );
  await assert.rejects(
    handlers().updateGroupSettings({
      auth: { uid: "alice" },
      data: { groupId: "g1", isSearchable: "yes" },
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("roleplay reservation rejects characters outside the fixed catalog", async () => {
  await assert.rejects(
    handlers().reserveRoleplayCharacter({
      auth: { uid: "alice" },
      data: {
        groupId: "g1",
        characterKey: "hero",
        character: { name: "Not The Hero" },
      },
    }),
    (error) => error.code === "invalid-argument",
  );
});