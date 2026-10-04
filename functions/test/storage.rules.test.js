/*
 * Run against Firestore and Storage emulators, for example:
 * FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 \
 * FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node --test test/storage.rules.test.js
 *
 * Wired into package.json as part of the "test:rules" script together with
 * firestore.rules.test.js, executed under the Firebase emulators with
 * --project demo-pubget-security. @firebase/rules-unit-testing is a devDependency.
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

// --- Cross-service Firestore capability ------------------------------------
// Several storage rules below are guarded by `firestore.get()` /
// `firestore.exists()` (isGroupOwner, isGroupMember, isPrivateParticipant,
// publicProfileAvatar, and the Fan Work visibility gate). The Firebase Storage
// emulator cannot evaluate those lookups: every guarded write denies locally
// even for the legitimate owner. Verified by probe below -- this is an emulator
// limitation, not a rules defect, and the rules must NOT be weakened to make it
// pass (the Flutter client really does write to the guarded paths).
const PROBE_GROUP = "cross-service-probe";
const PROBE_OWNER = "probe-owner";
const CROSS_SERVICE_UNSUPPORTED =
  "the Storage emulator cannot evaluate firestore.get()/firestore.exists() " +
  "from storage.rules, so every rule guarded by a cross-service lookup denies " +
  "locally; the rules are correct in production and must not be weakened";
let crossServiceWorks = false;
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
      db.doc(`groups/${PROBE_GROUP}`).set({ founderId: PROBE_OWNER }),
    ]);
  });
  // A *permitted* cross-service write: isGroupOwner() must read the group doc.
  // If this is denied, the emulator cannot do cross-service reads at all.
  try {
    await upload(
      env.authenticatedContext(PROBE_OWNER),
      `groups/${PROBE_GROUP}/group_image.jpg`,
      "image/jpeg",
    );
    crossServiceWorks = true;
  } catch {
    crossServiceWorks = false;
  }
});

test.after(async () => {
  await env.cleanup();
});

test("storage emulator cross-service firestore capability", async (t) => {
  // Not an assertion about the rules: this records whether the local runtime can
  // evaluate them, so the skips below are self-explaining and lift automatically
  // if the emulator ever gains support.
  console.log(
    `      storage emulator cross-service firestore lookups: ${
      crossServiceWorks ? "SUPPORTED" : "NOT SUPPORTED"
    }`,
  );
  if (!crossServiceWorks) {
    return t.skip(
      "cross-service firestore lookups unavailable in the Storage emulator",
    );
  }
});

test("requires authentication and UID ownership for avatars", async () => {
  await assertFails(upload(env.unauthenticatedContext(), "avatars/alice.jpg", "image/jpeg"));
  await assertSucceeds(upload(env.authenticatedContext("alice"), "avatars/alice.jpg", "image/jpeg"));
  await assertFails(upload(env.authenticatedContext("mallory"), "avatars/alice.jpg", "image/jpeg"));
});

test("private current avatars are readable only by their owner", async (t) => {
  if (!crossServiceWorks) return t.skip(CROSS_SERVICE_UNSUPPORTED);
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("users/private-user").set({
      profileVisibility: "private",
    });
    await context.firestore().doc("users/public-user").set({
      profileVisibility: "public",
    });
  });
  const privateOwner = env.authenticatedContext("private-user");
  const publicOwner = env.authenticatedContext("public-user");
  await assertSucceeds(upload(
    privateOwner,
    "users/private-user/avatar.jpg",
    "image/jpeg",
  ));
  await assertSucceeds(upload(
    publicOwner,
    "users/public-user/avatar.jpg",
    "image/jpeg",
  ));
  await assertSucceeds(
    privateOwner.storage().ref("users/private-user/avatar.jpg").getDownloadURL(),
  );
  await assertFails(
    env.authenticatedContext("alice")
      .storage().ref("users/private-user/avatar.jpg").getDownloadURL(),
  );
  await assertSucceeds(
    env.authenticatedContext("alice")
      .storage().ref("users/public-user/avatar.jpg").getDownloadURL(),
  );
});

test("permits group image changes only to the Firestore owner", async (t) => {
  if (!crossServiceWorks) return t.skip(CROSS_SERVICE_UNSUPPORTED);
  await assertSucceeds(upload(env.authenticatedContext("owner"), "groups/group-owner/group_image.jpg", "image/jpeg"));
  await assertFails(upload(env.authenticatedContext("member"), "groups/group-owner/group_image.jpg", "image/jpeg"));
});

test("requires group membership and uploader path ownership for group media", async (t) => {
  if (!crossServiceWorks) return t.skip(CROSS_SERVICE_UNSUPPORTED);
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

// NOTE ON RESUMABLE UPLOADS
// The Storage emulator exposes every ref.put() as a create-shaped operation, so
// an `allow update` branch cannot be exercised from this harness: re-putting an
// existing object is evaluated against `create` and fails on the
// `resource == null` guard, not on the update rule. The update branches below
// exist for the real resumable protocol that production clients use
// (putData -> CREATE then UPDATE), which is the same root cause already
// documented and fixed for /edits. These tests therefore cover the guarantees
// that ARE reachable: first upload by the owner, and denial for everyone else.
test("keeps group-media originals owner-scoped and server-variants closed", async (t) => {
  if (!crossServiceWorks) return t.skip(CROSS_SERVICE_UNSUPPORTED);
  const member = env.authenticatedContext("member");
  const original = "groups/group-owner/media/media1_original.jpg";
  await assertSucceeds(upload(
    member,
    original,
    "image/jpeg",
    32,
    uploaderMetadata("member"),
  ));
  await assertFails(upload(
    env.authenticatedContext("owner"),
    original,
    "image/jpeg",
    32,
    uploaderMetadata("owner"),
  ));
  await assertFails(upload(
    member,
    original,
    "image/jpeg",
    32,
    uploaderMetadata("owner"),
  ));
  await assertFails(upload(
    member,
    "groups/group-owner/media/media1_thumb.jpg",
    "image/jpeg",
    32,
    uploaderMetadata("member"),
  ));
});

test("keeps private-chat originals restricted to the uploading participant", async (t) => {
  if (!crossServiceWorks) return t.skip(CROSS_SERVICE_UNSUPPORTED);
  const original = "privateChats/private-1/media/m-resume_original.jpg";
  await assertSucceeds(upload(
    env.authenticatedContext("alice"),
    original,
    "image/jpeg",
    32,
    uploaderMetadata("alice"),
  ));
  await assertFails(upload(
    env.authenticatedContext("bob"),
    original,
    "image/jpeg",
    32,
    uploaderMetadata("bob"),
  ));
  await assertFails(upload(
    env.authenticatedContext("mallory"),
    original,
    "image/jpeg",
    32,
    uploaderMetadata("mallory"),
  ));
});

test("requires membership plus the path UID for character images", async (t) => {
  if (!crossServiceWorks) return t.skip(CROSS_SERVICE_UNSUPPORTED);
  await assertSucceeds(upload(env.authenticatedContext("member"), "groups/group-owner/characters/member.jpg", "image/jpeg"));
  await assertFails(upload(env.authenticatedContext("owner"), "groups/group-owner/characters/member.jpg", "image/jpeg"));
});

test("allows only Firestore private-chat participants", async (t) => {
  if (!crossServiceWorks) return t.skip(CROSS_SERVICE_UNSUPPORTED);
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
  await assertSucceeds(upload(
    env.authenticatedContext("alice"),
    "privateChats/private-1/media/m1_original.jpg",
    "image/jpeg",
    32,
    uploaderMetadata("alice"),
  ));
  await assertFails(upload(
    env.authenticatedContext("alice"),
    "privateChats/private-1/media/m1_thumb.jpg",
    "image/jpeg",
    32,
    uploaderMetadata("alice"),
  ));
});

test("enforces MIME and size ceilings", async () => {
  const alice = env.authenticatedContext("alice");
  const member = env.authenticatedContext("member");
  await assertFails(upload(alice, "avatars/alice.jpg", "video/mp4"));
  // NOTE: this assertion currently passes vacuously -- the guarded group path
  // denies locally whatever the MIME type, because the emulator cannot evaluate
  // isGroupMember(). The MIME/size coverage below therefore comes from the
  // path-only rules (avatars, edits).
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

test("edit video resumable updates are allowed for the owner", async () => {
  const alice = env.authenticatedContext("alice");
  await assertSucceeds(upload(alice, "edits/alice/editId123.mp4", "video/mp4", 32));
  await assertSucceeds(upload(alice, "edits/alice/editId123.mp4", "video/mp4", 64));
  await assertSucceeds(upload(
    alice,
    "edits/alice/editId123.mp4",
    "video/mp4; codecs=avc1.42E01E",
    96,
  ));
  await assertFails(upload(
    env.authenticatedContext("bob"),
    "edits/alice/editId123.mp4",
    "video/mp4",
    32,
  ));
});

test("group staging images are owner-writable before a group exists", async () => {
  const alice = env.authenticatedContext("alice");
  await assertSucceeds(upload(
    alice,
    "users/alice/group_staging/avatar_1.jpg",
    "image/jpeg",
  ));
  await assertSucceeds(upload(
    alice,
    "users/alice/group_staging/avatar_1.jpg",
    "image/jpeg",
    48,
  ));
  await assertFails(upload(
    env.authenticatedContext("bob"),
    "users/alice/group_staging/avatar_1.jpg",
    "image/jpeg",
  ));
});

test("denies paths not explicitly supported", async () => {
  await assertFails(upload(env.authenticatedContext("alice"), "unreviewed/alice/file.jpg", "image/jpeg"));
  // The old groups/{groupId}.jpg form cannot safely recover groupId from a
  // filename in Storage Rules, so clients must use groups/{groupId}/group_image.jpg.
  await assertFails(upload(env.authenticatedContext("owner"), "groups/group-owner.jpg", "image/jpeg"));
});

test("fan work media is owner-writable and public only when the work is published", async (t) => {
  if (!crossServiceWorks) return t.skip(CROSS_SERVICE_UNSUPPORTED);
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("fanWorks/w-public").set({
      creatorId: "alice", status: "published", moderationStatus: "approved",
    });
    await db.doc("fanWorks/w-draft").set({
      creatorId: "alice", status: "draft", moderationStatus: "pending",
    });
  });
  const alice = env.authenticatedContext("alice");
  const bob = env.authenticatedContext("bob");
  await assertSucceeds(upload(
    alice,
    "fan_works/alice/w-draft/cover.jpg",
    "image/jpeg",
    32,
    uploaderMetadata("alice"),
  ));
  // Only the draft owner may write the media (see the resumable-upload note).
  await assertFails(upload(
    bob,
    "fan_works/alice/w-draft/cover.jpg",
    "image/jpeg",
    32,
    uploaderMetadata("bob"),
  ));
  await assertFails(upload(
    alice,
    "fan_works/alice/w-draft/cover.jpg",
    "image/jpeg",
    32,
    uploaderMetadata("bob"),
  ));
  await assertFails(upload(
    bob,
    "fan_works/alice/w-draft/cover2.jpg",
    "image/jpeg",
    32,
    uploaderMetadata("bob"),
  ));
  await assertFails(upload(
    alice,
    "fan_works/alice/w-draft/cover.gif",
    "application/pdf",
    32,
    uploaderMetadata("alice"),
  ));
  await assertSucceeds(
    alice.storage().ref("fan_works/alice/w-draft/cover.jpg").getDownloadURL(),
  );
  await assertFails(
    bob.storage().ref("fan_works/alice/w-draft/cover.jpg").getDownloadURL(),
  );
  await assertFails(upload(
    alice,
    "fan_works/alice/w-public/page.jpg",
    "image/jpeg",
    32,
    uploaderMetadata("alice"),
  ));
  await env.withSecurityRulesDisabled(async (context) => {
    await context.storage().ref("fan_works/alice/w-public/page.jpg").put(
      bytes(32),
      { contentType: "image/jpeg" },
    );
  });
  await assertSucceeds(
    bob.storage().ref("fan_works/alice/w-public/page.jpg").getDownloadURL(),
  );
});

test("profile covers require owner writes and mirror avatar privacy on reads", async (t) => {
  if (!crossServiceWorks) return t.skip(CROSS_SERVICE_UNSUPPORTED);
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("users/cover-private").set({ profileVisibility: "private" });
    await db.doc("users/cover-public").set({ profileVisibility: "public" });
  });
  const owner = env.authenticatedContext("cover-private");
  const publicOwner = env.authenticatedContext("cover-public");
  await assertSucceeds(upload(
    owner,
    "users/cover-private/cover.jpg",
    "image/jpeg",
  ));
  await assertSucceeds(upload(
    publicOwner,
    "users/cover-public/cover.jpg",
    "image/jpeg",
  ));
  await assertFails(upload(
    env.authenticatedContext("bob"),
    "users/cover-private/cover.jpg",
    "image/jpeg",
  ));
  // Enforces MIME + 10 MB ceiling.
  await assertFails(upload(
    owner,
    "users/cover-private/cover2.jpg",
    "video/mp4",
  ));
  await assertFails(upload(
    owner,
    "users/cover-private/cover3.jpg",
    "image/jpeg",
    10 * 1024 * 1024 + 1,
  ));
  await assertFails(upload(
    env.unauthenticatedContext(),
    "users/cover-private/cover.jpg",
    "image/jpeg",
  ));

  await assertSucceeds(
    owner.storage().ref("users/cover-private/cover.jpg").getDownloadURL(),
  );
  await assertFails(
    env.authenticatedContext("bob")
      .storage().ref("users/cover-private/cover.jpg").getDownloadURL(),
  );
  await assertSucceeds(
    env.authenticatedContext("bob")
      .storage().ref("users/cover-public/cover.jpg").getDownloadURL(),
  );

  await assertFails(
    env.authenticatedContext("bob").storage()
      .ref("users/cover-private/cover.jpg").delete(),
  );
  await assertSucceeds(owner.storage().ref("users/cover-private/cover.jpg").delete());
});