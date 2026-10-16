"use strict";

// §15.2 cover frame.
//
// `coverFrameMs` was validated (0–60000) and persisted by startUpload, but the
// pipeline seeked to a hardcoded 00:00:00.500. The frame the creator picked in
// the trimmer was silently ignored, which is the worst kind of dead parameter:
// the client and the server both believed it worked.

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  resolveCoverSeekSeconds,
  toTimestampArg,
} = require("../src/editPipeline");

test("cover seek honours the frame the creator chose", () => {
  assert.equal(resolveCoverSeekSeconds(12000, 60), 12);
  assert.equal(resolveCoverSeekSeconds(0, 60), 0);
  assert.equal(resolveCoverSeekSeconds(1500, 60), 1.5);
  assert.equal(resolveCoverSeekSeconds(45000, 60), 45);
});

test("cover seek is clamped inside the last decodable frame", () => {
  // A 5s clip cannot show a frame at 30s; asking must not crash or black-frame.
  assert.equal(resolveCoverSeekSeconds(30000, 5), 4.9);
  // Exactly at the ceiling stays put rather than being pushed back to zero.
  assert.equal(resolveCoverSeekSeconds(4900, 5), 4.9);
  // Absurd input still resolves to a real, safe seek.
  assert.equal(resolveCoverSeekSeconds(60000, 8), 7.9);
  assert.equal(resolveCoverSeekSeconds(999999, 3), 2.9);
});

test("cover seek degrades to the first frame on bad input", () => {
  for (const bad of [undefined, null, -1, NaN, "abc", {}, []]) {
    assert.equal(
      resolveCoverSeekSeconds(bad, 30),
      0,
      `${String(bad)} must fall back to the first frame`,
    );
  }
  // Unknown duration must not produce NaN into an ffmpeg argument.
  for (const badDuration of [0, -1, NaN, undefined, null, "abc"]) {
    assert.equal(resolveCoverSeekSeconds(5000, badDuration), 0);
  }
});

test("timestamp argument is zero-padded ffmpeg HH:MM:SS.mmm", () => {
  assert.equal(toTimestampArg(0), "00:00:00.000");
  assert.equal(toTimestampArg(12.345), "00:00:12.345");
  assert.equal(toTimestampArg(59.5), "00:00:59.500");
  assert.equal(toTimestampArg(60), "00:01:00.000");
  assert.equal(toTimestampArg(3661.5), "01:01:01.500");
});

// Guards the formatting contract ffmpeg actually depends on.
test("timestamp argument never emits a malformed clock", () => {
  for (const seconds of [0, 1, 1.05, 59.999, 60, 3599.999, 3600, 7325]) {
    const stamp = toTimestampArg(seconds);
    assert.match(stamp, /^\d{2}:\d{2}:\d{2}\.\d{3}$/, `${seconds}s -> ${stamp}`);
    const [h, m, s] = stamp.split(":");
    assert.ok(Number(m) < 60, `minutes must roll over: ${stamp}`);
    assert.ok(Number(s) < 60, `seconds must roll over: ${stamp}`);
    assert.ok(Number(h) < 100, `hours must stay 2-digit: ${stamp}`);
  }
});