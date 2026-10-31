"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { renditionArgs } = require("../src/kirariPipeline");

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
