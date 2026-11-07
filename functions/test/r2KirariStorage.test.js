"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { createR2KirariBucket } = require("../src/r2KirariStorage");

test("Kirari R2 adapter fails closed when Google service identity is unavailable", async () => {
  const bucket = createR2KirariBucket({ tokenProvider: async () => "" });
  await assert.rejects(bucket.file("kirari/u1/r1/source.mp4").exists(), /identity is not available/);
});

test("Kirari R2 adapter rejects keys outside the Kirari namespace", () => {
  const bucket = createR2KirariBucket({ tokenProvider: async () => "header.payload.signature" });
  assert.throws(() => bucket.file("groups/g1/u1/image.jpg"), /Invalid Kirari/);
  assert.throws(() => bucket.file("kirari/../u1/source.mp4"), /Invalid Kirari/);
});

test("Kirari R2 adapter requests a Google metadata identity token with the Worker audience", async () => {
  const calls = [];
  const fetchImpl = async (url, options) => {
    calls.push({ url: String(url), options });
    if (calls.length === 1) return new Response("header.payload.signature", { status: 200 });
    return new Response(null, { status: 200 });
  };
  const bucket = createR2KirariBucket({ fetchImpl });
  assert.deepEqual(await bucket.file("kirari/u1/r1/source.mp4").exists(), [true]);
  assert.equal(calls.length, 2);
  assert.ok(calls[0].url.includes("metadata.google.internal"));
  assert.ok(calls[0].url.includes("audience=https%3A%2F%2Fpubget-media.pubget.workers.dev"));
  assert.ok(calls[0].url.includes("format=full"));
  assert.equal(calls[0].options.headers["Metadata-Flavor"], "Google");
  assert.equal(calls[1].options.headers.authorization, "Bearer header.payload.signature");
});

test("Kirari R2 adapter streams object downloads and reports metadata", async () => {
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
  const bucket = createR2KirariBucket({
    tokenProvider: async () => "header.payload.signature", fetchImpl,
  });
  assert.deepEqual(await bucket.file("kirari/u1/r1/source.mp4").exists(), [true]);
  assert.deepEqual(await bucket.file("kirari/u1/r1/source.mp4").getMetadata(), [{
    size: "4", contentType: "video/mp4",
  }]);
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), "kirari-r2-test-"));
  try {
    const destination = path.join(directory, "source.mp4");
    await bucket.file("kirari/u1/r1/source.mp4").download({ destination });
    assert.deepEqual([...await fs.readFile(destination)], [1, 2, 3, 4]);
  } finally {
    await fs.rm(directory, { recursive: true, force: true });
  }
  assert.ok(calls.every((call) =>
    call.headers.authorization === "Bearer header.payload.signature"));
});
