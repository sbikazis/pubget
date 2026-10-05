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
  // §15.9 exploration share of the Reels feed. Tunable, not hard text.
  explorationShare: 0.2,
  // Cap on how many watched Reels feed the repetition penalty.
  seenHistoryLimit: 300,
  prefetchAhead: 1,
  captionMax: 1000,
  commentMax: 500,
  stickerMax: 32,
  mentionMax: 8,
  repostWindowMs: 30 * DAY,
  schemaVersion: 2,
});

/**
 * §15.2 rendition ladder.
 *
 * `height` is the VERTICAL height of the 9:16 frame (1080x1920 -> 1920), which
 * is what `buildRenditionEncodeArgs` turns into a width via the 9:16 ratio.
 * Rungs are listed best-first; `selectRenditions` keeps that order and the
 * first surviving rung owns the canonical `videoUrl`.
 *
 * The primary rung keeps the historic path/name
 * (`edits-processed/{uid}/{editId}.mp4`) so existing players, cached rows and
 * stored `videoUrl` stay valid. The extra rungs are additive suffixed siblings,
 * which the `edits-processed/{userId}/{fileName}` Storage rule already matches.
 *
 * `blurPad: true` is required for every rung because the Instagram-style
 * backdrop is a generated canvas, not source pixels — it must be re-rendered at
 * each rung's dimensions rather than downscaled.
 */
const EDIT_RENDITIONS = Object.freeze([
  Object.freeze({ key: 'master', label: '1080p', height: 1920, crf: 25, audioKbps: 128, preset: 'veryfast', blurPad: true }),
  Object.freeze({ key: '720', label: '720p', height: 1280, crf: 26, audioKbps: 128, preset: 'veryfast', blurPad: true }),
  Object.freeze({ key: '480', label: '480p', height: 854, crf: 28, audioKbps: 96, preset: 'veryfast', blurPad: true }),
]);

/** §15.2 upload quota — server is truth, so the cap lives here only. */
const EDIT_UPLOAD_QUOTA = Object.freeze({
  /** Successful `startUpload` reservations per creator per UTC day. */
  dailyUploads: 20,
  /** Reserved quota rows retained for forensics (reservations that became posts). */
  retentionDays: 14,
});

/** §15.7 tag limits — validated server-side; the client only pre-cleans text. */
const TAG_LIMITS = Object.freeze({
  hashtagsMax: 12,
  hashtagMaxLength: 64,
  characterIdsMax: 8,
  characterIdMaxLength: 128,
});

module.exports = { EDITS_CONFIG, TAG_LIMITS, EDIT_RENDITIONS, EDIT_UPLOAD_QUOTA, DAY };
