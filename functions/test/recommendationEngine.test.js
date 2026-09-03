"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createRecommendationEngine } = require("../src/recommendationEngine");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function createFakeDb(seed = {}) {
  const store = new Map(Object.entries(clone(seed)));
  function docsFor(prefix) {
    return [...store.entries()]
      .filter(([path]) => path.startsWith(`${prefix}/`) && path.split("/").length === prefix.split("/").length + 1)
      .map(([path, data]) => ({
        id: path.slice(prefix.length + 1),
        data: () => data,
        ref: { path },
      }));
  }
  function applyWhere(docs, filters) {
    return docs.filter((doc) => filters.every((filter) => {
      const val = doc.data()[filter.field];
      if (filter.op === "==") return val === filter.value;
      if (filter.op === "in") return Array.isArray(filter.value) && filter.value.includes(val);
      if (filter.op === "array-contains") {
        return Array.isArray(val) && val.includes(filter.value);
      }
      return true;
    }));
  }
  function collection(name) {
    const filters = [];
    const api = {
      where(field, op, value) {
        filters.push({ field, op, value });
        return api;
      },
      limit() { return api; },
      orderBy() { return api; },
      startAfter() { return api; },
      async get() {
        return { docs: applyWhere(docsFor(name), filters) };
      },
      doc(id) {
        const path = `${name}/${id}`;
        return {
          id,
          path,
          collection: (child) => collection(`${path}/${child}`),
          async get() {
            return { exists: store.has(path), id, data: () => store.get(path), ref: { path } };
          },
        };
      },
    };
    return api;
  }
  return {
    collection,
    collectionGroup() {
      return {
        where() { return this; },
        limit() { return this; },
        async get() { return { docs: [] }; },
      };
    },
  };
}

function engine(seed) {
  return createRecommendationEngine({
    db: createFakeDb(seed),
    HttpsError: TestHttpsError,
    clock: { now: () => new Date("2026-09-03T12:00:00Z") },
  });
}

test("personalized feeds differ when anime interests differ", async () => {
  const seed = {
    "users/alice": { favoriteAnimeIds: ["one_piece"] },
    "users/bob": { favoriteAnimeIds: ["naruto"] },
    "groups/op": {
      isSearchable: true, animeId: "one_piece", activityScore: 40, risingScore: 50,
      membersCount: 6, description: "Straw hats meet here every week",
      rules: "Be kind to crewmates always", imageUrl: "https://cdn/x.png",
      founderId: "zoro", createdAt: "2026-09-01T00:00:00.000Z",
    },
    "groups/naruto": {
      isSearchable: true, animeId: "naruto", activityScore: 40, risingScore: 50,
      membersCount: 6, description: "Hidden leaf hangout for fans",
      rules: "No spoilers in the lobby chat", imageUrl: "https://cdn/y.png",
      founderId: "kakashi", createdAt: "2026-09-01T00:00:00.000Z",
    },
    "edits/e-op": {
      status: "published", creatorId: "zoro", animeTag: "one_piece",
      createdAt: "2026-09-02T00:00:00.000Z", qualifiedViewsCount: 8, likesCount: 3,
    },
    "edits/e-naruto": {
      status: "published", creatorId: "kakashi", animeTag: "naruto",
      createdAt: "2026-09-02T00:00:00.000Z", qualifiedViewsCount: 8, likesCount: 3,
    },
    "public_profiles/nami": { username: "Nami", favoriteAnimeIds: ["one_piece"], totalRespect: 4 },
    "public_profiles/sakura": { username: "Sakura", favoriteAnimeIds: ["naruto"], totalRespect: 4 },
  };
  const alice = await engine(seed).getDiscoveryFeed({ auth: { uid: "alice" } });
  const bob = await engine(seed).getDiscoveryFeed({ auth: { uid: "bob" } });
  const aliceGroup = alice.sections.recommendedGroups.items[0].targetId;
  const bobGroup = bob.sections.recommendedGroups.items[0].targetId;
  assert.notEqual(aliceGroup, bobGroup);
  assert.equal(alice.sections.recommendedEdits.items[0].targetId, "e-op");
  assert.equal(bob.sections.recommendedEdits.items[0].targetId, "e-naruto");
  assert.equal(alice.sections.recommendedPeople.items[0].targetId, "nami");
  assert.equal(bob.sections.recommendedPeople.items[0].targetId, "sakura");
  assert.equal(alice.sections.recommendedAnime.items[0].targetId, "one_piece");
  assert.equal(bob.sections.recommendedAnime.items[0].targetId, "naruto");
});

test("blocked and private groups stay out of discovery", async () => {
  const seed = {
    "users/alice": { favoriteAnimeIds: ["one_piece"] },
    "groups/hidden": {
      isSearchable: false, animeId: "one_piece", activityScore: 99, risingScore: 99,
      membersCount: 8, founderId: "x",
    },
    "public_profiles/mallory": { username: "Mallory", favoriteAnimeIds: ["one_piece"] },
    "friendships/alice_mallory": { userIds: ["alice", "mallory"], status: "blocked" },
  };
  const feed = await engine(seed).getDiscoveryFeed({ auth: { uid: "alice" } });
  assert.equal(feed.sections.recommendedGroups.items.some((item) => item.targetId === "hidden"), false);
  assert.equal(feed.sections.recommendedPeople.items.some((item) => item.targetId === "mallory"), false);
});

test("blocked creators are excluded from edits, fan works, groups, and rising creators", async () => {
  const seed = {
    "users/alice": { favoriteAnimeIds: ["one_piece"] },
    "users/bob": { favoriteAnimeIds: ["one_piece"] },
    "friendships/alice_mallory": {
      userIds: ["alice", "mallory"], status: "blocked",
    },
    "edits/blocked-edit": {
      status: "published", creatorId: "mallory", animeTag: "one_piece",
      createdAt: "2026-09-02T00:00:00.000Z", qualifiedViewsCount: 80, likesCount: 20,
    },
    "edits/safe-edit": {
      status: "published", creatorId: "zoro", animeTag: "one_piece",
      createdAt: "2026-09-02T00:00:00.000Z", qualifiedViewsCount: 4, likesCount: 1,
    },
    "fanWorks/blocked-work": {
      status: "published", moderationStatus: "approved", creatorId: "mallory",
      animeId: "one_piece", title: "Forged", type: "story", likesCount: 9,
      publishedAt: "2026-09-02T00:00:00.000Z",
    },
    "fanWorks/safe-work": {
      status: "published", moderationStatus: "approved", creatorId: "zoro",
      animeId: "one_piece", title: "Log", type: "story", likesCount: 2,
      publishedAt: "2026-09-02T00:00:00.000Z",
    },
    "groups/blocked-crew": {
      isSearchable: true, animeId: "one_piece", activityScore: 90, risingScore: 90,
      membersCount: 8, founderId: "mallory",
      description: "A searchable crew founded by a blocked user",
      rules: "Keep discussion on the Grand Line",
      imageUrl: "https://cdn/blocked.png", createdAt: "2026-09-01T00:00:00.000Z",
    },
    "groups/safe-crew": {
      isSearchable: true, animeId: "one_piece", activityScore: 40, risingScore: 40,
      membersCount: 6, founderId: "zoro",
      description: "A searchable crew founded by a safe user",
      rules: "Keep discussion on the Grand Line",
      imageUrl: "https://cdn/safe.png", createdAt: "2026-09-01T00:00:00.000Z",
    },
    "public_profiles/mallory": {
      username: "Mallory", favoriteAnimeIds: ["one_piece"], totalRespect: 9,
    },
    "public_profiles/zoro": {
      username: "Zoro", favoriteAnimeIds: ["one_piece"], totalRespect: 4,
    },
  };
  const alice = await engine(seed).getDiscoveryFeed({ auth: { uid: "alice" } });
  const bob = await engine(seed).getDiscoveryFeed({ auth: { uid: "bob" } });
  const has = (feed, section, id) =>
    feed.sections[section].items.some((item) => item.targetId === id);
  assert.equal(has(alice, "recommendedEdits", "blocked-edit"), false);
  assert.equal(has(alice, "recommendedFanWorks", "blocked-work"), false);
  assert.equal(has(alice, "recommendedGroups", "blocked-crew"), false);
  assert.equal(has(alice, "risingCreators", "mallory"), false);
  assert.equal(has(alice, "recommendedPeople", "mallory"), false);
  assert.equal(has(alice, "recommendedEdits", "safe-edit"), true);
  assert.equal(has(alice, "recommendedFanWorks", "safe-work"), true);
  assert.equal(has(bob, "recommendedEdits", "blocked-edit"), true);
  assert.equal(has(bob, "recommendedFanWorks", "blocked-work"), true);
  assert.equal(has(bob, "recommendedGroups", "blocked-crew"), true);
});

test("unauthenticated discovery is rejected", async () => {
  await assert.rejects(
    () => engine({}).getDiscoveryFeed({ data: {} }),
    (error) => error.code === "unauthenticated",
  );
});
