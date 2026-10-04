"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  decideAspectTreatment,
  buildVideoFilters,
  decideEditPublication,
  TARGET_RATIO,
} = require("../src/editPipeline");

test("near 9:16 stays passthrough (no blur/crop)", () => {
  const portrait = decideAspectTreatment(1080, 1920);
  assert.equal(portrait.mode, "passthrough");
  const near = decideAspectTreatment(1080, 1850);
  assert.equal(near.mode, "passthrough");
  const filters = buildVideoFilters(portrait);
  assert.equal(filters.filterComplex, null);
  assert.match(filters.simpleVf, /force_original_aspect_ratio=decrease/);
});

test("landscape gets blur_pad treatment (Instagram-style)", () => {
  const landscape = decideAspectTreatment(1920, 1080);
  assert.equal(landscape.mode, "blur_pad");
  assert.ok(landscape.ratio > TARGET_RATIO);
  const filters = buildVideoFilters(landscape);
  assert.match(filters.filterComplex, /boxblur/);
  assert.match(filters.filterComplex, /overlay/);
});

test("extreme tall gets center_crop", () => {
  const tall = decideAspectTreatment(720, 2400);
  assert.equal(tall.mode, "center_crop");
  const filters = buildVideoFilters(tall);
  assert.match(filters.simpleVf, /crop=1080:1920/);
});

test("watermark suspicion holds for needs_review instead of auto-publish", () => {
  const processing = {
    videoUrl: "processed.mp4",
    thumbnailUrl: "thumb.jpg",
    durationSeconds: 12,
    score: 21,
    creatorQuality: 1,
  };
  const held = decideEditPublication(
    { caption: "clean anime edit", animeTag: "one_piece" },
    processing,
    {
      scanned: true,
      suspected: true,
      reasons: ["corner_edge_bottom_right"],
      engine: "corner-edge-v1",
    },
  );
  assert.equal(held.publish, false);
  assert.equal(held.update.status, "needs_review");
  assert.equal(held.update.moderationStatus, "needs_review");
  assert.match(held.update.moderationReason, /watermark/i);
});

test("clean watermark scan still publishes", () => {
  const processing = {
    videoUrl: "processed.mp4",
    thumbnailUrl: "thumb.jpg",
    durationSeconds: 8,
    score: 20,
    creatorQuality: 0,
  };
  const published = decideEditPublication(
    { caption: "Luffy gear 5", animeTag: "one_piece" },
    processing,
    { scanned: true, suspected: false, reasons: [], engine: "corner-edge-v1" },
  );
  assert.equal(published.publish, true);
  assert.equal(published.update.status, "published");
});

// §15.2 duration is 3-60s. The lower bound was declared in config and in the
// user-facing copy but never enforced, so a 1-second clip published.
test("duration verdict enforces both the 3s floor and the 60s ceiling", () => {
  const { classifyDuration, durationFailureReason } = require("../src/editPipeline");

  for (const seconds of [0.5, 1, 2, 2.9]) {
    assert.equal(classifyDuration(seconds), "tooShort", `${seconds}s is below the floor`);
  }
  for (const seconds of [3, 4, 30, 59, 60]) {
    assert.equal(classifyDuration(seconds), "ok", `${seconds}s is inside the range`);
  }
  for (const seconds of [60.1, 61, 180]) {
    assert.equal(classifyDuration(seconds), "tooLong", `${seconds}s is above the ceiling`);
  }
  // Unreadable probe output must not slip through as valid.
  for (const bad of [0, -1, NaN, undefined, null, "abc", {}]) {
    const verdict = classifyDuration(bad);
    assert.notEqual(verdict, "ok", `${String(bad)} must not be accepted`);
    assert.equal(verdict, "invalid");
  }
});

test("duration failure copy names the limit that was actually hit", () => {
  const { classifyDuration, durationFailureReason } = require("../src/editPipeline");
  const config = { minDurationSeconds: 3, maxDurationSeconds: 60 };

  assert.match(durationFailureReason(classifyDuration(1, config), config), /at least 3 seconds/i);
  assert.match(durationFailureReason(classifyDuration(90, config), config), /up to 60 seconds/i);
  // The two verdicts must not produce the same message.
  assert.notEqual(
    durationFailureReason("tooShort", config),
    durationFailureReason("tooLong", config),
  );
});
