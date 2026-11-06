"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  createSocialGraph,
  legacyPairId,
  legacyRespectId,
  matchesLegacyFriendship,
  matchesLegacyRespect,
  pairId,
  respectId,
  validUid,
} = require("../src/socialGraph");
const {
  DISPLAY_FIELDS,
  buildPublicProfile,
  shouldPublishProfile,
} = require("../src/publicProfile");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function clone(value) {
  if (value === null || typeof value !== "object") return value;
  if (Array.isArray(value)) return value.map(clone);
  const next = {};
  for (const [key, item] of Object.entries(value)) next[key] = clone(item);
  return next;
}

function createFakeDb(seed = {}) {
  const store = new Map(Object.entries(clone(seed)));
  const collectionFor = (base) => ({
    doc(id) {
      const path = `${base}/${id}`;
      return {
        path,
        id,
        collection(name) {
          return collectionFor(`${path}/${name}`);
        },
      };
    },
  });
  return {
    store,
    collection(name) {
      return collectionFor(name);
    },
    async runTransaction(callback) {
      const transaction = {
        async get(ref) {
          const data = store.get(ref.path);
          return {
            exists: data !== undefined,
            data: () => (data === undefined ? undefined : clone(data)),
          };
        },
        create(ref, data) {
          if (store.has(ref.path)) {
            const error = new Error("already-exists");
            error.code = "already-exists";
            throw error;
          }
          store.set(ref.path, clone(data));
        },
        set(ref, data) {
          store.set(ref.path, clone(data));
        },
        update(ref, data) {
          if (!store.has(ref.path)) throw new Error("not-found");
          store.set(ref.path, { ...store.get(ref.path), ...clone(data) });
        },
        delete(ref) {
          store.delete(ref.path);
        },
      };
      return callback(transaction);
    },
  };
}

function pendingFriendshipSeed({ requestedBy = "alice" } = {}) {
  const pb = "friendships/" + pairId("alice", "bob");
  return createFakeDb({
    [pb]: {
      userA: "alice",
      userB: "bob",
      userIds: ["alice", "bob"],
      status: "pending",
      requestedBy,
    },
  });
}

test("relationship IDs are deterministic", () => {
  assert.equal(pairId("bob", "alice"), "5:alice3:bob");
  assert.equal(pairId("alice", "bob"), "5:alice3:bob");
  assert.equal(respectId("alice", "bob"), "5:alice3:bob");
  assert.notEqual(pairId("a_b", "c"), pairId("a", "b_c"));
  assert.notEqual(respectId("a_b", "c"), respectId("a", "b_c"));
  assert.equal(legacyPairId("bob", "alice"), "alice_bob");
  assert.equal(legacyRespectId("alice", "bob"), "alice_bob");
});

test("legacy collision fallback requires exact stored participants", () => {
  assert.equal(
    matchesLegacyRespect(
      { fromUserId: "a_b", toUserId: "c" },
      "a",
      "b_c",
    ),
    false,
  );
  assert.equal(
    matchesLegacyRespect(
      { fromUserId: "a_b", toUserId: "c" },
      "a_b",
      "c",
    ),
    true,
  );
  assert.equal(
    matchesLegacyFriendship(
      { userA: "a", userB: "b_c" },
      "a_b",
      "c",
    ),
    false,
  );
  assert.equal(
    matchesLegacyFriendship(
      { userA: "a", userB: "b_c" },
      "a",
      "b_c",
    ),
    true,
  );
});

test("public profile contains only the approved projection fields", () => {
  const profile = buildPublicProfile({
    username: "Alice",
    avatarUrl: "https://example.test/a.jpg",
    bio: "Anime fan",
    totalRespect: 12,
    fansCount: 2,
    email: "private@example.test",
    coinsBalance: 999,
    subscriptionType: "premium",
    equippedFrameId: "frame_sakura",
  });

  assert.deepEqual(Object.keys(profile), DISPLAY_FIELDS);
  assert.equal(profile.email, undefined);
  assert.equal(profile.coinsBalance, undefined);
  assert.equal(profile.subscriptionType, undefined);
  assert.equal(profile.equippedFrameId, "frame_sakura");
  assert.equal(shouldPublishProfile({ profileVisibility: "private" }), false);
  assert.equal(shouldPublishProfile({ profileVisibility: "public" }), true);
});

test("callables reject unauthenticated, self, and out-of-range respect", async () => {
  const handlers = createSocialGraph({
    db: {},
    FieldValue: {},
    HttpsError: TestHttpsError,
  });
  await assert.rejects(
    handlers.giveRespect({ data: { toUserId: "bob", value: 5 } }),
    (error) => error.code === "unauthenticated",
  );
  await assert.rejects(
    handlers.giveRespect({
      auth: { uid: "alice" },
      data: { toUserId: "alice", value: 5 },
    }),
    (error) => error.code === "invalid-argument",
  );
  await assert.rejects(
    handlers.giveRespect({
      auth: { uid: "alice" },
      data: { toUserId: "bob", value: 8 },
    }),
    (error) => error.code === "invalid-argument",
  );
  assert.equal(validUid("bad/id"), false);
});

test("cancelFriendRequest deletes a pending request made by the caller", async () => {
  const db = pendingFriendshipSeed();
  const handlers = createSocialGraph({
    db,
    FieldValue: {},
    HttpsError: TestHttpsError,
  });
  const result = await handlers.cancelFriendRequest({
    auth: { uid: "alice" },
    data: { otherUserId: "bob" },
  });
  assert.equal(result.ok, true);
  assert.equal(db.store.has("friendships/" + pairId("alice", "bob")), false);
});

test("cancelFriendRequest rejects unauthenticated, self, and non-requester", async () => {
  const handlers = createSocialGraph({
    db: {},
    FieldValue: {},
    HttpsError: TestHttpsError,
  });
  await assert.rejects(
    handlers.cancelFriendRequest({ data: { otherUserId: "bob" } }),
    (error) => error.code === "unauthenticated",
  );
  await assert.rejects(
    handlers.giveRespect({
      auth: { uid: "alice" },
      data: { otherUserId: "alice" },
    }),
    (error) => error.code === "invalid-argument",
  );
  const db = pendingFriendshipSeed();
  const requesterOnly = createSocialGraph({
    db,
    FieldValue: {},
    HttpsError: TestHttpsError,
  });
  await assert.rejects(
    requesterOnly.cancelFriendRequest({
      auth: { uid: "bob" },
      data: { otherUserId: "alice" },
    }),
    (error) => error.code === "permission-denied",
  );
  assert.equal(db.store.has("friendships/" + pairId("alice", "bob")), true);
});

test("cancelFriendRequest rejects requests that are not pending", async () => {
  const db = createFakeDb({
    ["friendships/" + pairId("alice", "bob")]: {
      userA: "alice",
      userB: "bob",
      userIds: ["alice", "bob"],
      status: "accepted",
      requestedBy: "alice",
    },
  });
  const handlers = createSocialGraph({
    db,
    FieldValue: {},
    HttpsError: TestHttpsError,
  });
  await assert.rejects(
    handlers.cancelFriendRequest({
      auth: { uid: "alice" },
      data: { otherUserId: "bob" },
    }),
    (error) => error.code === "permission-denied",
  );
  assert.equal(db.store.has("friendships/" + pairId("alice", "bob")), true);
});

test("blockUser creates a server-owned block and only the blocker can undo it", async () => {
  const db = createFakeDb({
    "users/alice": { username: "Alice" },
    "users/bob": { username: "Bob" },
  });
  const handlers = createSocialGraph({
    db,
    FieldValue: { serverTimestamp: () => ({ server: true }) },
    HttpsError: TestHttpsError,
  });

  const blocked = await handlers.blockUser({
    auth: { uid: "alice" },
    data: { otherUserId: "bob" },
  });
  assert.equal(blocked.ok, true);
  const relationPath = "friendships/" + pairId("alice", "bob");
  assert.equal(db.store.get(relationPath).status, "blocked");
  assert.equal(db.store.get(relationPath).blockedBy, "alice");
  assert.deepEqual(db.store.get(relationPath).userIds, ["alice", "bob"]);

  await assert.rejects(
    handlers.unblockUser({
      auth: { uid: "bob" },
      data: { otherUserId: "alice" },
    }),
    (error) => error.code === "permission-denied",
  );
  assert.equal(db.store.get(relationPath).status, "blocked");

  const unblocked = await handlers.unblockUser({
    auth: { uid: "alice" },
    data: { otherUserId: "bob" },
  });
  assert.equal(unblocked.ok, true);
  assert.equal(db.store.has(relationPath), false);
});

test("blockUser rejects self-blocking and nonexistent accounts", async () => {
  const db = createFakeDb({ "users/alice": { username: "Alice" } });
  const handlers = createSocialGraph({
    db,
    FieldValue: { serverTimestamp: () => ({ server: true }) },
    HttpsError: TestHttpsError,
  });
  await assert.rejects(
    handlers.blockUser({ auth: { uid: "alice" }, data: { otherUserId: "alice" } }),
    (error) => error.code === "invalid-argument",
  );
  await assert.rejects(
    handlers.blockUser({ auth: { uid: "alice" }, data: { otherUserId: "missing" } }),
    (error) => error.code === "not-found",
  );
});
