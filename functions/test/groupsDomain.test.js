"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  ROLE_PERMISSIONS,
  createGroupsDomain,
  entitledMaxMembers,
  normalizeRole,
} = require("../src/groupsDomain");
const { computeAutoSeatAssignments } = require("../src/pubgetRanks");

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

test("auto seats replace legacy invite thresholds", () => {
  assert.equal(normalizeRole("member"), "ronin");
  assert.equal(normalizeRole("senpai"), "gokenin");
  const now = Date.now();
  const day = 24 * 60 * 60 * 1000;
  const result = computeAutoSeatAssignments([
    { uid: "owner", role: "mikado", isManualRole: true, joinedAt: now - day * 10 },
    { uid: "inviter", role: "ronin", joinedAt: now - day * 10 },
    { uid: "a", role: "ronin", invitedBy: "inviter", joinedAt: now - day * 2 },
  ], new Set(), now);
  assert.equal(result.assignments.inviter, "daimyo");
});

test("mikado permissions include all sensitive group actions", () => {
  assert.ok(ROLE_PERMISSIONS.mikado.includes("kickBan"));
  assert.ok(ROLE_PERMISSIONS.mikado.includes("manageRoles"));
  assert.ok(ROLE_PERMISSIONS.mikado.includes("manageSettings"));
  assert.deepEqual(ROLE_PERMISSIONS.ronin, []);
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

test("roleplay reservation rejects incomplete character payloads", async () => {
  await assert.rejects(
    handlers().reserveRoleplayCharacter({
      auth: { uid: "alice" },
      data: {
        groupId: "g1",
        characterKey: "hero",
        character: { name: "" },
      },
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("public groups reject a founder character payload", async () => {
  await assert.rejects(
    handlers().createGroup({
      auth: { uid: "alice" },
      data: {
        name: "Public",
        description: "",
        type: "public",
        joinPolicy: "approval",
        isSearchable: true,
        rules: "",
        characterKey: "hero",
        character: { name: "The Hero", avatarUrl: "" },
      },
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("anime roleplay create requires a founder character", async () => {
  await assert.rejects(
    handlers().createGroup({
      auth: { uid: "alice" },
      data: {
        name: "Roleplay",
        description: "",
        type: "animeRoleplay",
        animeId: "52991",
        joinPolicy: "approval",
        isSearchable: true,
        rules: "",
      },
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("createGroup rejects local file paths as image URLs", async () => {
  await assert.rejects(
    handlers().createGroup({
      auth: { uid: "alice" },
      data: {
        name: "Crew",
        description: "",
        type: "public",
        joinPolicy: "open",
        isSearchable: true,
        rules: "",
        imageUrl: "/data/user/0/cache/x.jpg",
      },
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("promoteGroup authenticates first", async () => {
  await assert.rejects(
    handlers().promoteGroup({ data: { groupId: "g1" } }),
    (error) => error.code === "unauthenticated",
  );
});

test("promoteGroup is founder-only, server-priced, and debits coins", async () => {
  const store = {
    "groups/g1": { founderId: "alice", isPromoted: false },
    "users/alice": { coinsBalance: 200 },
  };
  function refFor(path) {
    const id = path.split("/").pop();
    return {
      id,
      path,
      collection(name) {
        return {
          doc(docId) {
            const next = docId || `auto-${Object.keys(store).length}`;
            return refFor(`${path}/${name}/${next}`);
          },
        };
      },
    };
  }
  const db = {
    collection(name) {
      return { doc: (id) => refFor(`${name}/${id}`) };
    },
    runTransaction: async (fn) => fn({
      get: async (ref) => ({
        exists: Object.prototype.hasOwnProperty.call(store, ref.path),
        data: () => store[ref.path],
      }),
      update: (ref, data) => {
        store[ref.path] = Object.assign({}, store[ref.path], data);
      },
      create: (ref, data) => {
        store[ref.path] = data;
      },
    }),
  };
  const domain = createGroupsDomain({
    db,
    FieldValue: { serverTimestamp: () => "SERVER_TIMESTAMP" },
    HttpsError: TestHttpsError,
    randomUUID: () => "id",
  });
  const result = await domain.promoteGroup({
    auth: { uid: "alice" },
    data: { groupId: "g1" },
  });
  assert.equal(result.ok, true);
  assert.equal(result.cost, 120);
  assert.equal(result.days, 7);
  assert.equal(store["users/alice"].coinsBalance, 80);
  assert.equal(store["groups/g1"].isPromoted, true);
  assert.ok(store["groups/g1"].promotionExpiresAt instanceof Date);

  await assert.rejects(
    domain.promoteGroup({
      auth: { uid: "mallory" },
      data: { groupId: "g1" },
    }),
    (error) => error.code === "permission-denied",
  );

  store["users/alice"].coinsBalance = 10;
  await assert.rejects(
    domain.promoteGroup({
      auth: { uid: "alice" },
      data: { groupId: "g1" },
    }),
    (error) => error.code === "failed-precondition",
  );
});