"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  decideAspectTreatment,
  buildRenditionEncodeArgs,
  decideEditPublication,
  TARGET_RATIO,
} = require("../src/editPipeline");
const { EDIT_RENDITIONS } = require("../src/editsConfig");

const MASTER = EDIT_RENDITIONS[0];

function encodeArgs(treatment, rendition = MASTER) {
  return buildRenditionEncodeArgs({
    source: "source.mp4",
    destination: "out.mp4",
    treatment,
    rendition,
  });
}

test("near 9:16 stays passthrough (no blur/crop)", () => {
  const portrait = decideAspectTreatment(1080, 1920);
  assert.equal(portrait.mode, "passthrough");
  const near = decideAspectTreatment(1080, 1850);
  assert.equal(near.mode, "passthrough");
  const args = encodeArgs(portrait);
  assert.equal(args.includes("-filter_complex"), false);
  assert.match(args.join(" "), /force_original_aspect_ratio=decrease/);
});

test("landscape gets blur_pad treatment (Instagram-style)", () => {
  const landscape = decideAspectTreatment(1920, 1080);
  assert.equal(landscape.mode, "blur_pad");
  assert.ok(landscape.ratio > TARGET_RATIO);
  const complex = encodeArgs(landscape).join(" ");
  assert.match(complex, /boxblur/);
  assert.match(complex, /overlay/);
});

test("extreme tall gets center_crop", () => {
  const tall = decideAspectTreatment(720, 2400);
  assert.equal(tall.mode, "center_crop");
  assert.match(encodeArgs(tall).join(" "), /crop=1080:1920/);
});

// The ladder replaced a single fixed encode. `height` is the VERTICAL height of
// the 9:16 frame, so every rung must resolve to the canonical 9:16 width.
test("every ladder rung encodes to correct 9:16 dimensions", () => {
  const expected = {
    master: "1080:1920",
    720: "720:1280",
    480: "480:854",
  };
  for (const rendition of EDIT_RENDITIONS) {
    const args = encodeArgs({ mode: "blur_pad" }, rendition).join(" ");
    const dims = expected[rendition.key];
    assert.ok(dims, `${rendition.key} has no expected dimensions`);
    assert.ok(
      args.includes(dims),
      `${rendition.key} must encode at ${dims}, got: ${args}`,
    );
  }
});

test("each rung uses its own bitrate ladder settings", () => {
  for (const rendition of EDIT_RENDITIONS) {
    const args = encodeArgs({ mode: "passthrough" }, rendition);
    const crf = args[args.indexOf("-crf") + 1];
    const audio = args[args.indexOf("-b:a") + 1];
    assert.equal(crf, String(rendition.crf));
    assert.equal(audio, `${rendition.audioKbps}k`);
    // Smaller rungs must be cheaper, never higher quality.
    assert.ok(rendition.crf >= MASTER.crf, `${rendition.key} crf too aggressive`);
  }
});

test("passthrough rungs never upscale the source", () => {
  const args = encodeArgs({ mode: "passthrough" }).join(" ");
  assert.match(args, /scale='min\(1080,iw\)'/);
  assert.equal(args.includes("-filter_complex"), false);
});

test("duration cap is applied to every rung, not just the master", () => {
  for (const rendition of EDIT_RENDITIONS) {
    const args = encodeArgs({ mode: "passthrough" }, rendition);
    assert.equal(args[args.indexOf("-t") + 1], "60");
  }
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
