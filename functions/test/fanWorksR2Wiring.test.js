"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.join(__dirname, "..");
const indexSource = fs.readFileSync(path.join(root, "index.js"), "utf8");

test("Functions wires Fan Works to the R2 signer, not the Firebase bucket", () => {
  assert.match(indexSource, /createR2FanWorksSigner\(\)/);
  assert.doesNotMatch(indexSource, /createFanWorksSigner\(\{/);
  assert.doesNotMatch(indexSource, /signer:\s*lazyStorageBucket/);
});

test("Fan Works domain receives the R2 signer as its metadata source", () => {
  const domainBlock = indexSource.slice(
    indexSource.indexOf("const fanWorksDomain = createFanWorksDomain"),
    indexSource.indexOf("const notificationCallables"),
  );
  assert.match(domainBlock, /storage:\s*fanWorksSigner/);
  assert.match(domainBlock, /signer:\s*fanWorksSigner/);
  assert.doesNotMatch(domainBlock, /lazyStorageBucket/);
});
