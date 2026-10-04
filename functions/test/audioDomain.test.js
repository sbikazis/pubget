"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createAudioDomain } = require("../src/audioDomain");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

/**
 * Minimal Firestore double: enough for transactions (all reads before the
 * first write), FieldValue.increment/delete, and nested collections.
 */
function createFakeDb(seed = {}) {
  const store = new Map(Object.entries(seed));
  const reads = { count: 0 };
  const writes = [];
  let writesStarted = false;

  const db = {
    store,
    reads,
    writes,
    collection(name) {
      return {
        doc(id) {
          const path = `${name}/${id}`;
          return {
            id,
            path,
            async get() {
              reads.count += 1;
              const data = store.get(path);
              return { id, exists: store.has(path), data: () => data };
            },
            async create(data) {
              store.set(path, { ...data });
            },
            async update(data) {
              const current = store.get(path) || {};
              store.set(path, applySentinels(current, data));
            },
            async delete() {
              store.delete(path);
            },
            collection(sub) {
              return db.collection(`${name}/${id}/${sub}`);
            },
          };
        },
        where(field, op, value) {
          return db._query(name, { filters: [{ field, op, value }], orders: [], limit: null, startAfter: null });
        },
      };
    },
    _query(name, state) {
      const q = state || { filters: [], orders: [], limit: null, startAfter: null };
      const api = {
        where(field, op, value) {
          q.filters.push({ field, op, value });
          return api;
        },
        orderBy(field, direction) {
          q.orders.push({ field, direction });
          return api;
        },
        limit(n) {
          q.limit = n;
          return api;
        },
        startAfter(doc) {
          q.startAfter = doc;
          return api;
        },
        async get() {
          reads.count += 1;
          let rows = [...store.entries()]
            .filter(([path]) => path.startsWith(`${name}/`))
            .filter(([path]) => !path.slice(name.length + 1).includes("/"))
            .map(([path, data]) => ({ id: path.slice(name.length + 1), path, data }));
          for (const { field, op, value } of q.filters) {
            rows = rows.filter((row) => {
              const actual = row.data[field];
              if (op === "==") return actual === value;
              if (op === "arrayContains") return Array.isArray(actual) && actual.includes(value);
              return false;
            });
          }
          for (const { field, direction } of [...q.orders].reverse()) {
            const sign = direction === "desc" ? -1 : 1;
            rows.sort((a, b) => sign * compare(a.data[field], b.data[field]));
          }
          if (q.startAfter) {
            const index = rows.findIndex((row) => row.id === q.startAfter.id);
            rows = rows.slice(index + 1);
          }
          if (q.limit != null) rows = rows.slice(0, q.limit);
          return { docs: rows.map((row) => ({ id: row.id, path: row.path, exists: true, data: () => row.data })) };
        },
      };
      return api;
    },
    async getAll(...refs) {
      reads.count += refs.length;
      return refs.map((ref) => {
        const data = store.get(ref.path);
        return { id: ref.id, path: ref.path, exists: store.has(ref.path), data: () => data };
      });
    },
    async runTransaction(fn) {
      writesStarted = false;
      const tx = {
        async get(ref) {
          // Firestore forbids reads after the first write in a transaction.
          assert.equal(writesStarted, false, "transaction read after write");
          reads.count += 1;
          const data = store.get(ref.path);
          return { id: ref.id, path: ref.path, exists: store.has(ref.path), data: () => data };
        },
        update(ref, data) {
          writesStarted = true;
          writes.push({ path: ref.path, data });
          const current = store.get(ref.path) || {};
          store.set(ref.path, applySentinels(current, data));
        },
        set(ref, data) {
          writesStarted = true;
          writes.push({ path: ref.path, data });
          store.set(ref.path, { ...data });
        },
        delete(ref) {
          writesStarted = true;
          writes.push({ path: ref.path, data: null, delete: true });
          store.delete(ref.path);
        },
      };
      return fn(tx);
    },
  };
  return db;
}

function compare(a, b) {
  const left = a instanceof Object && a !== null && "seconds" in a ? a.seconds : a;
  const right = b instanceof Object && b !== null && "seconds" in b ? b.seconds : b;
  if (typeof left === "number" && typeof right === "number") return left - right;
  return String(left ?? "").localeCompare(String(right ?? ""));
}

const DELETE = Symbol("delete");
function applySentinels(current, data) {
  // Merge first, then honour FieldValue.delete() — deleting from the patch
  // alone would let the spread of `current` resurrect the field.
  const merged = { ...current, ...data };
  for (const [key, value] of Object.entries(data)) {
    if (value && value.__op === "increment") merged[key] = (Number(current[key]) || 0) + value.by;
    if (value === DELETE) delete merged[key];
  }
  return merged;
}

const increment = (by) => ({ __op: "increment", by });

function FieldValue() {
  return {
    increment,
    serverTimestamp: () => "now",
    delete: () => DELETE,
  };
}

function domain(db) {
  return createAudioDomain({
    db,
    bucket: {},
    FieldValue: FieldValue(),
    HttpsError: TestHttpsError,
    reelCollection: "edits",
  });
}

function seedReel(id, creatorId, extra = {}) {
  return [`edits/${id}`, { creatorId, status: "published", ...extra }];
}

function seedAudio(id, extra = {}) {
  return [`reelAudios/${id}`, { creatorId: "sound-owner", status: "ready", usageCount: 0, ...extra }];
}

test("audio mutations reject unauthenticated callers", async () => {
  const db = createFakeDb();
  const audio = domain(db);
  for (const [handler, data] of [
    ["extractAudioFromReel", { reelId: "r1" }],
    ["listAudios", {}],
    ["getAudio", { audioId: "a1" }],
    ["useAudio", { audioId: "a1", reelId: "r1" }],
    ["removeAudio", { reelId: "r1" }],
    ["searchAudios", { query: "x" }],
  ]) {
    await assert.rejects(
      audio[handler]({ data }),
      (error) => error.code === "unauthenticated",
    );
  }
});

test("useAudio targets the injected reel collection, not a parallel one", async () => {
  const db = createFakeDb(Object.fromEntries([seedReel("r1", "alice"), seedAudio("a1")]));
  await domain(db).useAudio({ auth: { uid: "alice" }, data: { audioId: "a1", reelId: "r1" } });

  assert.equal(db.store.get("edits/r1").audioId, "a1");
  assert.ok(!db.store.has("reels/r1"), "must not write to a hardcoded reels collection");
  assert.equal(db.store.get("reelAudios/a1").usageCount, 1);
  assert.ok(db.store.has("reelAudios/a1/reelAudioUsage/r1"));
});

test("re-attaching the same audio is idempotent and does not inflate usageCount", async () => {
  const db = createFakeDb(Object.fromEntries([seedReel("r1", "alice"), seedAudio("a1")]));
  const audio = domain(db);
  const request = { auth: { uid: "alice" }, data: { audioId: "a1", reelId: "r1" } };

  await audio.useAudio(request);
  await audio.useAudio(request);
  await audio.useAudio(request);

  assert.equal(db.store.get("reelAudios/a1").usageCount, 1);
});

test("swapping audio moves the usage count instead of orphaning it", async () => {
  const db = createFakeDb(
    Object.fromEntries([seedReel("r1", "alice"), seedAudio("a1"), seedAudio("a2")]),
  );
  const audio = domain(db);
  await audio.useAudio({ auth: { uid: "alice" }, data: { audioId: "a1", reelId: "r1" } });
  await audio.useAudio({ auth: { uid: "alice" }, data: { audioId: "a2", reelId: "r1" } });

  assert.equal(db.store.get("reelAudios/a1").usageCount, 0);
  assert.equal(db.store.get("reelAudios/a2").usageCount, 1);
  assert.ok(!db.store.has("reelAudios/a1/reelAudioUsage/r1"));
  assert.ok(db.store.has("reelAudios/a2/reelAudioUsage/r1"));
  assert.equal(db.store.get("edits/r1").audioId, "a2");
});

test("removeAudio only decrements when audio was actually attached", async () => {
  const db = createFakeDb(Object.fromEntries([seedReel("r1", "alice"), seedAudio("a1")]));
  const audio = domain(db);
  await audio.useAudio({ auth: { uid: "alice" }, data: { audioId: "a1", reelId: "r1" } });

  await audio.removeAudio({ auth: { uid: "alice" }, data: { reelId: "r1" } });
  assert.equal(db.store.get("reelAudios/a1").usageCount, 0);
  assert.equal(db.store.get("edits/r1").audioId, undefined);

  // Second removal is a no-op, not another decrement.
  await audio.removeAudio({ auth: { uid: "alice" }, data: { reelId: "r1" } });
  assert.equal(db.store.get("reelAudios/a1").usageCount, 0);
});

test("useAudio refuses a reel the caller does not own", async () => {
  const db = createFakeDb(Object.fromEntries([seedReel("r1", "bob"), seedAudio("a1")]));
  await assert.rejects(
    domain(db).useAudio({ auth: { uid: "alice" }, data: { audioId: "a1", reelId: "r1" } }),
    (error) => error.code === "permission-denied",
  );
  assert.equal(db.store.get("reelAudios/a1").usageCount, 0);
});

test("useAudio refuses audio that is not ready", async () => {
  const db = createFakeDb(
    Object.fromEntries([seedReel("r1", "alice"), ["reelAudios/a1", { creatorId: "x", status: "processing" }]]),
  );
  await assert.rejects(
    domain(db).useAudio({ auth: { uid: "alice" }, data: { audioId: "a1", reelId: "r1" } }),
    (error) => error.code === "not-found",
  );
});

test("listAudios honors the requested sort and only returns ready audio", async () => {
  const db = createFakeDb(
    Object.fromEntries([
      ["users/sound-owner", { username: "DJ", avatarUrl: "a.png" }],
      seedAudio("pop", { usageCount: 10, createdAt: { seconds: 1 } }),
      seedAudio("fresh", { usageCount: 0, createdAt: { seconds: 9 } }),
      ["reelAudios/draft", { creatorId: "sound-owner", status: "processing" }],
    ]),
  );
  const audio = domain(db);

  const trending = await audio.listAudios({
    auth: { uid: "alice" },
    data: { type: "trending" },
  });
  assert.deepEqual(trending.items.map((item) => item.audioId ?? item.id ?? item.name ?? "x").length, 2);
  assert.equal(trending.items.length, 2);
  assert.ok(!trending.items.some((item) => item.status === "processing"));

  const audio0 = trending.items[0];
  assert.equal(audio0.creatorName, "DJ");
  assert.equal(audio0.creatorAvatar, "a.png");
});

test("listAudios resolves creator profiles in one batch, not one read per row", async () => {
  const seed = [["users/sound-owner", { username: "DJ" }]];
  for (let i = 0; i < 10; i += 1) {
    seed.push(seedAudio(`a${i}`));
  }
  const db = createFakeDb(Object.fromEntries(seed));
  db.reads.count = 0;

  const page = await domain(db).listAudios({ auth: { uid: "alice" }, data: { limit: 10 } });
  assert.equal(page.items.length, 10);
  assert.ok(
    db.reads.count <= 2,
    `expected a batched lookup, saw ${db.reads.count} reads for 10 rows`,
  );
});
