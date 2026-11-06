"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { createR2KirariBucket } = require("../src/r2KirariStorage");

test("Kirari R2 adapter fails closed without the service secret", async () => {
  const bucket = createR2KirariBucket({ secretProvider: () => "" });
  await assert.rejects(bucket.file("kirari/u1/r1/source.mp4").exists(), /not configured/);
});

test("Kirari R2 adapter rejects keys outside the Kirari namespace", () => {
  const bucket = createR2KirariBucket({ secretProvider: () => "x".repeat(48) });
  assert.throws(() => bucket.file("groups/g1/u1/image.jpg"), /Invalid Kirari/);
  assert.throws(() => bucket.file("kirari/../u1/source.mp4"), /Invalid Kirari/);
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
    secretProvider: () => "s".repeat(48), fetchImpl,
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
  assert.ok(calls.every((call) => call.headers.authorization === `Bearer ${"s".repeat(48)}`));
});
