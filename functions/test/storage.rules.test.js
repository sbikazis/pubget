/*
 * Run against Firestore and Storage emulators, for example:
 * FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 \
 * FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node --test test/storage.rules.test.js
 *
 * This test intentionally is not wired into package.json: the application
 * package does not currently include @firebase/rules-unit-testing. Install it
 * as a development dependency in CI before running this file.
 */
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const projectId = "demo-pubget-security";
const rules = fs.readFileSync(path.join(__dirname, "../../storage.rules"), "utf8");
let env;

const bytes = (size) => new Uint8Array(size);
const upload = (context, objectPath, contentType, size = 32, metadata = {}) =>
  context.storage().ref(objectPath).put(bytes(size), {
    contentType,
    customMetadata: metadata,
  });
const uploaderMetadata = (uid) => ({ uploadedBy: uid });

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: { host: "127.0.0.1", port: 8080 },
    storage: { host: "127.0.0.1", port: 9199, rules },
  });
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      db.doc("groups/group-owner").set({ founderId: "owner" }),
      db.doc("groups/group-owner/members/owner").set({ userId: "owner" }),
      db.doc("groups/group-owner/members/member").set({ userId: "member" }),
      db.doc("privateChats/private-1").set({ userA: "alice", userB: "bob" }),
    ]);
  });
});

test.after(async () => {
  await env.cleanup();
});

test("requires authentication and UID ownership for avatars", async () => {
  await assertFails(upload(env.unauthenticatedContext(), "avatars/alice.jpg", "image/jpeg"));
  await assertSucceeds(upload(env.authenticatedContext("alice"), "avatars/alice.jpg", "image/jpeg"));
  await assertFails(upload(env.authenticatedContext("mallory"), "avatars/alice.jpg", "image/jpeg"));
});

test("permits group image changes only to the Firestore owner", async () => {
  await assertSucceeds(upload(env.authenticatedContext("owner"), "groups/group-owner/group_image.jpg", "image/jpeg"));
  await assertFails(upload(env.authenticatedContext("member"), "groups/group-owner/group_image.jpg", "image/jpeg"));
});

test("requires group membership and uploader path ownership for group media", async () => {
  const media = "groups/group-owner/chat/member/message";
  await assertSucceeds(upload(env.authenticatedContext("member"), media, "audio/mp4", 32, uploaderMetadata("member")));
  await assertFails(upload(env.authenticatedContext("outsider"), media, "audio/mp4", 32, uploaderMetadata("outsider")));
  await assertFails(upload(env.authenticatedContext("owner"), media, "audio/mp4", 32, uploaderMetadata("owner")));
  await assertFails(upload(
    env.authenticatedContext("member"),
    "groups/group-owner/chat/message.jpg",
    "audio/mp4",
    32,
    uploaderMetadata("member"),
  ));
});

test("requires membership plus the path UID for character images", async () => {
  await assertSucceeds(upload(env.authenticatedContext("member"), "groups/group-owner/characters/member.jpg", "image/jpeg"));
  await assertFails(upload(env.authenticatedContext("owner"), "groups/group-owner/characters/member.jpg", "image/jpeg"));
});

test("allows only Firestore private-chat participants", async () => {
  await assertSucceeds(upload(
    env.authenticatedContext("alice"),
    "private_chats/private-1/alice/message",
    "image/jpeg",
    32,
    uploaderMetadata("alice"),
  ));
  await assertFails(upload(
    env.authenticatedContext("mallory"),
    "private_chats/private-1/mallory/other",
    "image/jpeg",
    32,
    uploaderMetadata("mallory"),
  ));
});

test("enforces MIME and size ceilings", async () => {
  const alice = env.authenticatedContext("alice");
  const member = env.authenticatedContext("member");
  await assertFails(upload(alice, "avatars/alice.jpg", "video/mp4"));
  await assertFails(upload(
    member,
    "groups/group-owner/chat/bad.jpg",
    "application/pdf",
    32,
    uploaderMetadata("member"),
  ));
  await assertFails(upload(
    alice,
    "edits/alice/v_too-large.mp4",
    "video/mp4",
    250 * 1024 * 1024 + 1,
  ));
  await assertSucceeds(upload(alice, "edits/alice/v_ok.mp4", "video/mp4", 32));
});

test("denies paths not explicitly supported", async () => {
  await assertFails(upload(env.authenticatedContext("alice"), "unreviewed/alice/file.jpg", "image/jpeg"));
  // The old groups/{groupId}.jpg form cannot safely recover groupId from a
  // filename in Storage Rules, so clients must use groups/{groupId}/group_image.jpg.
  await assertFails(upload(env.authenticatedContext("owner"), "groups/group-owner.jpg", "image/jpeg"));
});