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

test("public profile contains only the five approved projection fields", () => {
  const profile = buildPublicProfile({
    username: "Alice",
    avatarUrl: "https://example.test/a.jpg",
    bio: "Anime fan",
    totalRespect: 12,
    fansCount: 2,
    email: "private@example.test",
    coinsBalance: 999,
    subscriptionType: "premium",
  });

  assert.deepEqual(Object.keys(profile), DISPLAY_FIELDS);
  assert.equal(profile.email, undefined);
  assert.equal(profile.coinsBalance, undefined);
  assert.equal(profile.subscriptionType, undefined);
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