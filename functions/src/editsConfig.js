'use strict';

const DAY = 24 * 60 * 60 * 1000;

/** Canonical edits limits — keep in sync with lib/core/constants/limits.dart. */
const EDITS_CONFIG = Object.freeze({
  fanThreshold: 5,
  maxDurationSeconds: 180,
  maxBytes: 100 * 1024 * 1024,
  qualifiedViewPercent: 10,
  completionPercent: 90,
  viewabilityMs: 250,
  visibleFraction: 0.5,
  feedPageSize: 5,
  prefetchAhead: 1,
  captionMax: 1000,
  commentMax: 500,
  stickerMax: 32,
  mentionMax: 8,
  repostWindowMs: 30 * DAY,
  schemaVersion: 2,
});

module.exports = { EDITS_CONFIG, DAY };
