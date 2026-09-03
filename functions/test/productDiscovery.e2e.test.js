"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const admin = require("firebase-admin");
const { createRecommendationEngine } = require("../src/recommendationEngine");
const { createAnimeListsDomain } = require("../src/animeListsDomain");

process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-pubget-security";

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: "demo-pubget-security" });
}

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const FieldValue = admin.firestore.FieldValue;
const db = admin.firestore();

function recs() {
  return createRecommendationEngine({ db, HttpsError: TestHttpsError });
}

function lists() {
  return createAnimeListsDomain({ db, FieldValue, HttpsError: TestHttpsError });
}

test("multi-user discovery ranking and anime lists against the emulator", async () => {
  await db.doc("users/alice").set({
    username: "Alice", favoriteAnimeIds: ["one_piece"], profileVisibility: "public",
  });
  await db.doc("users/bob").set({
    username: "Bob", favoriteAnimeIds: ["naruto"], profileVisibility: "public",
  });
  await db.doc("public_profiles/nami").set({
    username: "Nami", favoriteAnimeIds: ["one_piece"], totalRespect: 3,
  });
  await db.doc("public_profiles/sakura").set({
    username: "Sakura", favoriteAnimeIds: ["naruto"], totalRespect: 3,
  });
  await db.doc("groups/op-crew").set({
    isSearchable: true, animeId: "one_piece", name: "Crew",
    activityScore: 40, risingScore: 55, membersCount: 5,
    description: "Straw hat sailors talk strategy",
    rules: "No spoilers in the main chat",
    imageUrl: "https://example.com/op.png",
    founderId: "nami", createdAt: new Date(),
  });
  await db.doc("groups/leaf").set({
    isSearchable: true, animeId: "naruto", name: "Leaf",
    activityScore: 40, risingScore: 55, membersCount: 5,
    description: "Hidden leaf missions and talk",
    rules: "Keep the village civil please",
    imageUrl: "https://example.com/leaf.png",
    founderId: "sakura", createdAt: new Date(),
  });
  await db.doc("edits/op-edit").set({
    status: "published", creatorId: "nami", animeTag: "one_piece",
    createdAt: new Date(), qualifiedViewsCount: 6, likesCount: 2, caption: "gear",
  });
  await db.doc("edits/naruto-edit").set({
    status: "published", creatorId: "sakura", animeTag: "naruto",
    createdAt: new Date(), qualifiedViewsCount: 6, likesCount: 2, caption: "rasengan",
  });
  await db.doc("fanWorks/op-work").set({
    status: "published", moderationStatus: "approved", creatorId: "nami",
    animeId: "one_piece", title: "Log pose", type: "story", likesCount: 2,
    publishedAt: new Date(),
  });
  const alice = await recs().getDiscoveryFeed({ auth: { uid: "alice" } });
  const bob = await recs().getDiscoveryFeed({ auth: { uid: "bob" } });
  assert.notEqual(
    alice.sections.recommendedGroups.items[0].targetId,
    bob.sections.recommendedGroups.items[0].targetId,
  );
  assert.equal(alice.sections.recommendedEdits.items[0].targetId, "op-edit");
  assert.equal(bob.sections.recommendedEdits.items[0].targetId, "naruto-edit");
  await lists().setAnimeListEntry({
    auth: { uid: "alice" },
    data: { animeId: "21", status: "watching", title: "One Piece", rating: 9 },
  });
  const listed = await lists().getAnimeList({ auth: { uid: "alice" } });
  assert.equal(listed.items.some((item) => item.animeId === "21"), true);
  await assert.rejects(
    lists().setAnimeListEntry({ data: { animeId: "21", status: "watching" } }),
    (error) => error.code === "unauthenticated",
  );
});

test.after(async () => {
  try {
    await db.terminate();
  } catch (_) {
    // Best-effort so combined emulator runs do not hang on open clients.
  }
});
