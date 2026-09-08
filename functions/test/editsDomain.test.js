"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createEditsDomain } = require("../src/editsDomain");

function createFakeDb() {
  const store = new Map();
  let auto = 0;
  return {
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
  };
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
  return {
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
            async update(data) {
              const current = store.get(path) || {};
              store.set(path, { ...current, ...data });
            },
          };
        },
      };
    },
  };
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
