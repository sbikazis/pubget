"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { ORIGINAL_PATTERN, createGroupMediaPipeline } = require("../src/groupMediaPipeline");

test("media pipeline processes original group and private-chat uploads only", () => {
  assert.deepEqual(
    ORIGINAL_PATTERN.exec("groups/g1/media/m1_original.jpg").slice(1),
    ["groups", "g1", "m1", "jpg"],
  );
  assert.deepEqual(
    ORIGINAL_PATTERN.exec("privateChats/5:alice3:bob/media/m1_original.png")
      .slice(1),
    ["privateChats", "5:alice3:bob", "m1", "png"],
  );
  assert.equal(
    ORIGINAL_PATTERN.test("groups/g1/media/m1_thumb.jpg"),
    false,
  );
  assert.equal(
    ORIGINAL_PATTERN.test("groups/g1/chat/m1_original.jpg"),
    false,
  );
  assert.equal(
    ORIGINAL_PATTERN.test("privateChats/c1/media/m1_medium.jpg"),
    false,
  );
});

function pipelineDb() {
  const store = new Map();
  return {
    store,
    collection(name) {
      return {
        doc(id) {
          const path = `${name}/${id}`;
          return {
            collection(sub) {
              return {
                doc(sid) {
                  const full = `${path}/${sub}/${sid}`;
                  return {
                    async set(data, options) {
                      const current = store.get(full) || {};
                      store.set(full, options && options.merge
                        ? { ...current, ...data }
                        : data);
                    },
                  };
                },
              };
            },
          };
        },
      };
    },
  };
}

test("audio originals under 10MB become ready without transcode", async () => {
  const db = pipelineDb();
  const process = createGroupMediaPipeline({
    db,
    bucket: {},
    randomUUID: () => "x",
  });
  await process({
    data: {
      name: "groups/g1/media/a1_original.m4a",
      contentType: "audio/mp4",
      size: 1024,
      metadata: { uploadedBy: "alice" },
    },
  });
  const stored = db.store.get("groups/g1/media/a1");
  assert.equal(stored.status, "ready");
  assert.equal(stored.mediaType, "audio");
  assert.equal(stored.maxDurationSeconds, 60);
});

test("oversized audio originals fail instead of becoming ready", async () => {
  const db = pipelineDb();
  const process = createGroupMediaPipeline({
    db,
    bucket: {},
    randomUUID: () => "x",
  });
  await process({
    data: {
      name: "groups/g1/media/a2_original.m4a",
      contentType: "audio/mp4",
      size: 11 * 1024 * 1024,
      metadata: { uploadedBy: "alice" },
    },
  });
  const stored = db.store.get("groups/g1/media/a2");
  assert.equal(stored.status, "failed");
  assert.equal(stored.errorCode, "audio-too-large");
});