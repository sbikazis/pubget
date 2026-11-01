"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  avatarDownloadUrl,
  createAvatarPrivacySync,
  createUpdateSocialProfile,
} = require("../src/avatarPrivacy");

function snapshot(data) {
  return { exists: true, data: () => data };
}

test("making a public avatar private revokes its bearer token and clears URL", async () => {
  const metadataWrites = [];
  const userUpdates = [];
  const handler = createAvatarPrivacySync({
    db: {
      collection: () => ({
        doc: () => ({ update: async (value) => userUpdates.push(value) }),
      }),
    },
    bucket: {
      name: "demo.appspot.com",
      file: () => ({
        setMetadata: async (value) => metadataWrites.push(value),
      }),
    },
    randomUUID: () => "replacement-token",
  });

  await handler({
    params: { uid: "alice" },
    data: {
      before: snapshot({
        profileVisibility: "public",
        avatarUrl: "https://example.test/old?token=old-token",
      }),
      after: snapshot({
        profileVisibility: "private",
        avatarUrl: "https://example.test/old?token=old-token",
      }),
    },
  });

  assert.deepEqual(metadataWrites, [{
    metadata: { firebaseStorageDownloadTokens: "replacement-token" },
  }]);
  assert.deepEqual(userUpdates, [{ avatarUrl: null }]);
  assert.notEqual(
    metadataWrites[0].metadata.firebaseStorageDownloadTokens,
    "old-token",
  );
});

test("profile callable rotates the old token before making profile private", async () => {
  const order = [];
  const handler = createUpdateSocialProfile({
    db: {
      collection: () => ({
        doc: () => ({
          get: async () => snapshot({
            profileVisibility: "public",
            avatarUrl: "https://example.test/avatar?token=old",
          }),
          update: async (value) => order.push(["update", value]),
        }),
      }),
    },
    bucket: {
      file: () => ({
        setMetadata: async (value) => order.push(["metadata", value]),
      }),
    },
    randomUUID: () => "rotated",
    HttpsError: class extends Error {},
  });

  await handler({
    auth: { uid: "alice" },
    data: {
      bio: "hello",
      favoriteAnimeIds: ["1"],
      profileVisibility: "private",
      activityVisibility: "public",
    },
  });

  assert.equal(order[0][0], "metadata");
  assert.equal(order[1][0], "update");
  assert.equal(order[1][1].profileVisibility, "private");
  assert.equal(order[1][1].avatarUrl, null);
});

test("making a profile public publishes a newly rotated avatar token", async () => {
  const userUpdates = [];
  const handler = createAvatarPrivacySync({
    db: {
      collection: () => ({
        doc: () => ({ update: async (value) => userUpdates.push(value) }),
      }),
    },
    bucket: {
      name: "demo.appspot.com",
      file: () => ({
        exists: async () => [true],
        setMetadata: async () => {},
      }),
    },
    randomUUID: () => "new-token",
  });

  await handler({
    params: { uid: "alice" },
    data: {
      before: snapshot({ profileVisibility: "private", avatarUrl: null }),
      after: snapshot({ profileVisibility: "public", avatarUrl: null }),
    },
  });

  assert.deepEqual(userUpdates, [{
    avatarUrl: avatarDownloadUrl(
      "demo.appspot.com",
      "users/alice/avatar.jpg",
      "new-token",
    ),
  }]);
});

// Username validation helper reused by the callable and the client validator.
const stubRegistry = () => ({
  validateUsername: (value) => {
    const valid = /^[\p{L}][\p{L}\p{N}._-]{2,19}$/u.test(String(value || ""));
    return valid ? { valid, reason: null } : { valid, reason: "invalid-characters" };
  },
  normalizeUsername: (value) => String(value || "").trim().toLowerCase(),
});

function profileHandler({ reservations = [], releases = [], updateError = null }) {
  const updates = [];
  let updateCalls = 0;
  const handler = createUpdateSocialProfile({
    db: {
      collection: () => ({
        doc: () => ({
          get: () => snapshot({ username: "oldname" }),
          update: async (value) => {
            updateCalls++;
            updates.push(value);
            if (updateError) throw updateError;
          },
        }),
      }),
    },
    bucket: {
      file: () => ({
        setMetadata: async () => {},
        exists: async () => [false],
      }),
    },
    randomUUID: () => "token",
    HttpsError: class extends Error {
      constructor(code) {
        super(code);
        this.code = code;
      }
    },
    userNameRegistry: {
      ...stubRegistry(),
      reserve: async (uid, username) => reservations.push(username),
      release: async (uid, username) => releases.push(username),
    },
  });
  return {
    handler,
    updates,
    get updateCalls() {
      return updateCalls;
    },
  };
}

test("profile callable writes a valid language and rejects unsupported codes", async () => {
  const { handler, updates } = profileHandler({});
  await handler({ auth: { uid: "alice" }, data: { language: "ar" } });
  assert.equal(updates[0].language, "ar");

  const { handler: en } = profileHandler({});
  await en({ auth: { uid: "alice" }, data: { language: "en" } });
  await assert.rejects(
    () => en({ auth: { uid: "alice" }, data: { language: "fr" } }),
    (error) => error.code === "invalid-argument",
  );
});

test("profile callable reserves the new username and releases the old name", async () => {
  const reservations = [];
  const releases = [];
  const handler = createUpdateSocialProfile({
    db: {
      collection: () => ({
        doc: () => ({
          get: () => snapshot({ username: "oldname" }),
          update: async (value) => updates.push(value),
        }),
      }),
    },
    bucket: {
      file: () => ({
        setMetadata: async () => {},
        exists: async () => [false],
      }),
    },
    randomUUID: () => "token",
    HttpsError: class extends Error {},
    userNameRegistry: {
      ...stubRegistry(),
      reserve: async (uid, username) => reservations.push(username),
      release: async (uid, username) => releases.push(username),
    },
  });
  const updates = [];

  await handler({ auth: { uid: "alice" }, data: { username: "newname" } });
  assert.deepEqual(reservations, ["newname"]);
  assert.deepEqual(releases, ["oldname"]);
  assert.equal(updates[0].username, "newname");
});

test("profile callable backs out the reservation when the write fails", async () => {
  const reservations = [];
  const releases = [];
  const boom = new Error("firestore down");
  const { handler } = profileHandler({ reservations, releases, updateError: boom });

  await assert.rejects(() => handler({
    auth: { uid: "alice" },
    data: { username: "newname" },
  }), (error) => error === boom);
  assert.deepEqual(reservations, ["newname"]);
  assert.deepEqual(releases, ["newname"]);
});

test("profile callable rejects an out-of-spec username", async () => {
  const handler = createUpdateSocialProfile({
    db: {
      collection: () => ({
        doc: () => ({
          get: () => snapshot({ username: "oldname" }),
          update: async () => {},
        }),
      }),
    },
    bucket: {
      file: () => ({
        setMetadata: async () => {},
        exists: async () => [false],
      }),
    },
    randomUUID: () => "token",
    HttpsError: class extends Error {},
    userNameRegistry: {
      ...stubRegistry(),
      reserve: async () => {},
      release: async () => {},
    },
  });

  await assert.rejects(
    () => handler({ auth: { uid: "alice" }, data: { username: "1bad" } }),
    (error) => error instanceof Error && /invalid/i.test(String(error)),
  );
});