"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  avatarDownloadUrl,
  createAvatarPrivacySync,
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