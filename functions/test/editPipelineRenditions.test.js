"use strict";

// §15.2 rendition ladder.
//
// The pipeline used to emit exactly one fixed 1080x1920 encode. The spec wants
// a ladder so players can pick a bitrate, and `selectRenditions` must never
// upscale a low-resolution source.

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  selectRenditions,
  renditionStoragePath,
} = require("../src/editPipeline");
const { EDIT_RENDITIONS } = require("../src/editsConfig");

const PREFIX = "edits-processed";

test("ladder is ordered best-first and the highest rung is the primary", () => {
  const ladder = selectRenditions({ sourceHeight: 1920 });
  const heights = ladder.map((rendition) => rendition.height);
  assert.deepEqual(heights, [...heights].sort((a, b) => b - a));
  assert.equal(ladder[0].key, "master");
});

test("high-resolution source gets the full ladder", () => {
  assert.deepEqual(
    selectRenditions({ sourceHeight: 1920 }).map((rendition) => rendition.key),
    ["master", "720", "480"],
  );
});

test("rungs taller than the source are dropped (no upscaling)", () => {
  // An 854-tall source must not get a 1280 or 1920 rung.
  const ladder = selectRenditions({ sourceHeight: 854 });
  assert.deepEqual(ladder.map((rendition) => rendition.key), ["480"]);
  assert.ok(ladder.every((rendition) => 854 >= rendition.height));
});

test("a source below every rung still yields one playable output", () => {
  // Regression: this used to return an empty ladder, so the pipeline produced
  // no video at all and then crashed trying to grab a cover frame from it.
  for (const sourceHeight of [854, 720, 480, 240, 120]) {
    const ladder = selectRenditions({ sourceHeight });
    assert.equal(ladder.length, 1, `${sourceHeight}p must still get an output`);
    assert.equal(ladder[0], EDIT_RENDITIONS[EDIT_RENDITIONS.length - 1]);
  }
});

test("unknown source height falls back to the full ladder", () => {
  assert.equal(selectRenditions({ sourceHeight: 0 }).length, EDIT_RENDITIONS.length);
  assert.equal(selectRenditions({ sourceHeight: null }).length, EDIT_RENDITIONS.length);
});

test("primary rung owns the legacy unsuffixed path", () => {
  // Stored `videoUrl` and cached players already point at this exact path.
  const primary = selectRenditions({ sourceHeight: 1920 })[0];
  assert.equal(
    renditionStoragePath(PREFIX, "user1", "edit1", primary, true),
    "edits-processed/user1/edit1.mp4",
  );
});

test("extra rungs use suffixed sibling paths", () => {
  const ladder = selectRenditions({ sourceHeight: 1920 });
  assert.equal(
    renditionStoragePath(PREFIX, "user1", "edit1", ladder[1], false),
    "edits-processed/user1/edit1_720.mp4",
  );
  assert.equal(
    renditionStoragePath(PREFIX, "user1", "edit1", ladder[2], false),
    "edits-processed/user1/edit1_480.mp4",
  );
});

test("low-resolution primary still resolves to the legacy path", () => {
  // The single output must still be the canonical path, not a suffixed one.
  const primary = selectRenditions({ sourceHeight: 480 })[0];
  assert.equal(
    renditionStoragePath(PREFIX, "user1", "edit1", primary, true),
    "edits-processed/user1/edit1.mp4",
  );
});

test("every produced path matches the existing Storage rule shape", () => {
  // storage.rules: match /edits-processed/{userId}/{fileName}
  for (const sourceHeight of [1920, 854, 480]) {
    for (const [index, rendition] of selectRenditions({ sourceHeight }).entries()) {
      const path = renditionStoragePath(PREFIX, "user1", "edit1", rendition, index === 0);
      assert.match(path, /^edits-processed\/[^/]+\/[^/]+\.mp4$/, path);
    }
  }
});

test("rung labels describe the encoded width, not the frame height", () => {
  assert.deepEqual(
    EDIT_RENDITIONS.map((rendition) => rendition.label),
    ["1080p", "720p", "480p"],
  );
});