"use strict";

// Server-authoritative aggregates for `anime_stats/{animeId}`.
//
// The Anime Hub charts read these fields and nothing else: a client that
// cannot see a distribution must render an unavailable state rather than
// rebuild one from the handful of reviews it happened to load. To keep that
// promise honest the three properties below hold everywhere:
//
//   * absolute — a value is a count of source documents, never a guess
//   * clamped  — a counter can never go negative, so a replay converges
//   * canonical — legacy status spellings are normalised before they are
//                 counted, so a status change moves the right bucket
//
// `SCORE_BUCKETS` is deliberately 1..10 and has no 0: a rating whose criteria
// are all zero has no score to plot, and inventing one would be a lie. Such a
// rating still moves `ratingCount` and `scoreSum`, so the distribution can sum
// to less than `ratingCount`; that is the honest reading, not a bug.

const SCORE_BUCKETS = Object.freeze(["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]);
const LIST_STATUSES = Object.freeze([
  "want_to_watch",
  "watching",
  "completed",
  "watch_later",
  "not_interested",
]);

// Statuses written before the five-state model. Mirrors the aliases the list
// domain already accepts, so an aggregate seeded from a legacy document lands
// in the same bucket as a fresh write.
const LEGACY_STATUS_ALIASES = Object.freeze({
  plan_to_watch: "want_to_watch",
  on_hold: "watch_later",
  dropped: "not_interested",
  favorites: "want_to_watch",
});

function canonicalStatus(status) {
  if (typeof status !== "string") return null;
  if (LIST_STATUSES.includes(status)) return status;
  return LEGACY_STATUS_ALIASES[status] || null;
}

/**
 * Bucket for a stored `overall`. Returns null when the score cannot be plotted
 * (absent, non-numeric, or rounds outside 1..10) so callers skip it instead of
 * coercing it into a neighbouring bucket.
 */
function scoreBucket(overall) {
  const value = Number(overall);
  if (!Number.isFinite(value)) return null;
  const rounded = Math.round(value);
  if (rounded < 1 || rounded > 10) return null;
  return String(rounded);
}

function emptyScoreDistribution() {
  const out = {};
  for (const bucket of SCORE_BUCKETS) out[bucket] = 0;
  return out;
}

function emptyStatusCounts() {
  const out = {};
  for (const status of LIST_STATUSES) out[status] = 0;
  return out;
}

function positiveInt(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : 0;
}

/** A stored number that is absent, non-numeric, or negative reads as zero. */
function nonNegative(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

/** True when a document already publishes a distribution the server maintains. */
function hasScoreDistribution(data) {
  const stored = data && data.scoreDistribution;
  return Boolean(stored) && typeof stored === "object";
}

/** True when a document already publishes status counts the server maintains. */
function hasStatusCounts(data) {
  const stored = data && data.statusCounts;
  return Boolean(stored) && typeof stored === "object";
}

/** Reads a stored distribution, tolerating a missing or partial document. */
function readScoreDistribution(data) {
  const stored = data && data.scoreDistribution;
  const out = emptyScoreDistribution();
  if (!stored || typeof stored !== "object") return out;
  for (const bucket of SCORE_BUCKETS) out[bucket] = positiveInt(stored[bucket]);
  return out;
}

/** Reads stored per-status counts, folding legacy spellings into canonical keys. */
function readStatusCounts(data) {
  const stored = data && data.statusCounts;
  const out = emptyStatusCounts();
  if (!stored || typeof stored !== "object") return out;
  for (const key of Object.keys(stored)) {
    const status = canonicalStatus(key);
    if (!status) continue;
    out[status] += positiveInt(stored[key]);
  }
  return out;
}

/** Moves one rating in or out of a bucket. `delta` is +1 or -1. */
function applyScoreDelta(distribution, bucket, delta) {
  if (!bucket) return distribution;
  const next = { ...distribution };
  const current = positiveInt(next[bucket]);
  next[bucket] = Math.max(0, current + (delta < 0 ? -1 : 1));
  return next;
}

/** Moves one list entry in or out of a status bucket. `delta` is +1 or -1. */
function applyStatusDelta(statusCounts, status, delta) {
  const canonical = canonicalStatus(status);
  if (!canonical) return statusCounts;
  const next = { ...statusCounts };
  const current = positiveInt(next[canonical]);
  next[canonical] = Math.max(0, current + (delta < 0 ? -1 : 1));
  return next;
}

function distributionTotal(distribution) {
  return SCORE_BUCKETS.reduce((sum, bucket) => sum + positiveInt(distribution && distribution[bucket]), 0);
}

function statusTotal(statusCounts) {
  return LIST_STATUSES.reduce((sum, status) => sum + positiveInt(statusCounts && statusCounts[status]), 0);
}

function round1(value) {
  return Math.round(Number(value) * 10) / 10;
}

// ---------------------------------------------------------------------------
// Absolute recompute
// ---------------------------------------------------------------------------
//
// The migration path is an absolute recompute rather than a delta replay: it
// walks the source rows and rebuilds every number, so running it twice gives
// the same answer as running it once. The two row readers below are shared by
// the backfill script and its tests so the bucketing rules can never drift
// between the migration and the live write path.

function emptyAggregate() {
  return {
    ratingCount: 0,
    scoreSum: 0,
    listedCount: 0,
    scoreDistribution: emptyScoreDistribution(),
    statusCounts: emptyStatusCounts(),
  };
}

/** Folds one stored anime rating row into a recomputed aggregate. */
function addRatingRow(aggregate, row) {
  const data = row || {};
  const overall = Number(data.overall);
  aggregate.ratingCount += 1;
  if (Number.isFinite(overall)) aggregate.scoreSum += overall;
  aggregate.scoreDistribution = applyScoreDelta(
    aggregate.scoreDistribution,
    scoreBucket(overall),
    1,
  );
  return aggregate;
}

/**
 * Folds one stored anime list row in. A row whose status is neither a
 * current state nor a known legacy spelling is skipped: it cannot be counted
 * honestly, and counting it as "somewhere else" would be a guess.
 */
function addListEntryRow(aggregate, row) {
  const status = canonicalStatus(row && row.status);
  if (!status) return aggregate;
  aggregate.listedCount += 1;
  aggregate.statusCounts = applyStatusDelta(aggregate.statusCounts, status, 1);
  return aggregate;
}

/** The anime id a source row belongs to, falling back to the document id. */
function animeIdOf(row, docId) {
  const data = row || {};
  return typeof data.animeId === "string" && data.animeId ? data.animeId : docId;
}

/** True when a stored document already agrees with a recomputed aggregate. */
function aggregateMatches(current, aggregate) {
  const data = current || {};
  // An absent field reads as zero rather than "unknown", so a title that only
  // ever collected list entries is not rewritten on every migration run.
  if (nonNegative(data.ratingCount) !== aggregate.ratingCount) return false;
  if (round1(nonNegative(data.scoreSum)) !== round1(aggregate.scoreSum)) return false;
  if (nonNegative(data.listedCount) !== aggregate.listedCount) return false;
  // Presence is part of the match, not just the numbers. A document with no
  // distribution field yet is exactly the pre-migration case this script
  // exists to repair, so reading it as all-zero must not convince the script
  // there is nothing to publish — otherwise a title whose only ratings are
  // unplottable would stay permanently "unavailable" in the client.
  if (!hasScoreDistribution(data) || !hasStatusCounts(data)) return false;
  const storedDistribution = readScoreDistribution(data);
  for (const bucket of SCORE_BUCKETS) {
    if (storedDistribution[bucket] !== aggregate.scoreDistribution[bucket]) return false;
  }
  const storedCounts = readStatusCounts(data);
  for (const status of LIST_STATUSES) {
    if (storedCounts[status] !== aggregate.statusCounts[status]) return false;
  }
  return true;
}

/** The exact field patch the migration writes onto an existing stats document. */
function aggregateFields(aggregate, updatedAt) {
  return {
    ratingCount: aggregate.ratingCount,
    scoreSum: round1(aggregate.scoreSum),
    averageScore:
      aggregate.ratingCount === 0 ? 0 : round1(aggregate.scoreSum / aggregate.ratingCount),
    listedCount: aggregate.listedCount,
    scoreDistribution: aggregate.scoreDistribution,
    statusCounts: aggregate.statusCounts,
    updatedAt,
  };
}

module.exports = {
  SCORE_BUCKETS,
  LIST_STATUSES,
  LEGACY_STATUS_ALIASES,
  canonicalStatus,
  scoreBucket,
  emptyScoreDistribution,
  emptyStatusCounts,
  hasScoreDistribution,
  hasStatusCounts,
  readScoreDistribution,
  readStatusCounts,
  applyScoreDelta,
  applyStatusDelta,
  distributionTotal,
  statusTotal,
  round1,
  emptyAggregate,
  addRatingRow,
  addListEntryRow,
  animeIdOf,
  aggregateMatches,
  aggregateFields,
};
