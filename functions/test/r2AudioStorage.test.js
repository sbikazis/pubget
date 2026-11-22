"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { createR2AudioBucket, MAX_AUDIO_BYTES } = require("../src/r2AudioStorage");

test("audio R2 adapter fails closed without a service identity", async () => {
  const bucket = createR2AudioBucket({ tokenProvider: async () => "" });
  await assert.rejects(
    bucket.file("reelAudios/alice/audio_1.m4a").exists(),
    /identity is not available/,
  );
});

test("audio R2 adapter rejects keys outside its strict namespaces", () => {
  const bucket = createR2AudioBucket({ tokenProvider: async () => "header.payload.signature" });
  assert.throws(() => bucket.file("groups/g1/u1/image.jpg"), /Invalid audio/);
  assert.throws(() => bucket.file("edits/../edit_1.mp4"), /Invalid audio/);
  assert.throws(() => bucket.file("reelAudios/alice/audio_1.mp3"), /Invalid audio/);
  assert.doesNotThrow(() => bucket.file("edits/alice/edit_1.mp4"));
  assert.doesNotThrow(() => bucket.file("edits-processed/alice/edit_1_720.mp4"));
  assert.doesNotThrow(() => bucket.file("reelAudios/alice/audio_1.m4a"));
});

test("audio R2 adapter reads Edit sources through the authenticated bridge", async () => {
  const calls = [];
  const fetchImpl = async (_url, options) => {
    calls.push(options);
    if (options.method === "HEAD") {
      return new Response(null, { status: 200, headers: {
        "content-length": "4", "content-type": "video/mp4",
      } });
    }
    return new Response(new Uint8Array([1, 2, 3, 4]), { status: 200 });
  };
  const bucket = createR2AudioBucket({
    tokenProvider: async () => "header.payload.signature", fetchImpl,
  });
  assert.deepEqual(await bucket.file("edits/alice/edit_1.mp4").exists(), [true]);
  assert.deepEqual(await bucket.file("edits/alice/edit_1.mp4").getMetadata(), [{
    size: "4", contentType: "video/mp4",
  }]);
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "audio-r2-test-"));
  try {
    const destination = path.join(directory, "source.mp4");
    await bucket.file("edits/alice/edit_1.mp4").download({ destination });
    assert.deepEqual([...await fs.readFile(destination)], [1, 2, 3, 4]);
  } finally {
    await fs.rm(directory, { recursive: true, force: true });
  }
  assert.ok(calls.every((call) =>
    call.headers.authorization === "Bearer header.payload.signature"));
});

test("audio R2 adapter writes only reelAudios objects", async () => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "audio-r2-upload-"));
  const source = path.join(directory, "audio.m4a");
  await fs.writeFile(source, Buffer.from([1, 2, 3, 4]));
  const calls = [];
  try {
    const bucket = createR2AudioBucket({
      tokenProvider: async () => "header.payload.signature",
      fetchImpl: async (url, options) => {
        calls.push({ url: String(url), options });
        return new Response(JSON.stringify({ key: "reelAudios/alice/audio_1.m4a" }), { status: 201 });
      },
    });
    await bucket.upload(source, {
      destination: "reelAudios/alice/audio_1.m4a",
      metadata: { contentType: "audio/mp4" },
    });
    assert.equal(calls.length, 1);
    assert.match(calls[0].url, /_internal\/audio\/objects\//);
    assert.equal(calls[0].options.method, "PUT");
    assert.equal(calls[0].options.headers.authorization, "Bearer header.payload.signature");
    assert.equal(calls[0].options.headers["content-type"], "audio/mp4");

    await assert.rejects(
      bucket.upload(source, {
        destination: "edits/alice/edit_1.mp4",
        metadata: { contentType: "audio/mp4" },
      }),
      /may only write reelAudios/,
    );
    await assert.rejects(
      bucket.upload(source, {
        destination: "reelAudios/alice/audio_1.m4a",
        metadata: { contentType: "video/mp4" },
      }),
      /must be audio\/mp4 or audio\/m4a/,
    );
  } finally {
    await fs.rm(directory, { recursive: true, force: true });
  }
  assert.ok(MAX_AUDIO_BYTES > 0);
});
