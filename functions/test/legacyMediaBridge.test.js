"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  authorizeLegacyPath,
  createLegacyMediaResolver,
  parseLegacyObjectPath,
} = require("../src/legacyMediaBridge");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function fakeDb({ exists = true, data = {} } = {}) {
  const reads = [];
  return {
    reads,
    collection(name) {
      return {
        doc(id) {
          reads.push(`${name}/${id}`);
          const doc = {
            get: async () => ({ exists, data: () => data }),
          };
          doc.collection = (child) => ({
            doc: (childId) => {
              reads.push(`${name}/${id}/${child}/${childId}`);
              return { get: async () => ({ exists }) };
            },
          });
          return doc;
        },
      };
    },
  };
}

function fakeBucket() {
  const calls = [];
  return {
    calls,
    file(path) {
      return {
        getSignedUrl: async (options) => {
          calls.push({ path, options });
          return [`https://storage.example/signed/${encodeURIComponent(path)}`];
        },
      };
    },
  };
}

function resolver({ db = fakeDb(), bucket = fakeBucket(), now = 1_700_000_000_000 } = {}) {
  return {
    db,
    bucket,
    handler: createLegacyMediaResolver({
      db,
      bucket,
      HttpsError: TestHttpsError,
      ttlMs: 300_000,
      now: () => now,
    }),
  };
}

test("legacy path parsing decodes canonical URLs and rejects traversal", () => {
  const url = "https://firebasestorage.googleapis.com/v0/b/pubget-aaf27.firebasestorage.app/o/" +
    "groups%2Fg1%2Falice%2Fmedia%2Fm1.jpg?alt=media&token=permanent";
  assert.equal(
    parseLegacyObjectPath(url),
    "groups/g1/alice/media/m1.jpg",
  );
  assert.equal(parseLegacyObjectPath("images/alice/avatar.jpg"), "images/alice/avatar.jpg");
  assert.equal(
    parseLegacyObjectPath("https://evil.example/v0/b/b/o/users%2Falice%2Favatar.jpg"),
    null,
  );
  assert.equal(parseLegacyObjectPath("users/alice/../../secret.jpg"), null);
  assert.equal(parseLegacyObjectPath("/users/alice/avatar.jpg"), null);
  assert.equal(parseLegacyObjectPath("users/alice/avatar.jpg?token=x"), null);
  assert.equal(parseLegacyObjectPath("a".repeat(1025)), null);
});

test("conversation media requires membership", async () => {
  const denied = await authorizeLegacyPath({
    db: fakeDb({ exists: false }),
    uid: "bob",
    path: "privateChats/chat-1/alice/media/m1.jpg",
  });
  assert.equal(denied, false);

  const allowed = await authorizeLegacyPath({
    db: fakeDb({ exists: true }),
    uid: "bob",
    path: "groups/g1/alice/media/m1.jpg",
  });
  assert.equal(allowed, true);
});

test("fan works need ownership or an approved published work", async () => {
  assert.equal(await authorizeLegacyPath({
    db: null,
    uid: "alice",
    path: "fan_works/alice/w1/123_page.pdf",
  }), true);

  assert.equal(await authorizeLegacyPath({
    db: fakeDb({ data: { status: "published", moderationStatus: "approved" } }),
    uid: "bob",
    path: "fan_works/alice/w1/123_page.pdf",
  }), true);

  assert.equal(await authorizeLegacyPath({
    db: fakeDb({ data: { status: "draft", moderationStatus: "pending" } }),
    uid: "bob",
    path: "fan_works/alice/w1/123_page.pdf",
  }), false);
});

test("owner-scoped private images are not readable across users", async () => {
  assert.equal(await authorizeLegacyPath({
    db: null,
    uid: "bob",
    path: "images/alice/avatar.jpg",
  }), false);
  assert.equal(await authorizeLegacyPath({
    db: null,
    uid: "alice",
    path: "images/alice/avatar.jpg",
  }), true);
  assert.equal(await authorizeLegacyPath({
    db: null,
    uid: "bob",
    path: "reels/alice/reel.mp4",
  }), true);
});

test("resolver requires authentication and a valid path", async () => {
  const { handler } = resolver();
  await assert.rejects(
    handler({ auth: null, data: { path: "images/alice/avatar.jpg" } }),
    (error) => error.code === "unauthenticated",
  );
  await assert.rejects(
    handler({ auth: { uid: "alice" }, data: { path: "../secret" } }),
    (error) => error.code === "invalid-argument",
  );
});

test("resolver mints a short URL without a permanent token", async () => {
  const { handler, bucket } = resolver();
  const result = await handler({
    auth: { uid: "alice" },
    data: {
      path: "https://firebasestorage.googleapis.com/v0/b/pubget-aaf27.firebasestorage.app/o/" +
        "images%2Falice%2Favatar.jpg?alt=media&token=old-permanent-token",
    },
  });

  assert.equal(result.url, "https://storage.example/signed/images%2Falice%2Favatar.jpg");
  assert.ok(!result.url.includes("token="));
  assert.equal(result.expiresAt, Math.floor((1_700_000_000_000 + 300_000) / 1000));
  assert.equal(bucket.calls.length, 1);
  assert.equal(bucket.calls[0].path, "images/alice/avatar.jpg");
  assert.equal(bucket.calls[0].options.action, "read");
  assert.equal(bucket.calls[0].options.expires, 1_700_000_300_000);
});

test("resolver denies unauthorized media before touching the bucket", async () => {
  const { handler, bucket } = resolver({ db: fakeDb({ exists: false }) });
  await assert.rejects(
    handler({
      auth: { uid: "bob" },
      data: { path: "privateChats/chat-1/alice/media/m1.jpg" },
    }),
    (error) => error.code === "permission-denied",
  );
  assert.equal(bucket.calls.length, 0);
});
