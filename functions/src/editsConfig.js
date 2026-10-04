'use strict';

const DAY = 24 * 60 * 60 * 1000;

/**
 * Canonical Axis 15 limits — the server is the single source of truth.
 *
 * Keep in sync with:
 *   - lib/core/constants/limits.dart  (client pre-flight, advisory only)
 *   - storage.rules                   (hard enforcement on write)
 *   - firestore.rules                 (field validation)
 *
 * §15.2 duration: 3–60s. `maxDurationSeconds` used to be 180 here while the
 * dead reelsConfig said 60, and the UI copy said 3 minutes — three different
 * answers for one rule. It is 60 now, and the client copy follows.
 *
 * §15.2 size: the spec target is 500MB, but the Cloud Functions gen2 /tmp is
 * 512MB and editPipeline downloads the whole source there, so 500MB cannot
 * work today. `maxBytes` stays at the safe 100MB that Storage rules already
 * enforce; raising it is an infrastructure change, not a client change.
 */
const EDITS_CONFIG = Object.freeze({
  fanThreshold: 5,
  minDurationSeconds: 3,
  maxDurationSeconds: 60,
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

/** §15.7 tag limits — validated server-side; the client only pre-cleans text. */
const TAG_LIMITS = Object.freeze({
  hashtagsMax: 12,
  hashtagMaxLength: 64,
  characterIdsMax: 8,
  characterIdMaxLength: 128,
});

module.exports = { EDITS_CONFIG, TAG_LIMITS, DAY };
