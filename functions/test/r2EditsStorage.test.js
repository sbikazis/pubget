"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { createR2EditsBucket } = require("../src/r2EditsStorage");

test("Edits R2 adapter fails closed without a service identity", async () => {
  const bucket = createR2EditsBucket({ tokenProvider: async () => "" });
  await assert.rejects(bucket.file("edits/alice/edit_1.mp4").exists(), /identity is not available/);
});

test("Edits R2 adapter rejects keys outside the strict Edits namespaces", () => {
  const bucket = createR2EditsBucket({ tokenProvider: async () => "header.payload.signature" });
  assert.throws(() => bucket.file("groups/g1/u1/image.jpg"), /Invalid Edits/);
  assert.throws(() => bucket.file("edits/../edit_1.mp4"), /Invalid Edits/);
  assert.throws(() => bucket.file("edits/alice/edit_1.mov"), /Invalid Edits/);
  assert.doesNotThrow(() => bucket.file("edits/alice/edit_1.mp4"));
  assert.doesNotThrow(() => bucket.file("edits-processed/alice/edit_1_720.mp4"));
  assert.doesNotThrow(() => bucket.file("edits/alice/t_edit_1.jpg"));
});

test("Edits R2 adapter uses authenticated Worker HEAD and GET for source reads", async () => {
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
  const bucket = createR2EditsBucket({
    tokenProvider: async () => "header.payload.signature", fetchImpl,
  });
  assert.deepEqual(await bucket.file("edits/alice/edit_1.mp4").exists(), [true]);
  assert.deepEqual(await bucket.file("edits/alice/edit_1.mp4").getMetadata(), [{
    size: "4", contentType: "video/mp4",
  }]);
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "edits-r2-test-"));
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

test("Edits R2 adapter streams processed outputs through the private Worker bridge", async () => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "edits-r2-upload-"));
  const source = path.join(directory, "rendition.mp4");
  await fs.writeFile(source, Buffer.from([1, 2, 3, 4]));
  const calls = [];
  try {
    const bucket = createR2EditsBucket({
      tokenProvider: async () => "header.payload.signature",
      fetchImpl: async (url, options) => {
        calls.push({ url: String(url), options });
        return new Response(JSON.stringify({ key: "edits-processed/alice/edit_1.mp4" }), { status: 201 });
      },
    });
    await bucket.upload(source, {
      destination: "edits-processed/alice/edit_1.mp4",
      metadata: { contentType: "video/mp4" },
    });
    assert.equal(calls.length, 1);
    assert.equal(calls[0].options.method, "PUT");
    assert.equal(calls[0].options.headers.authorization, "Bearer header.payload.signature");
    assert.equal(calls[0].options.headers["content-type"], "video/mp4");
  } finally {
    await fs.rm(directory, { recursive: true, force: true });
  }
});
