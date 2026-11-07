"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { renditionArgs, editorVideoFilter, outputDurationSeconds, buildAudioAttribution } = require("../src/kirariPipeline");

test("Kirari rendition ladder always outputs vertical 9:16 dimensions", () => {
  const expected = new Map([[360, 202], [540, 302], [720, 404]]);
  for (const [height, width] of expected) {
    const args = renditionArgs("source.mp4", "output.mp4", height, "1200k");
    const filter = args[args.indexOf("-vf") + 1];
    assert.match(filter, new RegExp(`scale=${width}:${height}:force_original_aspect_ratio=increase,crop=${width}:${height}`));
    assert.ok(args.includes("0:a?"), "optional source audio should be preserved");
    assert.ok(args.includes("+faststart"), "MP4 should be optimized for progressive playback");
  }
});

test("Kirari editor export applies trim-safe text, color and playback speed filters", () => {
  const filter = editorVideoFilter(404, 720, {
    filter: "warm",
    speed: 1.5,
    overlayText: "Anime: it's 100%",
  });
  assert.match(filter, /scale=404:720/);
  assert.match(filter, /colorbalance=rs=.08:gs=.02/);
  assert.match(filter, /drawtext=text=/);
  assert.match(filter, /setpts=PTS\/1.5/);
  assert.ok(filter.includes("Anime"));
});

test("Kirari text overlay is constrained to its selected source interval", () => {
  const filter = editorVideoFilter(404, 720, {
    trimStartSeconds: 8,
    trimEndSeconds: 24,
    overlayStartSeconds: 12,
    overlayEndSeconds: 18,
    speed: 1,
    filter: "none",
    overlayText: "Pubget",
  });
  assert.match(filter, /enable='between\(t,4,10\)'/);
});

test("Kirari speed changes preserve the selected source interval", () => {
  assert.equal(outputDurationSeconds(12, 0.5), 24);
  assert.equal(outputDurationSeconds(12, 1), 12);
  assert.equal(outputDurationSeconds(12, 2), 6);
  assert.equal(outputDurationSeconds(12, 9), 6);
});


test("Kirari reel attribution preserves the license and required credit text", () => {
  assert.deepEqual(buildAudioAttribution("track-1", {
    title: "Opening Theme",
    artist: "Creator",
    license: "CC BY 4.0",
    attribution: "Music by Creator, used under CC BY 4.0",
    creatorId: "creator-1",
  }), {
    audioId: "track-1",
    title: "Opening Theme",
    artist: "Creator",
    license: "CC BY 4.0",
    attribution: "Music by Creator, used under CC BY 4.0",
    sourceCreatorId: "creator-1",
  });
  assert.equal(buildAudioAttribution(null, { title: "unused" }), null);
});

test("Kirari attribution falls back to the catalog display name", () => {
  assert.equal(buildAudioAttribution("track-2", {
    displayName: "Community Remix",
    artist: "Fan Creator",
    license: "CC BY 4.0",
    attribution: "Credit required",
  }).title, "Community Remix");
});
