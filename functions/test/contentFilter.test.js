"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { decideEditPublication } = require("../src/editPipeline");
const { moderateEditCopy, scanText } = require("../src/contentFilter");

test("clean captions pass and banned captions flag", () => {
  assert.equal(moderateEditCopy({ caption: "Gear five port", animeTag: "one_piece" }).flagged, false);
  const flagged = moderateEditCopy({
    caption: "Join this crypto giveaway today",
    animeTag: "one_piece",
  });
  assert.equal(flagged.flagged, true);
  assert.equal(flagged.reason, "Caption or tag contains prohibited language.");
  assert.equal(scanText("please kys now").flagged, true);
  assert.equal(scanText("skyline").flagged, false);
});

test("pipeline publishes clean copy and rejects banned copy without client override", () => {
  const processing = {
    videoUrl: "processed.mp4",
    thumbnailUrl: "thumb.jpg",
    durationSeconds: 12,
    score: 21,
    creatorQuality: 1,
  };
  const published = decideEditPublication(
    { caption: "Luffy vs Kaido", animeTag: "one_piece" },
    processing,
  );
  assert.equal(published.publish, true);
  assert.equal(published.update.status, "published");
  assert.equal(published.update.moderationStatus, "approved");

  const rejected = decideEditPublication(
    { caption: "crypto giveaway", animeTag: "one_piece", moderationStatus: "approved" },
    processing,
  );
  assert.equal(rejected.publish, false);
  assert.equal(rejected.update.status, "rejected");
  assert.equal(rejected.update.moderationStatus, "flagged");
  assert.match(rejected.update.moderationReason, /prohibited language/);
  assert.equal(rejected.update.videoUrl, processing.videoUrl);
});
