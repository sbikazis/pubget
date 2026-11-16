"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createKirariR2ProcessingTrigger } = require("../src/kirariR2ProcessingTrigger");

function event(before, after, path = "kirari/alice/reel-1/source.mp4") {
  return {
    id: "event-1",
    params: { reelId: "reel-1" },
    data: {
      before: { data: () => before },
      after: { data: () => ({ ...after, creatorId: "alice", originalStoragePath: path }) },
    },
  };
}

test("R2 processing trigger forwards a valid uploading-to-processing transition", async () => {
  let requestedPath;
  let processed;
  const bucket = {
    name: "pubget-media",
    file(path) {
      requestedPath = path;
      return { getMetadata: async () => [{ size: "4096", contentType: "video/mp4" }] };
    },
  };
  const trigger = createKirariR2ProcessingTrigger({
    bucket,
    db: { collection() { throw new Error("Firestore should not be written on success"); } },
    processVideo: async (payload) => { processed = payload; return "started"; },
  });

  const result = await trigger(event(
    { status: "uploading", mediaBackend: "r2" },
    { status: "processing", mediaBackend: "r2" },
  ));

  assert.equal(result, "started");
  assert.equal(requestedPath, "kirari/alice/reel-1/source.mp4");
  assert.deepEqual(processed, { data: {
    name: requestedPath,
    bucket: "pubget-media",
    size: 4096,
    contentType: "video/mp4",
    generation: "event-1",
  } });
});

test("R2 processing trigger ignores legacy records and unrelated transitions", async () => {
  let calls = 0;
  const trigger = createKirariR2ProcessingTrigger({
    bucket: { name: "pubget-media", file() { calls++; return {}; } },
    db: {},
    processVideo: async () => { calls++; },
  });

  assert.equal(await trigger(event(
    { status: "uploading", mediaBackend: "firebase" },
    { status: "processing", mediaBackend: "firebase" },
  )), null);
  assert.equal(await trigger(event(
    { status: "processing", mediaBackend: "r2" },
    { status: "processing", mediaBackend: "r2" },
  )), null);
  assert.equal(await trigger(event(
    { status: "published", mediaBackend: "r2" },
    { status: "processing", mediaBackend: "r2" },
  )), null);
  assert.equal(calls, 0);
});

test("missing R2 source moves the reel to a recoverable failed state", async () => {
  let failurePatch;
  const trigger = createKirariR2ProcessingTrigger({
    bucket: { name: "pubget-media", file: () => ({
      getMetadata: async () => { throw new Error("R2 object missing"); },
    }) },
    db: { collection: (name) => ({
      doc: (id) => ({
        update: async (patch) => { failurePatch = { name, id, patch }; },
      }),
    }) },
    processVideo: async () => { throw new Error("processor must not run"); },
  });

  assert.equal(await trigger(event(
    { status: "uploading", mediaBackend: "r2" },
    { status: "processing", mediaBackend: "r2" },
  )), null);
  assert.equal(failurePatch.name, "kirari");
  assert.equal(failurePatch.id, "reel-1");
  assert.equal(failurePatch.patch.status, "failed");
  assert.equal(failurePatch.patch.failureReason, "r2-source-unavailable");
  assert.equal(failurePatch.patch.processingLeaseUntil.getTime(), 0);
});

test("R2 processing trigger rejects malformed source paths without invoking the processor", async () => {
  let called = false;
  const trigger = createKirariR2ProcessingTrigger({
    bucket: { name: "pubget-media", file: () => { throw new Error("must not access R2"); } },
    db: {},
    processVideo: async () => { called = true; },
  });

  assert.equal(await trigger(event(
    { status: "uploading", mediaBackend: "r2" },
    { status: "processing", mediaBackend: "r2" },
    "kirari/../reel-1/source.mp4",
  )), null);
  assert.equal(called, false);
});
