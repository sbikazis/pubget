"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  AnimeCatalogRow,
  CharacterPopularityRow,
  CreatorActivityRow,
  FriendActivityRow,
  FreshContentRow,
  rankAnimeOfTheWeek,
  rankPopularCharacters,
  rankRisingCreators,
  rankFriendsActivity,
  rankFreshestContent,
  clampHomeLimit,
  assertViewer,
} = require("../src/discoveryFeedSections");
const { createHomeSections } = require("../src/homeSectionsDomain");

const DAY = 24 * 60 * 60 * 1000;
const now = new Date("2026-01-15T12:00:00.000Z");
const clock = { now: () => now };

function row(id, data) {
  return { id, data: () => data };
}

test("clampHomeLimit falls back to the page size when no limit is sent", () => {
  assert.equal(clampHomeLimit(undefined, { page: 8 }), 8);
  assert.equal(clampHomeLimit(null, { page: 8 }), 8);
});

test("clampHomeLimit rejects non-positive and oversized limits", () => {
  assert.equal(clampHomeLimit(0, { page: 8 }), 8);
  assert.equal(clampHomeLimit(-5, { page: 8 }), 8);
  assert.equal(clampHomeLimit(9999, { page: 8 }), 20);
});

test("clampHomeLimit honours a valid limit", () => {
  assert.equal(clampHomeLimit(12, { page: 8 }), 12);
  assert.equal(clampHomeLimit(3, { page: 8 }), 3);
});

test("assertViewer rejects anonymous callers", () => {
  assert.throws(() => assertViewer(undefined), /Authentication is required/);
  assert.throws(() => assertViewer(""), /Authentication is required/);
  assert.doesNotThrow(() => assertViewer("viewer"));
});

test("anime of the week prefers weekly signals over lifetime totals", () => {
  const rows = [
    new AnimeCatalogRow({
      id: "cold",
      title: "Old Hit",
      ratingCount: 9000,
      weeklyRatingCount: 0,
      lastRatedAt: new Date(now.getTime() - 120 * DAY),
    }),
    new AnimeCatalogRow({
      id: "hot",
      title: "This Week",
      ratingCount: 400,
      weeklyRatingCount: 60,
      lastRatedAt: new Date(now.getTime() - DAY),
    }),
  ];

  const ranked = rankAnimeOfTheWeek(rows, { now, limit: 5 });
  assert.deepEqual(ranked.map((r) => r.id), ["hot"]);
});

test("anime of the week drops anime rated before the window", () => {
  const rows = [
    new AnimeCatalogRow({
      id: "stale",
      title: "Stale",
      ratingCount: 10,
      weeklyRatingCount: 5,
      lastRatedAt: new Date(now.getTime() - 8 * DAY),
    }),
  ];
  assert.deepEqual(rankAnimeOfTheWeek(rows, { now, limit: 5 }), []);
});

test("anime of the week drops anime with no rating this week", () => {
  const rows = [
    new AnimeCatalogRow({
      id: "stale",
      title: "Stale",
      ratingCount: 10,
      weeklyRatingCount: 0,
      lastRatedAt: new Date(now.getTime() - 400 * DAY),
    }),
  ];
  assert.deepEqual(rankAnimeOfTheWeek(rows, { now, limit: 5 }), []);
});

test("popular characters require real community signal", () => {
  const rows = [
    new CharacterPopularityRow({
      characterId: "quiet",
      name: "Quiet",
      favouriteCount: 0,
      discussionCount: 0,
    }),
    new CharacterPopularityRow({
      characterId: "loud",
      name: "Loud",
      favouriteCount: 4,
      discussionCount: 12,
    }),
  ];

  const ranked = rankPopularCharacters(rows, { limit: 5 });
  assert.deepEqual(ranked.map((i) => i.id), ["loud"]);
  assert.equal(ranked[0].reason, "community");
});

test("popular characters label a favourites-only signal honestly", () => {
  const rows = [
    new CharacterPopularityRow({
      characterId: "fav",
      name: "Fav",
      favouriteCount: 20,
      discussionCount: 0,
    }),
  ];
  assert.equal(rankPopularCharacters(rows, { limit: 5 })[0].reason, "favourites");
});

test("popular characters de-duplicate repeated rows", () => {
  const rows = [
    new CharacterPopularityRow({
      characterId: "same",
      name: "Same",
      favouriteCount: 3,
      discussionCount: 1,
    }),
    new CharacterPopularityRow({
      characterId: "same",
      name: "Same",
      favouriteCount: 9,
      discussionCount: 1,
    }),
  ];
  assert.equal(rankPopularCharacters(rows, { limit: 5 }).length, 1);
});

test("rising creators need sustained output, not one viral post", () => {
  const rows = [
    new CreatorActivityRow({
      creatorId: "u-one",
      displayName: "One",
      editCount: 1,
      fanWorkCount: 0,
      totalEngagement: 50000,
    }),
    new CreatorActivityRow({
      creatorId: "u-many",
      displayName: "Many",
      editCount: 6,
      fanWorkCount: 2,
      totalEngagement: 3000,
    }),
  ];

  const ranked = rankRisingCreators(rows, { limit: 5 });
  assert.deepEqual(ranked.map((i) => i.id), ["u-many"]);
});

test("rising creators exclude the viewer", () => {
  const rows = [
    new CreatorActivityRow({
      creatorId: "viewer",
      displayName: "Me",
      editCount: 9,
      fanWorkCount: 9,
      totalEngagement: 900,
    }),
    new CreatorActivityRow({
      creatorId: "other",
      displayName: "Other",
      editCount: 3,
      fanWorkCount: 0,
      totalEngagement: 100,
    }),
  ];

  const ranked = rankRisingCreators(rows, { limit: 5, viewerUid: "viewer" });
  assert.deepEqual(ranked.map((i) => i.id), ["other"]);
});

test("friends activity keeps one newest item per friend", () => {
  const rows = [
    new FriendActivityRow({
      uid: "a",
      kind: "edit",
      refId: "old",
      createdAtMillis: now.getTime() - 10 * 60 * 1000,
    }),
    new FriendActivityRow({
      uid: "a",
      kind: "edit",
      refId: "new",
      createdAtMillis: now.getTime() - 1000,
    }),
    new FriendActivityRow({
      uid: "b",
      kind: "fanWork",
      refId: "w",
      createdAtMillis: now.getTime() - 5000,
    }),
  ];

  const ranked = rankFriendsActivity(rows, { viewerUid: "viewer", limit: 5 });
  assert.deepEqual(
    ranked.map((i) => i.id),
    ["a:edit:new", "b:fanWork:w"],
  );
});

test("friends activity exclude blocked people and the viewer", () => {
  const rows = [
    new FriendActivityRow({
      uid: "blocked-user",
      kind: "edit",
      refId: "e1",
      createdAtMillis: now.getTime() - 1000,
    }),
    new FriendActivityRow({
      uid: "viewer",
      kind: "edit",
      refId: "e2",
      createdAtMillis: now.getTime() - 1000,
    }),
    new FriendActivityRow({
      uid: "friend",
      kind: "edit",
      refId: "e3",
      createdAtMillis: now.getTime() - 1000,
    }),
  ];

  const ranked = rankFriendsActivity(rows, {
    viewerUid: "viewer",
    blockedIds: new Set(["blocked-user"]),
    limit: 5,
  });
  assert.deepEqual(ranked.map((i) => i.id), ["friend:edit:e3"]);
});

test("friends activity drop rows with no usable timestamp", () => {
  const rows = [
    new FriendActivityRow({ uid: "a", kind: "edit", refId: "x", createdAtMillis: 0 }),
  ];
  assert.deepEqual(rankFriendsActivity(rows, { viewerUid: "viewer", limit: 5 }), []);
});

test("freshest content merges kinds newest-first", () => {
  const rows = [
    new FreshContentRow({
      refId: "e1",
      kind: "edit",
      title: "Older edit",
      createdAtMillis: now.getTime() - 5 * 60 * 1000,
    }),
    new FreshContentRow({
      refId: "w1",
      kind: "fanWork",
      title: "Work",
      createdAtMillis: now.getTime() - 60 * 1000,
    }),
  ];

  const ranked = rankFreshestContent(rows, { limit: 5 });
  assert.deepEqual(ranked.map((i) => i.id), ["fanWork:w1", "edit:e1"]);
});

test("freshest content caps each kind so one surface cannot own Home", () => {
  const rows = [];
  for (let index = 0; index < 6; index += 1) {
    rows.push(
      new FreshContentRow({
        refId: `e${index}`,
        kind: "edit",
        title: `Edit ${index}`,
        createdAtMillis: now.getTime() - index * 1000,
      }),
    );
  }
  rows.push(
    new FreshContentRow({
      refId: "w1",
      kind: "fanWork",
      title: "Work",
      createdAtMillis: now.getTime() - 10 * 60 * 1000,
    }),
  );

  const ranked = rankFreshestContent(rows, { limit: 10, perKindCap: 4 });
  const edits = ranked.filter((i) => i.reason === "edit");
  const works = ranked.filter((i) => i.reason === "fanWork");
  assert.equal(edits.length, 4);
  assert.equal(works.length, 1);
});

test("freshest content drops rows without a real timestamp", () => {
  const rows = [
    new FreshContentRow({ refId: "x", kind: "edit", title: "No date", createdAtMillis: 0 }),
  ];
  assert.deepEqual(rankFreshestContent(rows, { limit: 5 }), []);
});

/// A Firestore stub that really applies `where` filters. A stub that ignored
/// them would let a broken weekly window pass its own tests.
function matchesFilter(value, filter) {
  const [field, op, operand] = filter;
  const actual = value[field];
  const wanted = operand instanceof Date ? operand.getTime() : operand;
  const seen =
    actual instanceof Date
      ? actual.getTime()
      : Array.isArray(actual) && field.endsWith("Ids")
        ? actual.length
        : actual;
  if (op === "==") return seen === wanted;
  if (op === ">=") return typeof seen === "number" && seen >= wanted;
  if (op === "in") return Array.isArray(operand) && operand.includes(seen);
  return true;
}

function stubFirestore(data, { profileExists = false } = {}) {
  function collection(name) {
    let limit = 20;
    const filters = [];
    const query = {
      where: (field, op, operand) => {
        filters.push([field, op, operand]);
        return query;
      },
      limit: (value) => {
        limit = value;
        return query;
      },
      doc: (id) => {
        const found = (data[name] || []).find((entry) => entry.id === id);
        return {
          get: async () => (found ? found : { exists: profileExists, id, data: () => ({}) }),
        };
      },
      get: async () => ({
        docs: (data[name] || [])
          .filter((entry) => filters.every((f) => matchesFilter(entry.data() || {}, f)))
          .slice(0, limit),
      }),
    };
    return query;
  }
  return { collection };
}

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function seedData() {
  return {
    anime_stats: [
      row("anime-hot", {
        title: "Weekly Hit",
        imageUrl: "https://img/hot.jpg",
        ratingCount: 300,
        updatedAt: new Date(now.getTime() - DAY),
      }),
      row("anime-cold", {
        title: "Old",
        ratingCount: 8000,
        updatedAt: new Date(now.getTime() - 200 * DAY),
      }),
    ],
    character_stats: [
      row("hero", {
        name: "Hero",
        imageUrl: "https://img/hero.jpg",
        favoritesCount: 12,
        discussionCount: 9,
      }),
      row("nobody", { name: "Nobody", favoritesCount: 0 }),
    ],
    edits: [
      row("edit-1", {
        creatorId: "u1",
        animeId: "anime-hot",
        status: "published",
        caption: "New edit",
        likesCount: 40,
        viewsCount: 900,
        createdAt: new Date(now.getTime() - 60 * 1000),
      }),
      row("edit-stale", {
        creatorId: "u3",
        animeId: "anime-cold",
        status: "published",
        caption: "Older than the week",
        likesCount: 5,
        viewsCount: 10,
        createdAt: new Date(now.getTime() - 30 * DAY),
      }),
      row("edit-2", {
        creatorId: "u1",
        status: "published",
        caption: "Old edit",
        likesCount: 1,
        viewsCount: 4,
        createdAt: new Date(now.getTime() - 6 * DAY),
      }),
    ],
    fanWorks: [
      row("work-1", {
        creatorId: "u2",
        status: "published",
        moderationStatus: "approved",
        title: "Fan Work",
        likesCount: 12,
        publishedAt: new Date(now.getTime() - 120 * 1000),
      }),
    ],
    groups: [
      row("group-1", { name: "Group", isSearchable: true, createdAt: new Date() }),
    ],
    events: [
      row("event-1", { title: "Event", status: "active", createdAt: new Date() }),
    ],
  };
}

test("getHomeSections returns every spec section with only real data", async () => {
  const domain = createHomeSections({
    db: stubFirestore(seedData()),
    HttpsError: TestHttpsError,
    clock,
  });

  const out = await domain.getHomeSections({ auth: { uid: "viewer" }, data: {} });

  assert.deepEqual(Object.keys(out), [
    "animeOfTheWeek",
    "popularCharacters",
    "risingCreators",
    "friendsActivity",
    "freshestContent",
  ]);
  assert.deepEqual(out.animeOfTheWeek.items.map((i) => i.id), ["anime-hot"]);
  assert.equal(out.animeOfTheWeek.items[0].reason, "this_week");
  assert.deepEqual(out.popularCharacters.items.map((i) => i.id), ["hero"]);
  assert.deepEqual(out.risingCreators.items.map((i) => i.id), ["u1"]);
  assert.deepEqual(out.friendsActivity.items, []);
  assert.ok(out.freshestContent.items.length > 0);
});

test("getHomeSections honours a per-section limit", async () => {
  const domain = createHomeSections({
    db: stubFirestore(seedData()),
    HttpsError: TestHttpsError,
    clock,
  });

  const out = await domain.getHomeSections({
    auth: { uid: "viewer" },
    data: { section: "animeOfTheWeek", limit: 1 },
  });

  assert.deepEqual(Object.keys(out), ["animeOfTheWeek"]);
  assert.ok(out.animeOfTheWeek.items.length <= 1);
  assert.equal(out.animeOfTheWeek.hasMore, false);
});

test("getHomeSections rejects anonymous callers", async () => {
  const domain = createHomeSections({
    db: stubFirestore(seedData()),
    HttpsError: TestHttpsError,
    clock,
  });
  await assert.rejects(
    () => domain.getHomeSections({ auth: null, data: {} }),
    (error) => error.code === "unauthenticated",
  );
});

test("getHomeSections rejects an unknown section name", async () => {
  const domain = createHomeSections({
    db: stubFirestore(seedData()),
    HttpsError: TestHttpsError,
    clock,
  });
  await assert.rejects(
    () => domain.getHomeSections({ auth: { uid: "viewer" }, data: { section: "nope" } }),
    (error) => error.code === "invalid-argument",
  );
});

test("getHomeSections returns empty sections rather than filler when nothing ranks", async () => {
  const domain = createHomeSections({
    db: stubFirestore({}),
    HttpsError: TestHttpsError,
    clock,
  });

  const out = await domain.getHomeSections({ auth: { uid: "viewer" }, data: {} });

  for (const section of Object.values(out)) {
    assert.deepEqual(section.items, []);
    assert.equal(section.hasMore, false);
  }
});
test("anime of the week counts only edits published inside the seven day window", async () => {
  const domain = createHomeSections({
    db: stubFirestore(seedData()),
    HttpsError: TestHttpsError,
    clock,
  });

  const out = await domain.getHomeSections({
    auth: { uid: "viewer" },
    data: { section: "animeOfTheWeek" },
  });

  // `anime-cold` has edits, but they are older than the window, so it must not
  // appear. `anime-hot` has one edit inside the week.
  assert.deepEqual(out.animeOfTheWeek.items.map((i) => i.id), ["anime-hot"]);
  assert.equal(out.animeOfTheWeek.items[0].source, "weekly_edits");
  assert.equal(out.animeOfTheWeek.items[0].metadata.weeklyRatingCount, 1);
  assert.equal(out.animeOfTheWeek.items[0].metadata.title, "Weekly Hit");
  assert.equal(out.animeOfTheWeek.items[0].metadata.imageUrl, "https://img/hot.jpg");
  assert.equal(out.animeOfTheWeek.items[0].metadata.ratingCount, 300);
});

test("anime of the week falls back to real ratings when nothing was published", async () => {
  const data = seedData();
  // No published edit for any anime this week.
  data.edits = data.edits.filter((entry) => entry.id !== "edit-1");
  const domain = createHomeSections({
    db: stubFirestore(data),
    HttpsError: TestHttpsError,
    clock,
  });

  const out = await domain.getHomeSections({
    auth: { uid: "viewer" },
    data: { section: "animeOfTheWeek" },
  });

  assert.deepEqual(out.animeOfTheWeek.items.map((i) => i.id), ["anime-hot"]);
  assert.equal(out.animeOfTheWeek.items[0].source, "weekly_ratings");
});

test("popular characters reads the maintained favourite counter, not a scan", async () => {
  const domain = createHomeSections({
    db: stubFirestore(seedData()),
    HttpsError: TestHttpsError,
    clock,
  });

  const out = await domain.getHomeSections({
    auth: { uid: "viewer" },
    data: { section: "popularCharacters" },
  });

  assert.deepEqual(out.popularCharacters.items.map((i) => i.id), ["hero"]);
  const hero = out.popularCharacters.items[0];
  assert.equal(hero.metadata.favouriteCount, 12);
  assert.equal(hero.metadata.discussionCount, 9);
  assert.equal(hero.metadata.imageUrl, "https://img/hero.jpg");
  // The reason must name a signal that actually exists.
  assert.equal(hero.reason, "community");
});

test("popular characters drops a character with no real signal at all", async () => {
  const data = seedData();
  data.character_stats = [
    row("quiet", { name: "Quiet", favoritesCount: 0, discussionCount: 0 }),
  ];
  const domain = createHomeSections({
    db: stubFirestore(data),
    HttpsError: TestHttpsError,
    clock,
  });

  const out = await domain.getHomeSections({
    auth: { uid: "viewer" },
    data: { section: "popularCharacters" },
  });

  assert.deepEqual(out.popularCharacters.items, []);
});
