"use strict";

// Multi-user Prompt 20.1 E2E against the Firebase Emulator Suite.
// Covers server-authoritative group settings, unban, and roleplay
// character reservation. This is not hosted production E2E.

const assert = require("node:assert/strict");
const test = require("node:test");

process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-pubget-security";

const admin = require("firebase-admin");
if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "demo-pubget-security" });
}

const { createGroupsDomain } = require("../src/groupsDomain");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const FieldValue = admin.firestore.FieldValue;
const db = admin.firestore();

function auth(uid) {
  return { auth: { uid } };
}

function groups() {
  return createGroupsDomain({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
    randomUUID: () => "confirm-token",
  });
}

async function seedUser(uid) {
  await db.doc(`users/${uid}`).set({ username: uid, customMaxMembersLimit: 0 });
}

async function createGroup(founder, type) {
  const domain = groups();
  const result = await domain.createGroup({
    auth: { uid: founder },
    data: {
      name: `Group ${type}`,
      description: "",
      type,
      animeId: type === "animeRoleplay" ? "anime-1" : null,
      joinPolicy: "open",
      isSearchable: true,
      rules: "",
    },
  });
  return result.groupId;
}

test.before(async () => {
  for (const uid of ["alice", "bob", "carol"]) await seedUser(uid);
});

test("group settings are updatable only by manageSettings holders", async () => {
  const domain = groups();
  const groupId = await createGroup("alice", "public");
  await domain.joinGroup({ ...auth("bob"), data: { groupId } });

  // Founder can update supported settings.
  await domain.updateGroupSettings({
    ...auth("alice"),
    data: { groupId, name: "Renamed", joinPolicy: "approval", rules: "Be kind" },
  });
  let group = (await db.doc(`groups/${groupId}`).get()).data();
  assert.equal(group.name, "Renamed");
  assert.equal(group.searchName, "renamed");
  assert.equal(group.joinPolicy, "approval");
  assert.equal(group.rules, "Be kind");

  // Plain member (no manageSettings) is rejected.
  await assert.rejects(
    domain.updateGroupSettings({
      ...auth("bob"),
      data: { groupId, name: "Hacked" },
    }),
    (error) => error.code === "permission-denied",
  );
  group = (await db.doc(`groups/${groupId}`).get()).data();
  assert.equal(group.name, "Renamed");

  // A shogun (default manageSettings holder) can update settings.
  await db.doc(`groups/${groupId}/members/bob`).update({ role: "shogun" });
  await domain.updateGroupSettings({
    ...auth("bob"),
    data: { groupId, description: "By shogun" },
  });
  group = (await db.doc(`groups/${groupId}`).get()).data();
  assert.equal(group.description, "By shogun");
});

test("unban is authorized and reversible", async () => {
  const domain = groups();
  const groupId = await createGroup("alice", "public");
  await domain.joinGroup({ ...auth("bob"), data: { groupId } });
  await domain.joinGroup({ ...auth("carol"), data: { groupId } });

  // Founder bans carol.
  await domain.banMember({ ...auth("alice"), data: { groupId, uid: "carol" } });
  assert.equal(
    (await db.doc(`groups/${groupId}/bans/carol`).get()).exists,
    true,
  );
  // Banned user cannot rejoin.
  await assert.rejects(
    domain.joinGroup({ ...auth("carol"), data: { groupId } }),
    (error) => error.code === "permission-denied",
  );

  // Unauthorized member cannot unban.
  await assert.rejects(
    domain.unbanMember({ ...auth("bob"), data: { groupId, uid: "carol" } }),
    (error) => error.code === "permission-denied",
  );
  assert.equal(
    (await db.doc(`groups/${groupId}/bans/carol`).get()).exists,
    true,
  );

  // Authorized moderator (founder) unbans; carol can rejoin.
  await domain.unbanMember({ ...auth("alice"), data: { groupId, uid: "carol" } });
  assert.equal(
    (await db.doc(`groups/${groupId}/bans/carol`).get()).exists,
    false,
  );
  await domain.joinGroup({ ...auth("carol"), data: { groupId } });
  assert.equal(
    (await db.doc(`groups/${groupId}/members/carol`).get()).exists,
    true,
  );
});

test("roleplay reservation is restricted to roleplay groups and enforces exclusivity", async () => {
  const domain = groups();
  const publicGroup = await createGroup("alice", "public");
  const rpGroup = await createGroup("alice", "openRoleplay");
  await domain.joinGroup({ ...auth("bob"), data: { groupId: rpGroup } });
  await domain.joinGroup({ ...auth("carol"), data: { groupId: rpGroup } });

  // Non-roleplay group rejects reservation.
  await assert.rejects(
    domain.reserveRoleplayCharacter({
      ...auth("alice"),
      data: {
        groupId: publicGroup,
        characterKey: "hero",
        character: { name: "The Hero" },
      },
    }),
    (error) => error.code === "failed-precondition",
  );

  // Member reserves a valid character in a roleplay group.
  await domain.reserveRoleplayCharacter({
    ...auth("bob"),
    data: { groupId: rpGroup, characterKey: "hero", character: { name: "The Hero" } },
  });
  const member = (await db.doc(`groups/${rpGroup}/members/bob`).get()).data();
  assert.equal(member.roleplayCharacter.key, "hero");
  assert.equal(member.roleplayCharacter.name, "The Hero");

  // Another member cannot take a reserved character.
  await assert.rejects(
    domain.reserveRoleplayCharacter({
      ...auth("carol"),
      data: { groupId: rpGroup, characterKey: "hero", character: { name: "The Hero" } },
    }),
    (error) => error.code === "already-exists",
  );

  // Owner releases; the character becomes available again.
  await domain.releaseRoleplayCharacter({
    ...auth("bob"),
    data: { groupId: rpGroup, characterKey: "hero" },
  });
  assert.equal(
    (await db.doc(`groups/${rpGroup}/characters/hero`).get()).exists,
    false,
  );
  await domain.reserveRoleplayCharacter({
    ...auth("carol"),
    data: { groupId: rpGroup, characterKey: "hero", character: { name: "The Hero" } },
  });
  const carol = (await db.doc(`groups/${rpGroup}/members/carol`).get()).data();
  assert.equal(carol.roleplayCharacter.key, "hero");
});
