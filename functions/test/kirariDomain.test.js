"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  KIRARI, TRANSITIONS, transitionStatus, normalizeTags, normalizeEditSettings, rankKirari,
  isFeedCursorAfter, shouldCountEarlySkip, calculateVerifiedPlayback, diversifyKirari, createKirariDomain,
} = require("../src/kirariDomain");

class TestHttpsError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

test("Kirari contract has strict media and daily upload limits", () => {
  assert.equal(KIRARI.minDurationSeconds, 3);
  assert.equal(KIRARI.maxDurationSeconds, 60);
  assert.equal(KIRARI.maxBytes, 500 * 1024 * 1024);
  assert.equal(KIRARI.dailyUploadLimit, 10);
  assert.equal(KIRARI.qualifiedViewSeconds, 3);
  assert.equal(KIRARI.completionPercent, 95);
});

test("Kirari lifecycle only allows declared transitions", () => {
  assert.equal(transitionStatus("uploading", "processing"), true);
  assert.equal(transitionStatus("processing", "preparing"), true);
  assert.equal(transitionStatus("preparing", "published"), true);
  assert.equal(transitionStatus("published", "processing"), false);
  assert.equal(transitionStatus("rejected", "published"), false);
  assert.equal(transitionStatus("failed", "uploading"), true);
  assert.equal(TRANSITIONS.deleted.size, 0);
});

test("hashtag normalization removes duplicates and unsafe characters", () => {
  assert.deepEqual(normalizeTags(["#Anime", "anime", " One_Piece! "]), ["anime", "one_piece"]);
  assert.deepEqual(normalizeTags(null), []);
  assert.throws(() => normalizeTags(new Array(13).fill("tag")));
});

test("Kirari ranking is bounded and reacts to relevance and negative feedback", () => {
  const now = Date.now();
  const base = {
    creatorId: "creator", hashtags: ["one_piece"],
    createdAt: { toMillis: () => now },
    qualifiedViewsCount: 100, completionCount: 70,
    likesCount: 20, commentsCount: 5, savesCount: 5, sharesCount: 2,
    creatorQuality: 80, negativeFeedbackCount: 0,
  };
  const relevant = rankKirari(base, { interests: ["one_piece"], creatorIds: [] }, now);
  const irrelevant = rankKirari(base, { interests: ["bleach"], creatorIds: [] }, now);
  const negative = rankKirari({ ...base, negativeFeedbackCount: 100 }, { interests: ["one_piece"] }, now);
  const strongWatch = rankKirari({
    ...base, durationSeconds: 20, totalQualifiedWatchSeconds: 1800,
    earlySkipCount: 0, replayCount: 25,
  }, { interests: ["one_piece"] }, now);
  const earlySkip = rankKirari({
    ...base, durationSeconds: 20, totalQualifiedWatchSeconds: 100,
    earlySkipCount: 80, replayCount: 0,
  }, { interests: ["one_piece"] }, now);
  assert.ok(relevant > irrelevant);
  assert.ok(relevant > negative);
  assert.ok(strongWatch > earlySkip, "qualified watch and replay should improve ranking over early skips");
  assert.ok(relevant >= 0 && relevant <= 100);
});

test("all Kirari callables reject unauthenticated requests before touching Firestore", async () => {
  const domain = createKirariDomain({
    db: { collection() { throw new Error("database must not be touched"); } },
    FieldValue: {},
    HttpsError: TestHttpsError,
    bucket: {},
  });
  for (const [name, data] of [
    ["startUpload", {}],
    ["finalizeUpload", { reelId: "r1" }],
    ["retryProcessing", { reelId: "r1" }],
    ["cancelUpload", { reelId: "r1" }],
    ["deleteReel", { reelId: "r1" }],
    ["setCreatorMute", { creatorId: "bob" }],
    ["getHashtagFeed", { hashtag: "anime" }],
    ["getAudioLibrary", {}],
    ["getComments", { reelId: "r1" }],
    ["getReelsByAudio", { audioId: "a1" }],
    ["getCreatorReels", { creatorId: "bob" }],
    ["getReel", { reelId: "r1" }],
    ["action", { reelId: "r1", kind: "like" }],
    ["addComment", { reelId: "r1", text: "hi" }],
    ["commentAction", { reelId: "r1", commentId: "c1", kind: "like" }],
    ["startPlayback", { reelId: "r1" }],
    ["recordPlayback", { reelId: "r1", sessionId: "s1", eventId: "e1" }],
    ["getFeed", {}],
  ]) {
    await assert.rejects(
      domain[name]({ data }),
      (error) => error.code === "unauthenticated",
    );
  }
});

test("editor settings are bounded and unsafe filter values fall back to original", () => {
  assert.deepEqual(normalizeEditSettings({
    trimStartSeconds: -10,
    trimEndSeconds: 999,
    speed: 9,
    filter: "arbitrary",
    overlayText: "x".repeat(100),
    coverTimeSeconds: -5,
  }), {
    trimStartSeconds: 0,
    trimEndSeconds: 60,
    speed: 2,
    filter: "none",
    overlayText: "x".repeat(80),
    coverTimeSeconds: 0,
  });
});

test("audio catalog returns only approved reusable tracks with a bounded page size", async () => {
  const filters = [];
  let requestedLimit = 0;
  const docs = [{
    id: "theme_1",
    data: () => ({
      title: "Opening theme", artist: "Artist", license: "CC BY 4.0",
      attribution: "Artist / label", audioPath: "kirari-audio/theme_1/audio.mp3",
      status: "approved", allowReuse: true,
    }),
  }];
  const query = {
    where(field, operator, value) { filters.push([field, operator, value]); return this; },
    orderBy(field, direction) { filters.push([field, direction]); return this; },
    limit(value) { requestedLimit = value; return this; },
    async get() { return { docs }; },
  };
  const domain = createKirariDomain({
    db: { collection: () => query },
    FieldValue: {},
    HttpsError: TestHttpsError,
    bucket: {},
  });
  const result = await domain.getAudioLibrary({
    auth: { uid: "viewer" }, data: { limit: 500 },
  });
  assert.equal(requestedLimit, 50);
  assert.deepEqual(filters.slice(0, 2), [
    ["status", "==", "approved"],
    ["allowReuse", "==", true],
  ]);
  assert.equal(result.items[0].id, "theme_1");
});

test("audio publishing requires explicit reuse approval and preserves attribution", async () => {
  let saved = null;
  const domain = createKirariDomain({
    db: {
      collection: () => ({
        doc: () => ({
          set: async (data) => { saved = data; },
        }),
      }),
    },
    FieldValue: { serverTimestamp: () => "server-time" },
    HttpsError: TestHttpsError,
    bucket: {
      file: (path) => ({
        getMetadata: async () => [{
          size: "2048",
          contentType: path.endsWith(".mp3") ? "audio/mpeg" : "application/octet-stream",
        }],
      }),
    },
  });
  const result = await domain.publishAudioTrack({
    auth: { uid: "admin", token: { admin: true } },
    data: {
      audioId: "theme_1", title: "Opening theme", artist: "Artist",
      license: "CC BY 4.0", attribution: "Artist / label",
      creatorId: "source_creator",
      audioPath: "kirari-audio/theme_1/audio.mp3",
      approved: true, allowReuse: true,
    },
  });
  assert.deepEqual(result, { ok: true, audioId: "theme_1" });
  assert.equal(saved.status, "approved");
  assert.equal(saved.allowReuse, true);
  assert.equal(saved.license, "CC BY 4.0");
  assert.equal(saved.attribution, "Artist / label");
  assert.equal(saved.creatorId, "source_creator");
});

test("audio publishing rejects missing rights approval and oversized files", async () => {
  const makeDomain = (size) => createKirariDomain({
    db: { collection() { throw new Error("database must not be written"); } },
    FieldValue: { serverTimestamp: () => "server-time" },
    HttpsError: TestHttpsError,
    bucket: { file: () => ({
      getMetadata: async () => [{ size: String(size), contentType: "audio/mpeg" }],
    }) },
  });
  const request = {
    auth: { uid: "admin", token: { admin: true } },
    data: {
      audioId: "theme_1", title: "Opening theme", artist: "Artist",
      license: "CC BY 4.0", attribution: "Artist / label",
      audioPath: "kirari-audio/theme_1/audio.mp3",
      approved: true, allowReuse: true,
    },
  };
  await assert.rejects(
    makeDomain(1024).publishAudioTrack({
      ...request, data: { ...request.data, approved: false },
    }),
    (error) => error.code === "failed-precondition",
  );
  await assert.rejects(
    makeDomain(26 * 1024 * 1024).publishAudioTrack(request),
    (error) => error.code === "invalid-argument",
  );
});

test("admin moderation and audio catalog endpoints require the admin claim", async () => {
  const domain = createKirariDomain({
    db: { collection() { throw new Error("database must not be touched"); } },
    FieldValue: {},
    HttpsError: TestHttpsError,
    bucket: {},
  });
  for (const name of ["publishAudioTrack", "reviewContent", "getModerationQueue"]) {
    await assert.rejects(
      domain[name]({ auth: { uid: "member", token: { admin: false } }, data: {} }),
      (error) => error.code === "permission-denied",
    );
  }
});


test('feed cursor uses score descending and id ascending', () => {
  assert.equal(isFeedCursorAfter(9, 'b', 10, 'a'), true);
  assert.equal(isFeedCursorAfter(10, 'b', 10, 'a'), true);
  assert.equal(isFeedCursorAfter(10, 'a', 10, 'a'), false);
  assert.equal(isFeedCursorAfter(11, 'z', 10, 'a'), false);
  assert.equal(isFeedCursorAfter(9, 'z', NaN, null), true);
  assert.equal(isFeedCursorAfter(10, 'a', 10, null), true);
  assert.equal(isFeedCursorAfter(10, 'a', Infinity, 'b'), true);
  assert.equal(isFeedCursorAfter(10, 'c', 10, 'b'), true);
  assert.equal(isFeedCursorAfter(10, 'a', 10, 'c'), false);
});


test("Kirari feed fails closed when privacy-filter lookup fails", async () => {
  const db = {
    collection(name) {
      if (name === "users") return {
        doc: () => ({
          get: async () => ({ data: () => ({}) }),
          collection: () => {
            const query = { limit: () => query, get: async () => ({ docs: [] }) };
            return query;
          },
        }),
      };
      if (name === "friendships") return {
        where: () => {
          const query = {
            limit: () => query,
            get: async () => { throw new Error("privacy lookup unavailable"); },
          };
          return query;
        },
      };
      if (name === "respects") return {
        where: () => {
          const query = {
            limit: () => query,
            get: async () => ({ docs: [] }),
          };
          return query;
        },
      };
      throw new Error("unexpected collection " + name);
    },
  };
  const domain = createKirariDomain({ db, FieldValue: {}, HttpsError: TestHttpsError, bucket: {} });
  await assert.rejects(
    domain.getFeed({ auth: { uid: "viewer" }, data: { type: "forYou" } }),
    /privacy lookup unavailable/,
  );
});

test("For You ranking rewards verified watch time and completion with small-sample smoothing", () => {
  const now = Date.now();
  const base = {
    creatorId: "creator", durationSeconds: 20,
    createdAt: { toMillis: () => now },
    qualifiedViewsCount: 100, completionCount: 50,
    totalQualifiedWatchSeconds: 500, earlySkipCount: 0, replayCount: 0,
  };
  const highRetention = rankKirari({
    ...base, completionCount: 90, totalQualifiedWatchSeconds: 1700, replayCount: 20,
  }, { interests: [], creatorIds: [] }, now);
  const lowRetention = rankKirari({
    ...base, completionCount: 10, totalQualifiedWatchSeconds: 150, earlySkipCount: 70,
  }, { interests: [], creatorIds: [] }, now);
  assert.ok(highRetention > lowRetention);
});

test("For You diversity caps repeated creators and anime while retaining exploration", () => {
  const candidates = [
    { id: "r1", creatorId: "same", animeId: "one", _rank: 100, _relevant: true },
    { id: "r2", creatorId: "same", animeId: "one", _rank: 99, _relevant: true },
    { id: "r3", creatorId: "same", animeId: "one", _rank: 98, _relevant: true },
    { id: "r4", creatorId: "other", animeId: "one", _rank: 97, _relevant: true },
    { id: "e1", creatorId: "explorer", animeId: "new", _rank: 90, _relevant: false },
    { id: "e2", creatorId: "explorer-2", animeId: "new-2", _rank: 80, _relevant: false },
  ];
  const page = diversifyKirari(candidates, 5, 0.2);
  assert.equal(page.length, 4, "the page should preserve diversity when fewer unique candidates exist");
  assert.ok(page.some((item) => item._relevant === false), "one slot should explore outside interests");
  assert.ok(page.filter((item) => item.creatorId === "same").length <= 2);
  assert.ok(page.filter((item) => item.animeId === "one").length <= 2);
});

test("For You ranking does not consume client-supplied playback counters", () => {
  const now = Date.now();
  const base = {
    creatorId: "creator", durationSeconds: 20,
    createdAt: { toMillis: () => now },
    qualifiedViewsCount: 20, completionCount: 10,
    totalQualifiedWatchSeconds: 200, earlySkipCount: 2, replayCount: 1,
  };
  const normal = rankKirari(base, { interests: [], creatorIds: [] }, now);
  const forged = rankKirari({
    ...base, clientWatchSeconds: 999999, clientCompletionCount: 999999,
    clientReplayCount: 999999, clientEarlySkipCount: 0,
  }, { interests: [], creatorIds: [] }, now);
  assert.equal(forged, normal);
});

test("server early-skip policy only counts recent unqualified playback transitions", () => {
  const now = 100000;
  const valid = {
    viewerId: "viewer", uid: "viewer", qualified: false, skipCounted: false,
    creditedSeconds: 1, lastHeartbeatAt: now - 2000,
    creatorId: "creator", reelStatus: "published", now,
  };
  assert.equal(shouldCountEarlySkip(valid), true);
  assert.equal(shouldCountEarlySkip({ ...valid, qualified: true }), false);
  assert.equal(shouldCountEarlySkip({ ...valid, skipCounted: true }), false);
  assert.equal(shouldCountEarlySkip({ ...valid, creditedSeconds: 3 }), false);
  assert.equal(shouldCountEarlySkip({ ...valid, viewerId: "attacker" }), false);
  assert.equal(shouldCountEarlySkip({ ...valid, creatorId: "viewer" }), false);
  assert.equal(shouldCountEarlySkip({ ...valid, reelStatus: "deleted" }), false);
  assert.equal(shouldCountEarlySkip({ ...valid, lastHeartbeatAt: now - 16000 }), false);
  assert.equal(shouldCountEarlySkip({ ...valid, lastHeartbeatAt: now - 100 }), false);
});

test("feed pagination scans beyond a privacy-filtered candidate window without losing the next page", async () => {
  const now = Date.now();
  const blockedCreators = Array.from({ length: 100 }, (_, i) => "blocked_" + i);
  const blockedDocs = blockedCreators.map((creatorId) => ({
    id: "block_" + creatorId,
    data: () => ({ status: "blocked", userA: "viewer", userB: creatorId }),
  }));
  const rows = [
    ...blockedCreators.map((creatorId, i) => ({
      id: "blocked_reel_" + i,
      data: {
        creatorId, status: "published", moderationStatus: "approved",
        rankingScore: 1000 - i, velocityScore: 0, publishedAt: now - i,
        createdAt: now - i, durationSeconds: 20,
      },
    })),
    ...Array.from({ length: 5 }, (_, i) => ({
      id: "visible_" + i,
      data: {
        creatorId: "visible_creator_" + i, status: "published",
        moderationStatus: "approved", rankingScore: 100 - i,
        velocityScore: 0, publishedAt: now - 100 - i,
        createdAt: now - 100 - i, durationSeconds: 20,
      },
    })),
  ];
  const byId = new Map(rows.map((row) => [row.id, row]));
  const makeEmptyQuery = (docs = []) => ({
    where() { return this; }, orderBy() { return this; }, limit() { return this; },
    async get() { return { docs }; },
  });
  const db = {
    collection(name) {
      if (name === "users") return {
        doc: (uid) => ({
          async get() { return { data: () => ({}) }; },
          collection: (sub) => sub === "kirariSeen" ? {
            doc: (id) => ({ async get() { return { id, exists: false }; } }),
            ...makeEmptyQuery(),
          } : makeEmptyQuery(),
        }),
      };
      if (name === "friendships") return {
        where(field) { return makeEmptyQuery(field === "userA" ? blockedDocs : []); },
      };
      if (name === "respects") return { where() { return makeEmptyQuery(); } };
      if (name === "kirari") return {
        doc: (id) => ({
          async get() {
            const row = byId.get(id);
            return row ? { id, exists: true, data: () => row.data } : { exists: false };
          },
        }),
        where() {
          let pageSize = 100;
          let cursorId = null;
          const query = {
            where() { return this; },
            orderBy() { return this; },
            limit(value) { pageSize = value; return this; },
            startAfter(doc) { cursorId = doc.id; return this; },
            async get() {
              const sorted = [...rows].sort((a, b) =>
                b.data.rankingScore - a.data.rankingScore ||
                b.data.publishedAt - a.data.publishedAt ||
                a.id.localeCompare(b.id));
              const start = cursorId ? sorted.findIndex((row) => row.id === cursorId) + 1 : 0;
              return { docs: sorted.slice(start, start + pageSize).map((row) => ({
                id: row.id, data: () => row.data,
              })) };
            },
          };
          return query;
        },
      };
      throw new Error("unexpected collection " + name);
    },
  };
  const domain = createKirariDomain({
    db, FieldValue: {}, HttpsError: TestHttpsError, bucket: {},
  });
  const first = await domain.getFeed({
    auth: { uid: "viewer" }, data: { type: "forYou", limit: 3 },
  });
  assert.deepEqual(first.items.map((item) => item.id), ["visible_0", "visible_1", "visible_2"]);
  assert.equal(first.hasMore, true);
  assert.equal(first.nextCursor.scanAfterId, "visible_2");
  const second = await domain.getFeed({
    auth: { uid: "viewer" }, data: { type: "forYou", limit: 3, ...first.nextCursor },
  });
  assert.deepEqual(second.items.map((item) => item.id), ["visible_3", "visible_4"]);
  assert.equal(second.hasMore, false);
});

test("playback retention ignores client claims and is capped by server elapsed time", () => {
  const progress = calculateVerifiedPlayback({
    previousCreditedSeconds: 4,
    lastHeartbeatAt: 1000,
    now: 6500,
    durationSeconds: 20,
  });
  assert.equal(progress.creditedSeconds, 9.5);
  assert.equal(progress.creditedDelta, 5.5);
  assert.equal(progress.verifiedPercent, 47.5);
  const capped = calculateVerifiedPlayback({
    previousCreditedSeconds: 2,
    lastHeartbeatAt: 1000,
    now: 30000,
    durationSeconds: 20,
  });
  assert.equal(capped.creditedSeconds, 12);
  const complete = calculateVerifiedPlayback({
    previousCreditedSeconds: 19,
    lastHeartbeatAt: 1000,
    now: 11000,
    durationSeconds: 20,
  });
  assert.equal(complete.creditedSeconds, 20);
  assert.equal(complete.verifiedPercent, 100);
});


test("Following feed queries followed creators in bounded chunks and paginates without gaps", async () => {
  const creatorIds = Array.from({ length: 31 }, (_, index) =>
    "creator_" + String(index).padStart(2, "0"));
  const follows = creatorIds.map((toUserId) => ({
    id: "follow_" + toUserId, data: () => ({ toUserId, value: 5 }),
  }));
  const rows = creatorIds.map((creatorId, index) => ({
    id: "reel_" + String(index).padStart(2, "0"),
    data: {
      creatorId, status: "published", moderationStatus: "approved",
      rankingScore: 100 - index, publishedAt: 1000 - index,
    },
  }));
  const byId = new Map(rows.map((row) => [row.id, row]));
  const chunksSeen = [];
  const makeEmptyQuery = (docs = []) => ({
    limit() { return this; },
    async get() { return { docs }; },
  });
  const db = {
    collection(name) {
      if (name === "users") return {
        doc: () => ({
          async get() { return { data: () => ({}) }; },
          collection: () => makeEmptyQuery(),
        }),
      };
      if (name === "friendships") return {
        where() { return makeEmptyQuery(); },
      };
      if (name === "respects") return {
        where() { return makeEmptyQuery(follows); },
      };
      if (name === "kirari") return {
        doc: (id) => ({
          id,
          exists: byId.has(id),
          data: () => byId.get(id)?.data,
          async get() {
            const row = byId.get(id);
            return row
              ? { id, exists: true, data: () => row.data }
              : { id, exists: false };
          },
        }),
        where(field, operator, value) {
          const filters = [];
          let cursor = null;
          let pageSize = 100;
          const query = {
            where(nextField, nextOperator, nextValue) {
              filters.push([nextField, nextOperator, nextValue]);
              if (nextField === "creatorId" && nextOperator === "in") {
                chunksSeen.push(nextValue.length);
              }
              return this;
            },
            orderBy() { return this; },
            startAfter(doc) { cursor = doc; return this; },
            limit(value) { pageSize = value; return this; },
            async get() {
              let selected = rows.filter((row) => filters.every(([key, op, expected]) => {
                if (op === "in") return expected.includes(row.data[key]);
                return row.data[key] === expected;
              }));
              selected.sort((a, b) =>
                b.data.rankingScore - a.data.rankingScore ||
                b.data.publishedAt - a.data.publishedAt ||
                a.id.localeCompare(b.id));
              if (cursor) {
                const cursorRow = byId.get(cursor.id);
                selected = selected.filter((row) =>
                  row.data.rankingScore < cursorRow.data.rankingScore ||
                  (row.data.rankingScore === cursorRow.data.rankingScore &&
                    (row.data.publishedAt < cursorRow.data.publishedAt ||
                      (row.data.publishedAt === cursorRow.data.publishedAt &&
                        row.id.localeCompare(cursor.id) > 0))));
              }
              return {
                docs: selected.slice(0, pageSize).map((row) => ({
                  id: row.id, exists: true, data: () => row.data,
                })),
              };
            },
          };
          if (field) query.where(field, operator, value);
          return query;
        },
      };
      throw new Error("unexpected collection " + name);
    },
  };
  const domain = createKirariDomain({
    db, FieldValue: {}, HttpsError: TestHttpsError, bucket: {},
  });
  const first = await domain.getFeed({
    auth: { uid: "viewer" }, data: { type: "following", limit: 3 },
  });
  assert.deepEqual(first.items.map((item) => item.id), ["reel_00", "reel_01", "reel_02"]);
  assert.equal(first.hasMore, true);
  assert.equal(first.nextCursor.scanAfterId, "reel_02");
  assert.ok(chunksSeen.length >= 2);
  assert.ok(chunksSeen.every((size) => size > 0 && size <= 30));

  const second = await domain.getFeed({
    auth: { uid: "viewer" }, data: { type: "following", limit: 3, ...first.nextCursor },
  });
  assert.deepEqual(second.items.map((item) => item.id), ["reel_03", "reel_04", "reel_05"]);
  assert.equal(second.nextCursor.scanAfterId, "reel_05");
  assert.equal(new Set([
    ...first.items.map((item) => item.id),
    ...second.items.map((item) => item.id),
  ]).size, 6);
});


test("saved Kirari reels paginate with a document cursor and never repeat entries", async () => {
  const savedIds = ["saved_1", "saved_2", "saved_3", "saved_4", "saved_5"];
  const savedById = new Map(savedIds.map((id) => [id, {
    id, exists: true, data: () => ({ savedAt: id }),
  }]));
  const reelById = new Map(savedIds.map((id) => [id, {
    id,
    exists: true,
    data: () => ({
      creatorId: "creator_" + id,
      status: "published",
      moderationStatus: "approved",
      caption: id,
    }),
  }]));
  const savedCollection = {
    doc(id) {
      return {
        async get() { return savedById.get(id) || { id, exists: false }; },
      };
    },
    orderBy() {
      let pageSize = 0;
      let cursorId = null;
      const query = {
        startAfter(snapshot) { cursorId = snapshot.id; return this; },
        limit(value) { pageSize = value; return this; },
        async get() {
          const start = cursorId ? savedIds.indexOf(cursorId) + 1 : 0;
          return {
            docs: savedIds.slice(start, start + pageSize)
              .map((id) => savedById.get(id)),
          };
        },
      };
      return query;
    },
  };
  const db = {
    collection(name) {
      if (name === "users") return {
        doc: () => ({ collection: (sub) => {
          assert.equal(sub, "kirariSaved");
          return savedCollection;
        } }),
      };
      if (name === "kirari") return {
        doc: (id) => ({
          async get() { return reelById.get(id) || { id, exists: false }; },
        }),
      };
      if (name === "friendships") return {
        doc: (id) => ({ async get() { return { id, exists: false }; } }),
      };
      if (name === "public_profiles") return {
        doc: (id) => ({ async get() { return { id, exists: false }; } }),
      };
      throw new Error("unexpected collection " + name);
    },
  };
  const domain = createKirariDomain({
    db, FieldValue: {}, HttpsError: TestHttpsError, bucket: {},
  });
  const first = await domain.getSavedReels({
    auth: { uid: "viewer" }, data: { limit: 2 },
  });
  assert.deepEqual(first.items.map((item) => item.id), ["saved_1", "saved_2"]);
  assert.equal(first.hasMore, true);
  assert.equal(first.nextCursor, "saved_2");

  const second = await domain.getSavedReels({
    auth: { uid: "viewer" }, data: { limit: 2, cursor: first.nextCursor },
  });
  assert.deepEqual(second.items.map((item) => item.id), ["saved_3", "saved_4"]);
  assert.equal(second.hasMore, true);
  assert.equal(second.nextCursor, "saved_4");

  const third = await domain.getSavedReels({
    auth: { uid: "viewer" }, data: { limit: 2, cursor: second.nextCursor },
  });
  assert.deepEqual(third.items.map((item) => item.id), ["saved_5"]);
  assert.equal(third.hasMore, false);
  assert.equal(third.nextCursor, "saved_5");
  assert.equal(new Set([
    ...first.items, ...second.items, ...third.items,
  ].map((item) => item.id)).size, 5);
});

test("saved Kirari pagination rejects a cursor that is not owned by the viewer", async () => {
  const db = {
    collection(name) {
      if (name === "users") return {
        doc: () => ({ collection: () => ({
          doc: (id) => ({ async get() { return { id, exists: false }; } }),
          orderBy() { return { startAfter() { return this; }, limit() { return this; } }; },
        }) }),
      };
      throw new Error("database should not be queried beyond the saved cursor");
    },
  };
  const domain = createKirariDomain({
    db, FieldValue: {}, HttpsError: TestHttpsError, bucket: {},
  });
  await assert.rejects(
    domain.getSavedReels({
      auth: { uid: "viewer" }, data: { limit: 2, cursor: "foreign_or_deleted_cursor" },
    }),
    (error) => error.code === "invalid-argument",
  );
});
