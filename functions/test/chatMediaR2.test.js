"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const Module = require("node:module");
const fsp = require("node:fs/promises");

const {
  createChatMediaDocumentProcessor,
  isChatR2Original,
  chatDerivativeKey,
} = require("../src/groupMediaPipeline");

function fakeDb() {
  const store = new Map();
  const writes = [];
  function doc(full) {
    return {
      async set(data, options) {
        const current = store.get(full) || {};
        store.set(full, options && options.merge ? { ...current, ...data } : data);
        writes.push({ path: full, data });
      },
    };
  }
  function collection(name) {
    return {
      doc(id) {
        const base = `${name}/${id}`;
        return {
          collection(sub) {
            return {
              doc(sid) {
                return doc(`${base}/${sub}/${sid}`);
              },
              where(field, _operator, value) {
                return {
                  limit() { return this; },
                  async get() {
                    const prefix = `${base}/${sub}/`;
                    const docs = [...store.entries()]
                      .filter(([path, data]) => path.startsWith(prefix) && data[field] === value)
                      .map(([path]) => ({ ref: { path } }));
                    return { empty: docs.length === 0, docs };
                  },
                };
              },
            };
          },
        };
      },
    };
  }
  return {
    store,
    writes,
    collection,
    batch() {
      const updates = [];
      return {
        update(ref, data) {
          updates.push({ ref, data });
        },
        async commit() {
          for (const update of updates) {
            const current = store.get(update.ref.path) || {};
            store.set(update.ref.path, { ...current, ...update.data });
            writes.push({ path: update.ref.path, data: update.data });
          }
        },
      };
    },
  };
}

function fakeBucket() {
  const uploads = [];
  return {
    uploads,
    file(key) {
      return {
        async download({ destination }) {
          await fsp.writeFile(destination, "fake-image-bytes");
          return [destination];
        },
      };
    },
    async upload(_localPath, options) {
      uploads.push(options.destination);
      return [{ name: options.destination }];
    },
  };
}

function withFakeSharp(run) {
  const originalLoad = Module._load;
  Module._load = function load(request) {
    if (request === "sharp") {
      return function sharp() {
        return {
          rotate() { return this; },
          resize() { return this; },
          jpeg() { return this; },
          async toFile() {},
          async metadata() { return { width: 640, height: 360 }; },
        };
      };
    }
    return originalLoad.apply(this, arguments);
  };
  return Promise.resolve().then(run).finally(() => {
    Module._load = originalLoad;
  });
}

test("R2 chat keys derive owned JPEG rendition keys only", () => {
  const original = "groups/g1/alice/2b1c.jpg";
  assert.equal(isChatR2Original(original), true);
  assert.equal(chatDerivativeKey(original, "thumb"), "groups/g1/alice/2b1c_thumb.jpg");
  assert.equal(chatDerivativeKey(original, "medium"), "groups/g1/alice/2b1c_medium.jpg");
  assert.equal(isChatR2Original("groups/g1/alice/2b1c_thumb.jpg"), false);
  assert.equal(isChatR2Original("images/alice/2b1c.jpg"), false);
  assert.equal(chatDerivativeKey("bad/key", "thumb"), null);
});

test("R2 image document gains derivatives without ever un-readying the media", async () => {
  await withFakeSharp(async () => {
    const db = fakeDb();
    const bucket = fakeBucket();
    const original = "groups/g1/alice/2b1c.jpg";
    const media = {
      mediaId: "m1",
      uploaderId: "alice",
      mediaType: "image",
      mediaBackend: "r2",
      originalPath: original,
      thumbnailPath: original,
      mediumPath: original,
      contentType: "image/jpeg",
      sizeBytes: 1024,
      status: "ready",
    };
    db.store.set("groups/g1/media/m1", { ...media });
    db.store.set("groups/g1/messages/msg1", { mediaId: "m1" });
    const process = createChatMediaDocumentProcessor({
      db,
      bucket,
      randomUUID: () => "x",
    });

    await process({
      params: { groupId: "g1", mediaId: "m1" },
      data: { data: () => media },
    });

    assert.deepEqual(bucket.uploads, [
      "groups/g1/alice/2b1c_thumb.jpg",
      "groups/g1/alice/2b1c_medium.jpg",
    ]);
    const stored = db.store.get("groups/g1/media/m1");
    assert.equal(stored.status, "ready");
    assert.equal(stored.thumbnailPath, "groups/g1/alice/2b1c_thumb.jpg");
    assert.equal(stored.mediumPath, "groups/g1/alice/2b1c_medium.jpg");
    assert.equal(stored.width, 640);
    assert.equal(stored.height, 360);
    assert.equal(db.store.get("groups/g1/messages/msg1").thumbnailUrl,
      "groups/g1/alice/2b1c_thumb.jpg");
    assert.equal(db.store.get("groups/g1/messages/msg1").mediaUrl,
      "groups/g1/alice/2b1c_medium.jpg");
    assert.equal(db.writes.some((write) => write.data.status === "processing"), false);
  });
});

test("legacy media documents are untouched", async () => {
  const db = fakeDb();
  const bucket = fakeBucket();
  const process = createChatMediaDocumentProcessor({ db, bucket, randomUUID: () => "x" });
  const result = await process({
    params: { chatId: "c1", mediaId: "m2" },
    data: { data: () => ({
      originalPath: "groups/c1/media/m2_original.jpg",
      contentType: "image/jpeg",
      uploaderId: "alice",
    }) },
  });
  assert.equal(result, null);
  assert.equal(bucket.uploads.length, 0);
  assert.equal(db.writes.length, 0);
});

test("R2 private-chat audio is finalized without transcoding", async () => {
  const db = fakeDb();
  const bucket = fakeBucket();
  const process = createChatMediaDocumentProcessor({ db, bucket, randomUUID: () => "x" });
  db.store.set("privateChats/5:alice:bob/media/a1", { status: "ready" });
  await process({
    params: { chatId: "5:alice:bob", mediaId: "a1" },
    data: { data: () => ({
      mediaBackend: "r2",
      originalPath: "privateChats/5:alice:bob/alice/voice.m4a",
      contentType: "audio/mp4",
      sizeBytes: 2048,
      uploaderId: "alice",
      status: "ready",
    }) },
  });
  const stored = db.store.get("privateChats/5:alice:bob/media/a1");
  assert.equal(stored.status, "ready");
  assert.equal(stored.mediaType, "audio");
  assert.equal(stored.maxDurationSeconds, 60);
  assert.equal(bucket.uploads.length, 0);
});

test("a key that does not belong to the uploader is rejected", async () => {
  const db = fakeDb();
  const bucket = fakeBucket();
  const process = createChatMediaDocumentProcessor({ db, bucket, randomUUID: () => "x" });
  const result = await process({
    params: { groupId: "g1", mediaId: "m3" },
    data: { data: () => ({
      mediaBackend: "r2",
      originalPath: "groups/g1/bob/2b1c.jpg",
      contentType: "image/jpeg",
      sizeBytes: 1024,
      uploaderId: "alice",
    }) },
  });
  assert.equal(result, null);
  assert.equal(bucket.uploads.length, 0);
});
