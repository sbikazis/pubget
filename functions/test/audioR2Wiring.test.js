"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.join(__dirname, "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");

test("audio extraction is bound only to the R2 adapter", () => {
  const index = read("index.js");
  assert.match(index, /require\("\.\/src\/r2AudioStorage"\)/);
  assert.match(index, /const r2AudioBucket = createR2AudioBucket\(\);/);
  assert.match(index, /createAudioDomain\(\{[\s\S]*?bucket: r2AudioBucket/);
  assert.doesNotMatch(index, /createAudioDomain\(\{[\s\S]{0,200}lazyStorageBucket/);

  const domain = read("src/audioDomain.js");
  assert.doesNotMatch(domain, /require\("firebase-admin\/storage"\)/);
  assert.match(domain, /reelAudios\/\$\{creatorId\}\/\$\{audioId\}\.m4a/);
});

test("audio R2 bridge accepts only service-authenticated, scoped objects", () => {
  const worker = read("../worker/src/index.ts");
  assert.match(worker, /export function validAudioServiceKey\(/);
  assert.match(worker, /url\.pathname\.startsWith\("\/_internal\/audio\/objects\/"\)/);
  assert.match(worker, /authenticateKirariService\(/);
  assert.match(worker, /Only extracted audio objects can be written\./);
  assert.match(worker, /pipeline: "audio-extractor-v1"/);

  const adapter = read("src/r2AudioStorage.js");
  assert.match(adapter, /may only write reelAudios objects/);
  assert.match(adapter, /audio\/mp4", "audio\/m4a/);
});
