"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createAnimeHubDomain } = require("../src/animeHubDomain");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const FieldValue = { serverTimestamp: () => ({ _ts: true }) };

const fullCriteria = {
  story: 8,
  art: 9,
  characters: 10,
  action: 7,
  sound: 8,
  enjoyment: 9,
};

function createFakeDb() {
  const store = new Map();
  function ref(path) {
    return {
      id: path.split("/").pop(),
      path,
      collection(name) {
        return {
          doc(id) {
            return ref(`${path}/${name}/${id}`);
          },
        };
      },
      async get() {
        return { exists: store.has(path), id: this.id, data: () => store.get(path) };
      },
      async set(data, opts) {
        store.set(path, opts && opts.merge ? { ...(store.get(path) || {}), ...data } : { ...data });
      },
      async delete() {
        store.delete(path);
      },
    };
  }
  return {
    store,
    collection(name) {
      return {
        doc(id) {
          return ref(`${name}/${id}`);
        },
      };
    },
    async runTransaction(fn) {
      const tx = {
        async get(r) {
          return { exists: store.has(r.path), data: () => store.get(r.path) };
        },
        set(r, data, opts) {
          store.set(
            r.path,
            opts && opts.merge ? { ...(store.get(r.path) || {}), ...data } : { ...data },
          );
        },
        update(r, data) {
          store.set(r.path, { ...(store.get(r.path) || {}), ...data });
        },
        create(r, data) {
          store.set(r.path, { ...data });
        },
        delete(r) {
          store.delete(r.path);
        },
      };
      return fn(tx);
    },
  };
}

function domain() {
  const db = createFakeDb();
  db.store.set("users/alice", { username: "Alice" });
  db.store.set("users/bob", { username: "Bob" });
  return {
    db,
    hub: createAnimeHubDomain({ db, FieldValue, HttpsError: TestHttpsError }),
  };
}

function overallOf(criteria) {
  const keys = Object.keys(criteria);
  return Math.round((keys.reduce((sum, key) => sum + criteria[key], 0) / keys.length) * 10) / 10;
}

test("upsert combines criteria with an unweighted mean and aggregates server-side", async () => {
  const { hub, db } = domain();
  const result = await hub.upsertAnimeRating({
    auth: { uid: "alice" },
    data: { animeId: "16498", title: "Attack on Titan", criteria: fullCriteria, comment: "Great." },
  });
  assert.equal(result.overall, overallOf(fullCriteria));
  const rating = db.store.get("users/alice/anime_ratings/16498");
  assert.equal(rating.userId, "alice");
  assert.equal(rating.overall, result.overall);
  const stats = db.store.get("anime_stats/16498");
  assert.equal(stats.ratingCount, 1);
  assert.equal(stats.averageScore, result.overall);
  assert.equal(db.store.get("anime_stats/16498/reviews/alice").comment, "Great.");
});

test("a second user updates the server aggregate mean", async () => {
  const { hub, db } = domain();
  await hub.upsertAnimeRating({
    auth: { uid: "alice" },
    data: { animeId: "16498", criteria: fullCriteria },
  });
  const bobCriteria = { ...fullCriteria, story: 4, enjoyment: 4 };
  const bob = await hub.upsertAnimeRating({
    auth: { uid: "bob" },
    data: { animeId: "16498", criteria: bobCriteria },
  });
  const stats = db.store.get("anime_stats/16498");
  const aliceOverall = overallOf(fullCriteria);
  const expected = Math.round(((aliceOverall + bob.overall) / 2) * 10) / 10;
  assert.equal(stats.ratingCount, 2);
  assert.equal(stats.averageScore, expected);
});

test("one rating per user is updated in place", async () => {
  const { hub, db } = domain();
  await hub.upsertAnimeRating({
    auth: { uid: "alice" },
    data: { animeId: "16498", criteria: fullCriteria },
  });
  db.store.delete("users/alice/animeHubRate/write");
  const next = { ...fullCriteria, story: 10, action: 10 };
  await hub.upsertAnimeRating({
    auth: { uid: "alice" },
    data: { animeId: "16498", criteria: next },
  });
  assert.equal(db.store.get("users/alice/anime_ratings/16498").overall, overallOf(next));
  assert.equal(db.store.get("anime_stats/16498").ratingCount, 1);
});

test("clients cannot score outside 0-10 or omit a criterion", async () => {
  const { hub } = domain();
  await assert.rejects(
    hub.upsertAnimeRating({
      auth: { uid: "alice" },
      data: { animeId: "16498", criteria: { ...fullCriteria, story: 99 } },
    }),
    (error) => error.code === "invalid-argument",
  );
  await assert.rejects(
    hub.upsertAnimeRating({
      auth: { uid: "alice" },
      data: { animeId: "16498", criteria: { story: 8 } },
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("unauthenticated rating writes are rejected", async () => {
  const { hub } = domain();
  await assert.rejects(
    hub.upsertAnimeRating({ data: { animeId: "16498", criteria: fullCriteria } }),
    (error) => error.code === "unauthenticated",
  );
});

test("auth uid is the only writer — another user cannot forge a rating", async () => {
  const { hub, db } = domain();
  await hub.upsertAnimeRating({
    auth: { uid: "alice" },
    data: { animeId: "16498", criteria: fullCriteria },
  });
  db.store.delete("users/bob/animeHubRate/write");
  await hub.upsertAnimeRating({
    auth: { uid: "bob" },
    data: { animeId: "16498", userId: "alice", criteria: { ...fullCriteria, story: 0 } },
  });
  assert.equal(db.store.get("users/alice/anime_ratings/16498").criteria.story, 8);
  assert.equal(db.store.has("users/bob/anime_ratings/16498"), true);
});

test("rating writes are cooldown limited", async () => {
  const { hub } = domain();
  await hub.upsertAnimeRating({
    auth: { uid: "alice" },
    data: { animeId: "16498", criteria: fullCriteria },
  });
  await assert.rejects(
    hub.upsertAnimeRating({
      auth: { uid: "alice" },
      data: { animeId: "1", criteria: fullCriteria },
    }),
    (error) => error.code === "resource-exhausted",
  );
});

test("deleting a rating reverses the aggregate", async () => {
  const { hub, db } = domain();
  await hub.upsertAnimeRating({
    auth: { uid: "alice" },
    data: { animeId: "16498", criteria: fullCriteria },
  });
  db.store.delete("users/alice/animeHubRate/write");
  await hub.deleteAnimeRating({
    auth: { uid: "alice" },
    data: { animeId: "16498" },
  });
  assert.equal(db.store.has("users/alice/anime_ratings/16498"), false);
  assert.equal(db.store.get("anime_stats/16498").ratingCount, 0);
  assert.equal(db.store.get("anime_stats/16498").averageScore, 0);
});

test("reviews with banned language are rejected", async () => {
  const { hub } = domain();
  await assert.rejects(
    hub.upsertAnimeRating({
      auth: { uid: "alice" },
      data: { animeId: "16498", criteria: fullCriteria, comment: "kys" },
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("review reports flag the review and cannot target yourself", async () => {
  const { hub, db } = domain();
  await hub.upsertAnimeRating({
    auth: { uid: "alice" },
    data: { animeId: "16498", criteria: fullCriteria, comment: "Solid." },
  });
  await assert.rejects(
    hub.reportAnimeReview({
      auth: { uid: "alice" },
      data: { animeId: "16498", targetUserId: "alice", reason: "spam" },
    }),
    (error) => error.code === "failed-precondition",
  );
  await hub.reportAnimeReview({
    auth: { uid: "bob" },
    data: { animeId: "16498", targetUserId: "alice", reason: "spam" },
  });
  assert.equal(db.store.get("anime_stats/16498/reviews/alice").moderationStatus, "flagged");
  assert.ok(db.store.get("anime_stats/16498/reviews/alice/reports/bob"));
});
