"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.join(__dirname, "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");

test("Kirari Functions bind both domain and pipeline to the R2 adapter", () => {
  const index = read("index.js");
  assert.match(index, /createR2KirariBucket/);
  assert.match(index, /const kirariBucket = createR2KirariBucket\(\);/);
  assert.match(index, /createKirariPipeline\(\{[\s\S]*?bucket: kirariBucket/);
  assert.match(index, /createKirariDomain\(\{[\s\S]*?bucket: kirariBucket/);
  assert.doesNotMatch(index, /createKirariPipeline\(\{[\s\S]{0,200}getStorage\(\)\.bucket\(\)/);
  assert.doesNotMatch(index, /createKirariDomain\(\{[\s\S]{0,200}getStorage\(\)\.bucket\(\)/);
});

test("Kirari processing is woken by a Firestore state transition, not a Storage event", () => {
  const index = read("index.js");
  assert.match(index, /exports\.processKirariVideo = onDocumentUpdated\(/);
  assert.doesNotMatch(index, /exports\.processKirariVideo = onObjectFinalized\(/);
  assert.match(index, /after\.status !== "processing"/);
  assert.match(index, /after\.processingLeaseId/);
  const domain = read("src/kirariDomain.js");
  assert.doesNotMatch(domain, /await processVideo\(\{ data:/);
});

test("new Kirari media is tagged with its R2 backend for client resolution", () => {
  const pipeline = read("src/kirariPipeline.js");
  const domain = read("src/kirariDomain.js");
  assert.match(pipeline, /mediaBackend: "r2"/);
  assert.match(domain, /mediaBackend: "r2"/);
});

test("Worker and adapter agree on the custom-cover object key", () => {
  assert.match(read("../worker/src/index.ts"), /cover-source\\\.jpg/);
  assert.match(read("src/r2KirariStorage.js"), /cover-source\\\.jpg/);
});
