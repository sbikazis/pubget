"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.join(__dirname, "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");

test("Edits Functions bind pipeline and domain only to the R2 adapter", () => {
  const index = read("index.js");
  assert.match(index, /const r2EditsBucket = createR2EditsBucket\(\);/);
  assert.match(index, /createEditPipeline\(\{[\s\S]*?r2Bucket: r2EditsBucket/);
  assert.match(index, /createEditsDomain\(\{[\s\S]*?r2Bucket: r2EditsBucket/);
  assert.doesNotMatch(index, /createEditPipeline\(\{[\s\S]{0,200}lazyStorageBucket/);
  assert.doesNotMatch(index, /createEditsDomain\(\{[\s\S]{0,200}lazyStorageBucket/);
});

test("no Firebase Storage finalize processor remains for Edits", () => {
  const index = read("index.js");
  assert.doesNotMatch(index, /require\("firebase-functions\/v2\/storage"\)/);
  assert.doesNotMatch(index, /onObjectFinalized\(/);
  assert.doesNotMatch(index, /exports\.processEditVideo/);
  assert.match(index, /exports\.processEditR2Video = onDocumentUpdated\(/);

  const pipeline = read("src/editPipeline.js");
  assert.doesNotMatch(pipeline, /setMediaVisible/);
  assert.doesNotMatch(pipeline, /mediaBackend === "r2" \? r2Bucket : bucket/);

  const domain = read("src/editsDomain.js");
  assert.doesNotMatch(domain, /setMediaVisible/);
  assert.doesNotMatch(domain, /await processEdit\(\{/);
  assert.match(domain, /This Reel uses legacy storage\. Re-upload it to process it\./);
});

test("legacy Edits, Reels and Kirari writes are denied but reads remain", () => {
  const rules = read("../storage.rules");
  assert.match(
    rules,
    /match \/edits\/\{userId\}\/\{fileName\} \{[\s\S]*?allow read:[\s\S]*?allow create, update, delete: if false;/,
  );
  assert.match(
    rules,
    /match \/reels\/\{userId\}\/\{fileName\} \{[\s\S]*?allow read:[\s\S]*?allow create, update, delete: if false;/,
  );
  assert.match(
    rules,
    /match \/kirari\/\{userId\}\/\{reelId\}\/source\.mp4 \{[\s\S]*?allow read:[\s\S]*?allow create, update, delete: if false;/,
  );
  assert.match(
    rules,
    /match \/kirari\/\{userId\}\/\{reelId\}\/cover-source\.jpg \{[\s\S]*?allow read:[\s\S]*?allow create, update, delete: if false;/,
  );
});

test("Flutter Edits repository uploads only through R2", () => {
  const repository = read("../lib/features/edits/repositories/firebase_edits_repository.dart");
  assert.doesNotMatch(repository, /firebase_storage\/firebase_storage\.dart/);
  assert.doesNotMatch(repository, /edit_storage_put\.dart/);
  assert.doesNotMatch(repository, /putEditVideo\(/);
  assert.match(repository, /uploadEditVideoToR2\(/);

  const app = read("../lib/app/pubget_app.dart");
  assert.doesNotMatch(app, /storage: FirebaseStorage\.instance/);
});
