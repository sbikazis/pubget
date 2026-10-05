"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createEditsDomain } = require("../src/editsDomain");
const { utcDayKey } = require("../src/editUploadQuota");
const { EDIT_UPLOAD_QUOTA } = require("../src/editsConfig");

/**
 * Teach a store-backed fake the Firestore transaction API.
 *
 * The upload-quota reservation is a read-and-increment transaction, so the
 * double must actually SERIALIZE transactions. A fake that ran them
 * concurrently let three simultaneous uploads all read `count = 0` and all be
 * admitted — the quota race protection was silently untested. Chaining onto a
 * single promise reproduces Firestore's commit-one-at-a-time behaviour.
 */
function withTransactions(db) {
  let tail = Promise.resolve();
  db.runTransaction = (updateFn) => {
    const run = tail.then(() => updateFn({
      async get(ref) {
        const data = db.store.get(ref.path);
        return { id: ref.id, exists: data !== undefined, data: () => data };
      },
      set(ref, data, options = {}) {
        const current = options.merge ? (db.store.get(ref.path) || {}) : {};
        db.store.set(ref.path, { ...current, ...data });
      },
      create(ref, data) {
        db.store.set(ref.path, { ...data });
      },
      delete(ref) {
        db.store.delete(ref.path);
      },
      update(ref, data) {
        db.store.set(ref.path, { ...(db.store.get(ref.path) || {}), ...data });
      },
    }));
    // Keep the chain alive even if this transaction rejects.
    tail = run.then(() => {}, () => {});
    return run;
  };
  return db;
}

function createFakeDb() {
  const store = new Map();
  let auto = 0;
  return withTransactions({
    store,
    collection(name) {
      return {
        doc(id) {
          const resolvedId = id || `auto-${++auto}`;
          const path = `${name}/${resolvedId}`;
          return {
            id: resolvedId,
            path,
            async create(data) {
              store.set(path, { ...data });
            },
          };
        },
      };
    },
  });
}

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function handlers() {
  return createEditsDomain({
    db: {},
    FieldValue: {},
    HttpsError: TestHttpsError,
  });
}

test("edit mutations reject unauthenticated requests before database access", async () => {
  for (const [handler, data] of [
    ["startUpload", {}],
    ["repost", { editId: "e1" }],
    ["deleteEdit", { editId: "e1" }],
    ["like", { editId: "e1" }],
    ["comment", { editId: "e1", text: "hello" }],
    ["recordView", { editId: "e1", watchPercent: 50, watchSeconds: 3 }],
    ["signal", { editId: "e1", type: "share" }],
    ["commentAction", { editId: "e1", commentId: "c1", action: "like" }],
    ["getEditFeed", {}],
    ["retryProcessing", { editId: "e1" }],
    ["finalizeUpload", { editId: "e1" }],
  ]) {
    await assert.rejects(
      handlers()[handler]({ data }),
      (error) => error.code === "unauthenticated",
    );
  }
});

test("startUpload ignores client moderation fields and starts pending", async () => {
  const db = createFakeDb();
  const domain = createEditsDomain({
    db,
    FieldValue: { serverTimestamp: () => "now" },
    HttpsError: TestHttpsError,
  });
  const started = await domain.startUpload({
    auth: { uid: "alice" },
    data: {
      caption: "Clean edit",
      animeTag: "one_piece",
      moderationStatus: "approved",
      moderationReason: "forged",
      status: "published",
    },
  });
  const stored = db.store.get(`edits/${started.editId}`);
  assert.equal(stored.status, "uploading");
  assert.equal(stored.moderationStatus, "pending");
  assert.equal(stored.moderationReason, null);
  assert.equal(stored.caption, "Clean edit");
  assert.equal(stored.schemaVersion, 2);
  assert.equal(stored.originalCreatorId, "alice");
  assert.equal(stored.originalStoragePath, `edits/alice/${started.editId}.mp4`);
  assert.equal(stored.counters.views, 0);
});

test("view and signal validation rejects client-controlled invalid values", async () => {
  await assert.rejects(
    handlers().recordView({
      auth: { uid: "alice" },
      data: { editId: "e1", watchPercent: 200, watchSeconds: 3 },
    }),
    (error) => error.code === "invalid-argument",
  );
  await assert.rejects(
    handlers().signal({
      auth: { uid: "alice" },
      data: { editId: "e1", type: "invented" },
    }),
    (error) => error.code === "invalid-argument",
  );
});
function createMutableDb(seed = {}) {
  const store = new Map(Object.entries(seed));
  return withTransactions({
    store,
    collection(name) {
      return {
        doc(id) {
          const path = `${name}/${id}`;
          return {
            id,
            path,
            async get() {
              const data = store.get(path);
              return { exists: Boolean(data), data: () => data };
            },
            async create(data) {
              store.set(path, { ...data });
            },
            async set(data) {
              store.set(path, { ...data });
            },
            async delete() {
              store.delete(path);
            },
            async update(data) {
              const current = store.get(path) || {};
              store.set(path, { ...current, ...data });
            },
            collection(sub) {
              const prefix = `${name}/${id}/${sub}/`;
              return {
                doc(childId) {
                  const childPath = `${prefix}${childId}`;
                  return {
                    id: childId,
                    path: childPath,
                    async get() {
                      const data = store.get(childPath);
                      return {
                        id: childId,
                        exists: data !== undefined,
                        data: () => data,
                      };
                    },
                    async set(data) {
                      store.set(childPath, { ...data });
                    },
                    async create(data) {
                      store.set(childPath, { ...data });
                    },
                    async delete() {
                      store.delete(childPath);
                    },
                  };
                },
                async get() {
                  const rows = [...store.entries()]
                    .filter(([p]) => p.startsWith(prefix))
                    .map(([p, data]) => ({ id: p.slice(prefix.length), data }));
                  return { docs: rows.map((r) => ({ id: r.id, data: () => r.data })) };
                },
                orderBy(field, direction = "asc") {
                  const readRows = () =>
                    [...store.entries()]
                      .filter(([p]) => p.startsWith(prefix))
                      .map(([p, data]) => ({
                        id: p.slice(prefix.length),
                        path: p,
                        data,
                      }));
                  const state = { field, direction, limit: null, cursorId: null };
                  const api = {
                    orderBy(nextField, nextDirection = "asc") {
                      state.field = nextField;
                      state.direction = nextDirection;
                      return api;
                    },
                    // Mirrors the production paging pattern: the cursor is a
                    // document snapshot, and the query resumes strictly after
                    // it. Without this the fake silently replayed page one.
                    startAfter(cursorSnap) {
                      const raw = cursorSnap && (cursorSnap.id || cursorSnap.path);
                      if (typeof raw !== "string") {
                        state.cursorId = null;
                      } else if (raw.startsWith(prefix)) {
                        state.cursorId = raw.slice(prefix.length);
                      } else {
                        state.cursorId = raw;
                      }
                      return api;
                    },
                    limit(value) {
                      state.limit = value;
                      return api;
                    },
                    async get() {
                      let list = readRows();
                      if (state.field) {
                        const sign = state.direction === "desc" ? -1 : 1;
                        list = list.slice().sort((a, b) => {
                          const left = a.data[state.field];
                          const right = b.data[state.field];
                          if (left === right) {
                            if (a.id === b.id) return 0;
                            return a.id < b.id ? -sign : sign;
                          }
                          if (left === undefined || left === null) return 1;
                          if (right === undefined || right === null) return -1;
                          return left < right ? -sign : sign;
                        });
                      }
                      if (state.cursorId) {
                        const index = list.findIndex((row) => row.id === state.cursorId);
                        list = index >= 0 ? list.slice(index + 1) : [];
                      }
                      if (state.limit != null) list = list.slice(0, state.limit);
                      return {
                        docs: list.map((r) => ({
                          id: r.id,
                          path: r.path,
                          data: () => r.data,
                        })),
                      };
                    },
                  };
                  return api;
                },
              };
            },
          };
        },
      };
    },
  });
}

test("finalizeUpload and retryProcessing recover stuck uploading/processing", async () => {
  const db = createMutableDb({
    "edits/e1": {
      creatorId: "alice",
      status: "uploading",
      originalStoragePath: "edits/alice/e1.mp4",
      videoPath: "edits/alice/e1.mp4",
    },
  });
  const calls = [];
  const domain = createEditsDomain({
    db,
    FieldValue: { serverTimestamp: () => "now" },
    HttpsError: TestHttpsError,
    processEdit: async (event) => {
      calls.push(event.data.name);
      db.store.set("edits/e1", {
        ...db.store.get("edits/e1"),
        status: "published",
      });
    },
    bucket: {
      file() {
        return {
          async exists() {
            return [true];
          },
          async getMetadata() {
            return [{ contentType: "video/mp4", size: 2048 }];
          },
        };
      },
    },
  });

  const finalized = await domain.finalizeUpload({
    auth: { uid: "alice" },
    data: { editId: "e1" },
  });
  assert.equal(finalized.ok, true);
  assert.equal(finalized.status, "processing");
  // Processing is kicked without awaiting — flush the microtask queue.
  await new Promise((resolve) => setImmediate(resolve));
  assert.deepEqual(calls, ["edits/alice/e1.mp4"]);
  assert.equal(db.store.get("edits/e1").status, "published");

  db.store.set("edits/e1", {
    creatorId: "alice",
    status: "processing",
    originalStoragePath: "edits/alice/e1.mp4",
    videoPath: "edits/alice/e1.mp4",
  });
  const retried = await domain.retryProcessing({
    auth: { uid: "alice" },
    data: { editId: "e1" },
  });
  assert.equal(retried.ok, true);
  assert.equal(calls.length, 2);
});

test("finalizeUpload rejects non-owners", async () => {
  const db = createMutableDb({
    "edits/e1": {
      creatorId: "alice",
      status: "uploading",
      originalStoragePath: "edits/alice/e1.mp4",
    },
  });
  const domain = createEditsDomain({
    db,
    FieldValue: { serverTimestamp: () => "now" },
    HttpsError: TestHttpsError,
  });
  await assert.rejects(
    domain.finalizeUpload({ auth: { uid: "mallory" }, data: { editId: "e1" } }),
    (error) => error.code === "permission-denied",
  );
});

// ---------------------------------------------------------------------------
// Feed candidate selection. The fake db below records every query it receives so
// the tests can assert on the *clauses*, not just the returned rows. A prior
// version fetched a global top-200 and filtered it in memory, which silently
// starved scoped feeds; these tests fail if scope is not pushed into the query.
// ---------------------------------------------------------------------------

function createFeedDb(reels, extra = {}) {
  const store = new Map(Object.entries(extra));
  for (const reel of reels) store.set(`edits/${reel.id}`, reel);
  const queries = [];
  const compare = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

  const apply = (rows, q) => {
    let out = rows;
    for (const f of q.filters) {
      out = out.filter((row) => {
        const value = row.data[f.field];
        if (f.op === "==") return value === f.value;
        if (f.op === "array-contains") return Array.isArray(value) && value.includes(f.value);
        if (f.op === "in") return f.value.includes(value);
        return false;
      });
    }
    for (const o of q.orders) {
      const sign = o.direction === "desc" ? -1 : 1;
      out = [...out].sort((a, b) => sign * compare(a.data[o.field], b.data[o.field]));
    }
    return q.limit == null ? out : out.slice(0, q.limit);
  };

  const q = (state, collection = "edits") => {
    const api = {
      where(field, op, value) {
        state.filters.push({ field, op, value });
        return api;
      },
      orderBy(field, direction) {
        state.orders.push({ field, direction });
        return api;
      },
      limit(n) {
        state.limit = n;
        return api;
      },
      async get() {
        queries.push({ filters: [...state.filters], orders: [...state.orders], limit: state.limit });
        const prefix = `${collection}/`;
        const rows = [...store.entries()]
          .filter(([path]) => path.startsWith(prefix) && !path.slice(prefix.length).includes("/"))
          .map(([path, data]) => ({ id: path.slice(prefix.length), data }));
        return { docs: apply(rows, state).map((r) => ({ id: r.id, data: () => r.data })) };
      },
    };
    return api;
  };

  const db = {
    store,
    queries,
    collection(name) {
      return {
        doc(id) {
          const path = `${name}/${id}`;
          return {
            id,
            path,
            async get() {
              const data = store.get(path);
              return { id, exists: store.has(path), data: () => data };
            },
            async create(data) {
              store.set(path, { ...data });
            },
            async set(data) {
              store.set(path, { ...data });
            },
            async delete() {
              store.delete(path);
            },
            async update(data) {
              store.set(path, { ...(store.get(path) || {}), ...data });
            },
            collection(sub) {
              const subCollection = db.collection(`${name}/${id}/${sub}`);
              return {
                ...subCollection,
                async get() {
                  const rows = [...store.entries()]
                    .filter(([p]) => p.startsWith(`${name}/${id}/${sub}/`))
                    .map(([p, data]) => ({ id: p.slice(`${name}/${id}/${sub}/`.length), data }));
                  return { docs: rows.map((r) => ({ id: r.id, data: () => r.data })) };
                },
                async create(data) {
                  store.set(`${name}/${id}/${sub}/${data.id || 'auto'}`, { ...data });
                },
                async set(data) {
                  store.set(path, { ...data });
                },
                async delete() {
                  store.delete(path);
                },
                where(field, op, value) {
                  return q({ filters: [{ field, op, value }], orders: [], limit: null }, name);
                },
              };
            },
          };
        },
        where(field, op, value) {
          return q({ filters: [{ field, op, value }], orders: [], limit: null }, name);
        },
      };
    },
  };
  return db;
}

function reel(id, extra = {}) {
  return {
    id,
    creatorId: "creator",
    status: "published",
    score: 10,
    createdAt: new Date(Date.UTC(2026, 0, 10)),
    ...extra,
  };
}

function feedDomain(db) {
  return createEditsDomain({
    db,
    // `increment` is recorded as an opaque marker: the fake store cannot apply
    // deltas, and these tests assert on saved-list shape, not on counters.
    FieldValue: {
      serverTimestamp: () => "now",
      increment: (amount) => ({ __increment: amount }),
      arrayUnion: (...values) => ({ __arrayUnion: values }),
    },
    HttpsError: TestHttpsError,
  });
}

test("hashtag feed filters by hashtag in the query, not by trimming a global top-200", async () => {
  // 300 unrelated high-score Reels would previously fill the whole candidate
  // window and hide the tagged Reel completely.
  const reels = Array.from({ length: 300 }, (_, i) =>
    reel(`noise-${i}`, { score: 1000 - i }),
  );
  reels.push(reel("tagged", { hashtags: ["onepiece"], score: 1 }));
  const db = createFeedDb(reels);

  const page = await feedDomain(db).getEditFeed({
    auth: { uid: "alice" },
    data: { hashtag: "#OnePiece", feedType: "trending" },
  });

  assert.ok(
    page.items.some((item) => item.id === "tagged"),
    "a Reel outside the global top-200 must still appear in its own hashtag feed",
  );
  const clause = db.queries.flatMap((q) => q.filters).find(
    (f) => f.field === "hashtags" && f.op === "array-contains",
  );
  assert.ok(clause, "hashtag scope must reach Firestore");
  assert.equal(clause.value, "onepiece", "hashtag is normalised to lower case without #");
  assert.ok(page.items.every((item) => (item.hashtags || []).includes("onepiece")));
});

test("creator, anime, character and audio scopes each reach the query", async () => {
  const scopes = [
    { field: "creatorId", op: "==", value: "alice", data: { creatorId: "alice" } },
    { field: "animeId", op: "==", value: "one_piece", data: { animeId: "one_piece" } },
    { field: "characterIds", op: "array-contains", value: "luffy", data: { characterIds: ["luffy"] } },
    { field: "audioId", op: "==", value: "a1", data: { audioId: "a1" } },
  ];
  for (const scope of scopes) {
    const db = createFeedDb([reel("match", scope.data), reel("other", {})]);
    const page = await feedDomain(db).getEditFeed({
      auth: { uid: "alice" },
      data: { [scope.field.replace("Ids", "Id").replace("audioId", "audioId")]: scope.value },
    });
    const clause = db.queries.flatMap((q) => q.filters).find((f) => f.field === scope.field);
    assert.ok(clause, `${scope.field} scope must reach Firestore`);
    assert.deepEqual([clause.op, clause.value], [scope.op, scope.value]);
    assert.ok(page.items.every((item) => item.id === "match"));
  }
});

test("Following queries followed creators instead of filtering the global feed", async () => {
  const db = createFeedDb(
    [
      reel("popular-stranger", { creatorId: "stranger", score: 9999 }),
      reel("followed", { creatorId: "friend", score: 1 }),
    ],
    {
      "respects/r1": { fromUserId: "alice", toUserId: "friend", value: 10 },
    },
  );

  const page = await feedDomain(db).getEditFeed({
    auth: { uid: "alice" },
    data: { feedType: "following" },
  });

  assert.deepEqual(page.items.map((item) => item.id), ["followed"]);
  const clause = db.queries.flatMap((q) => q.filters).find(
    (f) => f.field === "creatorId" && f.op === "in",
  );
  assert.ok(clause, "Following must constrain creatorId in the query");
  assert.deepEqual(clause.value, ["friend"]);
});

test("Following is genuinely empty when the viewer follows nobody", async () => {
  const db = createFeedDb([reel("a", { creatorId: "stranger", score: 9999 })]);
  const page = await feedDomain(db).getEditFeed({
    auth: { uid: "alice" },
    data: { feedType: "following" },
  });
  assert.deepEqual(page.items, []);
});

test("Following splits creatorId 'in' queries into chunks of at most 30", async () => {
  const followed = {};
  const reels = [];
  for (let i = 0; i < 65; i += 1) {
    followed[`respects/r${i}`] = { fromUserId: "alice", toUserId: `c${i}`, value: 10 };
    reels.push(reel(`r${i}`, { creatorId: `c${i}` }));
  }
  const db = createFeedDb(reels, followed);

  const page = await feedDomain(db).getEditFeed({
    auth: { uid: "alice" },
    data: { feedType: "following", limit: 12 },
  });

  const inClauses = db.queries.flatMap((q) => q.filters).filter((f) => f.op === "in");
  assert.ok(inClauses.length >= 3, `expected chunked queries, got ${inClauses.length}`);
  for (const clause of inClauses) {
    assert.ok(clause.value.length <= 30, "Firestore caps 'in' at 30 values");
  }
  const ids = new Set(inClauses.flatMap((c) => c.value));
  assert.equal(ids.size, 65, "every followed creator must be queried");
  assert.equal(page.items.length, 12);
});

test("trending reads the newest published slice instead of the top-scored one", async () => {
  const db = createFeedDb([
    reel("old-hot", { score: 999, createdAt: new Date(Date.UTC(2020, 0, 1)), qualifiedViewsCount: 900 }),
    reel("new-cool", { score: 1, createdAt: new Date(Date.UTC(2026, 0, 14)), qualifiedViewsCount: 40 }),
  ]);

  await feedDomain(db).getEditFeed({ auth: { uid: "alice" }, data: { feedType: "trending" } });

  const trendingQuery = db.queries[db.queries.length - 1];
  assert.deepEqual(
    trendingQuery.orders.map((o) => o.field),
    ["createdAt"],
    "trending must not be pinned to the stored For You score",
  );
});

test("an unknown feed type degrades to For You instead of throwing", async () => {
  const db = createFeedDb([reel("a")]);
  const page = await feedDomain(db).getEditFeed({
    auth: { uid: "alice" },
    data: { feedType: "invented" },
  });
  assert.equal(page.items.length, 1);
  const feedQuery = db.queries.find((q) => q.filters.some((f) => f.field === "status"));
  assert.deepEqual(feedQuery.orders.map((o) => o.field), ["score", "createdAt"]);
});

test("startUpload refuses an Edit that points at a missing sound track", async () => {
  const db = createAudioAwareDb();
  const domain = createEditsDomain({
    db,
    FieldValue: { serverTimestamp: () => "now" },
    HttpsError: TestHttpsError,
  });
  await assert.rejects(
    domain.startUpload({
      auth: { uid: "alice" },
      data: { caption: "Song", animeTag: "one_piece", audioId: "ghost" },
    }),
    (error) =>
      error.code === "failed-precondition" &&
      /no longer exists/.test(error.message),
  );
});

test("startUpload refuses an Edit whose sound track is still processing", async () => {
  const db = createAudioAwareDb({ audios: { pendingTrack: { status: "processing" } } });
  const domain = createEditsDomain({
    db,
    FieldValue: { serverTimestamp: () => "now" },
    HttpsError: TestHttpsError,
  });
  await assert.rejects(
    domain.startUpload({
      auth: { uid: "alice" },
      data: { caption: "Song", animeTag: "one_piece", audioId: "pendingTrack" },
    }),
    (error) =>
      error.code === "failed-precondition" &&
      /still processing/.test(error.message),
  );
});

test("startUpload stores a ready sound track id verbatim", async () => {
  const db = createAudioAwareDb({ audios: { track1: { status: "ready" } } });
  const domain = createEditsDomain({
    db,
    FieldValue: { serverTimestamp: () => "now" },
    HttpsError: TestHttpsError,
  });
  const started = await domain.startUpload({
    auth: { uid: "alice" },
    data: { caption: "Song", animeTag: "one_piece", audioId: "track1" },
  });
  const stored = db.store.get(`edits/${started.editId}`);
  assert.equal(stored.audioId, "track1");
});

// §15.2 upload quota. Enforced server-side because the client pre-flight is
// advisory and the callable is directly reachable.
test("startUpload enforces the daily quota and reserves a slot per upload", async () => {
  const db = createFakeDb();
  const domain = createEditsDomain({
    db,
    FieldValue: { serverTimestamp: () => "now" },
    HttpsError: TestHttpsError,
  });
  const today = new Date();
  const quotaPath = `editUploadQuota/alice_${utcDayKey(today)}`;

  const first = await domain.startUpload({
    auth: { uid: "alice" },
    data: { caption: "one", animeTag: "one_piece" },
  });
  assert.equal(db.store.get(quotaPath).count, 1);
  assert.equal(first.quotaRemaining, EDIT_UPLOAD_QUOTA.dailyUploads - 1);

  // Burn the rest of the allowance.
  for (let i = 1; i < EDIT_UPLOAD_QUOTA.dailyUploads; i += 1) {
    await domain.startUpload({
      auth: { uid: "alice" },
      data: { caption: `fill ${i}`, animeTag: "one_piece" },
    });
  }
  assert.equal(db.store.get(quotaPath).count, EDIT_UPLOAD_QUOTA.dailyUploads);

  await assert.rejects(
    domain.startUpload({
      auth: { uid: "alice" },
      data: { caption: "one too many", animeTag: "one_piece" },
    }),
    (error) => error.code === "resource-exhausted" && /daily upload limit/i.test(error.message),
  );
  // A refused upload must not create an edit or consume a slot.
  assert.equal(db.store.get(quotaPath).count, EDIT_UPLOAD_QUOTA.dailyUploads);
});

test("upload quota is per creator, not global", async () => {
  const db = createFakeDb();
  const domain = createEditsDomain({
    db,
    FieldValue: { serverTimestamp: () => "now" },
    HttpsError: TestHttpsError,
  });
  for (let i = 0; i < EDIT_UPLOAD_QUOTA.dailyUploads; i += 1) {
    await domain.startUpload({
      auth: { uid: "alice" },
      data: { caption: `a${i}`, animeTag: "one_piece" },
    });
  }
  // Alice is blocked, bob is untouched.
  await assert.rejects(
    domain.startUpload({ auth: { uid: "alice" }, data: { caption: "x", animeTag: "one_piece" } }),
    (error) => error.code === "resource-exhausted",
  );
  const bob = await domain.startUpload({
    auth: { uid: "bob" },
    data: { caption: "bob", animeTag: "one_piece" },
  });
  assert.ok(bob.editId);
});

test("a rejected upload does not consume quota", async () => {
  const db = createFakeDb();
  const domain = createEditsDomain({
    db,
    FieldValue: { serverTimestamp: () => "now" },
    HttpsError: TestHttpsError,
  });
  // Invalid payload is rejected before any reservation is taken.
  await assert.rejects(
    domain.startUpload({ auth: { uid: "alice" }, data: { caption: 5 } }),
  );
  assert.equal(db.store.size, 0);
});

// One domain object serves every request, so quota state must never be stashed
// on the instance. This used to return a single shared `remaining` value.
test("concurrent uploads each report their own remaining quota", async () => {
  const db = createFakeDb();
  const domain = createEditsDomain({
    db,
    FieldValue: { serverTimestamp: () => "now" },
    HttpsError: TestHttpsError,
  });
  const results = await Promise.all(
    [1, 2, 3].map((i) => domain.startUpload({
      auth: { uid: "alice" },
      data: { caption: `c${i}`, animeTag: "one_piece" },
    })),
  );
  const remaining = results.map((result) => result.quotaRemaining).sort((a, b) => a - b);
  assert.deepEqual(
    remaining,
    [
      EDIT_UPLOAD_QUOTA.dailyUploads - 3,
      EDIT_UPLOAD_QUOTA.dailyUploads - 2,
      EDIT_UPLOAD_QUOTA.dailyUploads - 1,
    ],
    'each caller must get its own post-reservation remaining count',
  );
  // The transaction must serialize: three uploads consume exactly three slots.
  const quotaPath = `editUploadQuota/alice_${utcDayKey(new Date())}`;
  assert.equal(db.store.get(quotaPath).count, 3);
});

function createAudioAwareDb({ audios = {} } = {}) {
  const store = new Map();
  for (const [id, data] of Object.entries(audios)) {
    store.set(`reelAudios/${id}`, { ...data, audioId: id });
  }
  let auto = 0;
  return withTransactions({
    store,
    collection(name) {
      return {
        doc(id) {
          const resolvedId = id || `auto-${++auto}`;
          const path = `${name}/${resolvedId}`;
          return {
            id: resolvedId,
            path,
            async create(data) {
              store.set(path, { ...data });
            },
            async get() {
              const found = store.get(path);
              return { exists: found !== undefined, data: () => found };
            },
          };
        },
      };
    },
  });
}

// §15 viewer visibility at the domain level.
//
// `blockUser` wrote `friendships.status == "blocked"` but `getEditFeed` never
// read it, so blocking someone did nothing in the Reels feed — the control only
// existed on the profile page.
test("getEditFeed removes a blocked creator from every scope", async () => {
  const db = createFeedDb([
    reel("mine", { creatorId: "alice" }),
    reel("blocked", { creatorId: "bob" }),
    reel("other", { creatorId: "carol" }),
  ], {
    "friendships/f1": {
      userIds: ["alice", "bob"],
      status: "blocked",
      blockedBy: "alice",
    },
  });

  const page = await feedDomain(db).getEditFeed({
    auth: { uid: "alice" },
    data: { feedType: "trending" },
  });

  const ids = page.items.map((item) => item.id);
  assert.equal(ids.includes("blocked"), false, "blocked creator must not appear");
  assert.deepEqual(ids.sort(), ["mine", "other"]);
});

test("getEditFeed removes a muted creator", async () => {
  const db = createFeedDb([
    reel("mine", { creatorId: "alice" }),
    reel("muted", { creatorId: "bob" }),
  ], {
    "reelMutes/alice/creators/bob": { creatorId: "bob", viewerId: "alice" },
  });

  const page = await feedDomain(db).getEditFeed({
    auth: { uid: "alice" },
    data: { feedType: "trending" },
  });
  assert.deepEqual(page.items.map((item) => item.id), ["mine"]);
});

test("a creator who blocked the viewer is also hidden", async () => {
  const db = createFeedDb([reel("theirs", { creatorId: "bob" })], {
    "friendships/f1": {
      userIds: ["alice", "bob"],
      status: "blocked",
      blockedBy: "bob",
    },
  });
  const page = await feedDomain(db).getEditFeed({
    auth: { uid: "alice" },
    data: { feedType: "trending" },
  });
  assert.equal(page.items.length, 0);
});

test("a pending friend request does not hide anyone from the feed", async () => {
  const db = createFeedDb([reel("theirs", { creatorId: "bob" })], {
    "friendships/f1": { userIds: ["alice", "bob"], status: "pending" },
  });
  const page = await feedDomain(db).getEditFeed({
    auth: { uid: "alice" },
    data: { feedType: "trending" },
  });
  assert.equal(page.items.length, 1);
});

test("block beats the following scope instead of leaking through it", async () => {
  // The `following` branch re-filters by creatorIds; a blocked creator must not
  // survive that second pass.
  const db = createFeedDb([
    reel("blocked", { creatorId: "bob" }),
    reel("kept", { creatorId: "carol" }),
  ], {
    "friendships/f1": {
      userIds: ["alice", "bob"],
      status: "blocked",
      blockedBy: "alice",
    },
    "respects/r1": { fromUserId: "alice", toUserId: "bob", value: 10 },
    "respects/r2": { fromUserId: "alice", toUserId: "carol", value: 10 },
  });

  const page = await feedDomain(db).getEditFeed({
    auth: { uid: "alice" },
    data: { feedType: "following" },
  });
  assert.deepEqual(page.items.map((item) => item.id), ["kept"]);
});

test("muteReelCreator writes then removes the viewer's own mute row", async () => {
  const db = createFeedDb([], { "users/bob": { uid: "bob" } });
  const domain = feedDomain(db);

  const muted = await domain.muteReelCreator({
    auth: { uid: "alice" },
    data: { creatorId: "bob" },
  });
  assert.equal(muted.muted, true);
  assert.equal(db.store.get("reelMutes/alice/creators/bob").creatorId, "bob");

  const unmuted = await domain.muteReelCreator({
    auth: { uid: "alice" },
    data: { creatorId: "bob", muted: false },
  });
  assert.equal(unmuted.muted, false);
  assert.equal(db.store.get("reelMutes/alice/creators/bob"), undefined);
});

test("muteReelCreator rejects self-mute and unknown creators", async () => {
  const db = createFeedDb([], { "users/bob": { uid: "bob" } });
  const domain = feedDomain(db);

  await assert.rejects(
    domain.muteReelCreator({ auth: { uid: "alice" }, data: { creatorId: "alice" } }),
    (error) => error.code === "failed-precondition",
  );
  await assert.rejects(
    domain.muteReelCreator({ auth: { uid: "alice" }, data: { creatorId: "ghost" } }),
    (error) => error.code === "not-found",
  );
  await assert.rejects(
    domain.muteReelCreator({ auth: { uid: "alice" }, data: {} }),
    (error) => error.code === "invalid-argument",
  );
  await assert.rejects(
    domain.muteReelCreator({ data: { creatorId: "bob" } }),
    (error) => error.code === "unauthenticated",
  );
});

// §15 saved Reels.
//
// `save` was a per-edit signal row that `unsave` DELETED, so there was no way
// to recover a user's saves: no collection, no callable, no rule, no screen.
test("save writes a retrievable saved-Reels item, unsave removes it", async () => {
  const db = createMutableDb({
    "edits/e1": {
      creatorId: "bob",
      status: "published",
      caption: "Luffy gear 5",
      videoUrl: "edits-processed/bob/e1.mp4",
      thumbnailUrl: "edits/bob/t_e1.jpg",
      durationSeconds: 12,
      likesCount: 40,
    },
  });
  const domain = feedDomain(db);

  await domain.signal({ auth: { uid: "alice" }, data: { editId: "e1", type: "save" } });
  const saved = db.store.get("savedReels/alice/items/e1");
  assert.ok(saved, "save must write a retrievable item");
  assert.equal(saved.editId, "e1");
  assert.equal(saved.creatorId, "bob");
  assert.equal(saved.caption, "Luffy gear 5");
  assert.equal(saved.videoUrl, "edits-processed/bob/e1.mp4");
  assert.equal(saved.durationSeconds, 12);

  await domain.signal({ auth: { uid: "alice" }, data: { editId: "e1", type: "unsave" } });
  assert.equal(db.store.get("savedReels/alice/items/e1"), undefined);
});

test("saved Reels are listable and scoped to the requesting viewer", async () => {
  const db = createMutableDb({
    "savedReels/alice/items/e1": { editId: "e1", creatorId: "bob", caption: "one" },
    "savedReels/alice/items/e2": { editId: "e2", creatorId: "carol", caption: "two" },
    "savedReels/bob/items/e3": { editId: "e3", creatorId: "carol", caption: "secret" },
  });
  const domain = feedDomain(db);

  const alice = await domain.listSavedReels({ auth: { uid: "alice" }, data: {} });
  assert.deepEqual(alice.items.map((i) => i.id).sort(), ["e1", "e2"]);

  const bob = await domain.listSavedReels({ auth: { uid: "bob" }, data: {} });
  assert.deepEqual(bob.items.map((i) => i.id), ["e3"]);

  await assert.rejects(
    domain.listSavedReels({ data: {} }),
    (error) => error.code === "unauthenticated",
  );
});

test("saving twice is idempotent and does not double-count", async () => {
  const db = createMutableDb({
    "edits/e1": { creatorId: "bob", status: "published" },
  });
  const domain = feedDomain(db);
  const signal = { auth: { uid: "alice" }, data: { editId: "e1", type: "save" } };
  await domain.signal(signal);
  await domain.signal(signal);
  const list = await domain.listSavedReels({ auth: { uid: "alice" }, data: {} });
  assert.equal(list.items.length, 1);
});

test("unsave without a prior save is a no-op, not a negative counter", async () => {
  const db = createMutableDb({ "edits/e1": { creatorId: "bob", status: "published" } });
  const domain = feedDomain(db);
  await domain.signal({ auth: { uid: "alice" }, data: { editId: "e1", type: "unsave" } });
  assert.equal(db.store.get("savedReels/alice/items/e1"), undefined);
});

test("non-save signals do not create saved-Reels items", async () => {
  const db = createMutableDb({ "edits/e1": { creatorId: "bob", status: "published" } });
  const domain = feedDomain(db);
  for (const type of ["share", "negative"]) {
    await domain.signal({ auth: { uid: "alice" }, data: { editId: "e1", type } });
  }
  const list = await domain.listSavedReels({ auth: { uid: "alice" }, data: {} });
  assert.equal(list.items.length, 0);
});

test("listSavedReels pages forward instead of replaying the first page", async () => {
  // Regression: the cursor was applied *after* the page was fetched, so it only
  // worked while the cursor happened to sit inside that page. Requesting page two
  // with the last id of page one returned page one again, forever.
  const saved = {};
  for (let i = 1; i <= 5; i += 1) {
    saved[`savedReels/alice/items/e${i}`] = {
      editId: `e${i}`,
      creatorId: "bob",
      savedAt: i,
    };
  }
  const domain = feedDomain(createMutableDb(saved));

  const first = await domain.listSavedReels({
    auth: { uid: "alice" },
    data: { limit: 2 },
  });
  assert.deepEqual(first.items.map((i) => i.id), ["e5", "e4"]);
  assert.equal(first.hasMore, true);

  const second = await domain.listSavedReels({
    auth: { uid: "alice" },
    data: { limit: 2, afterId: first.items[first.items.length - 1].id },
  });
  assert.deepEqual(second.items.map((i) => i.id), ["e3", "e2"]);
  assert.equal(second.hasMore, true);

  const third = await domain.listSavedReels({
    auth: { uid: "alice" },
    data: { limit: 2, afterId: second.items[second.items.length - 1].id },
  });
  assert.deepEqual(third.items.map((i) => i.id), ["e1"]);
  assert.equal(third.hasMore, false);

  // No id may ever repeat across pages.
  const seen = [
    ...first.items,
    ...second.items,
    ...third.items,
  ].map((i) => i.id);
  assert.equal(new Set(seen).size, seen.length);
});

test("listSavedReels with an unknown cursor returns the first page, not an empty one", async () => {
  const db = createMutableDb({
    "savedReels/alice/items/e1": { editId: "e1", creatorId: "bob", savedAt: 2 },
    "savedReels/alice/items/e2": { editId: "e2", creatorId: "bob", savedAt: 1 },
  });
  const domain = feedDomain(db);
  const list = await domain.listSavedReels({
    auth: { uid: "alice" },
    data: { afterId: "does-not-exist" },
  });
  assert.deepEqual(list.items.map((i) => i.id), ["e1", "e2"]);
});

test("a failed block read fails the feed closed instead of unblocking", async () => {
  // Regression: `loadHiddenCreatorIds` swallowed read errors and carried on with
  // an empty hidden set, which republished the very creators the viewer blocked.
  // An unavailable boundary read must surface as an error, not as "no blocks".
  const db = createFeedDb([reel("e1", { creatorId: "bob", publishedAt: 5 })], {
    "friendships/f1": { userIds: ["alice", "bob"], status: "blocked", blockedBy: "alice" },
  });
  const original = db.collection.bind(db);
  db.collection = (name) => {
    if (name === "friendships") {
      return {
        where() {
          return {
            async get() {
              throw new Error("firestore unavailable");
            },
          };
        },
      };
    }
    return original(name);
  };

  await assert.rejects(
    feedDomain(db).getEditFeed({ auth: { uid: "alice" }, data: {} }),
    (error) => /firestore unavailable/.test(String(error && error.message)),
    "a broken block read must reject rather than return unblocked content",
  );
});

test("a failed mute read fails the feed closed too", async () => {
  const db = createFeedDb([reel("e1", { creatorId: "bob", publishedAt: 5 })], {
    "reelMutes/alice/creators/bob": {},
  });
  const original = db.collection.bind(db);
  db.collection = (name) => {
    if (name === "reelMutes") {
      return {
        doc() {
          return {
            collection() {
              return {
                async get() {
                  throw new Error("mute read unavailable");
                },
              };
            },
          };
        },
      };
    }
    return original(name);
  };

  await assert.rejects(
    feedDomain(db).getEditFeed({ auth: { uid: "alice" }, data: {} }),
    (error) => /mute read unavailable/.test(String(error && error.message)),
  );
});

test("a healthy feed still works when both boundary reads succeed", async () => {
  // The counterpart to the two tests above: fail-closed must not turn a normal
  // read into a rejection.
  const db = createFeedDb(
    [reel("mine", { creatorId: "alice" }), reel("other", { creatorId: "carol" })],
    { "friendships/f1": { userIds: ["alice", "bob"], status: "blocked", blockedBy: "alice" } },
  );
  const page = await feedDomain(db).getEditFeed({
    auth: { uid: "alice" },
    data: { feedType: "trending" },
  });
  assert.deepEqual(page.items.map((i) => i.id).sort(), ["mine", "other"]);
});
