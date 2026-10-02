"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  SCORE_BUCKETS,
  LIST_STATUSES,
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
} = require("../src/animeStats");

test("the distribution is exactly 1-10 and the breakdown is exactly the five states", () => {
  assert.deepEqual([...SCORE_BUCKETS], ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]);
  assert.equal(SCORE_BUCKETS.length, 10);
  assert.deepEqual(
    [...LIST_STATUSES],
    ["want_to_watch", "watching", "completed", "watch_later", "not_interested"],
  );
});

test("a score is bucketed by rounding, and only when it lands in 1-10", () => {
  assert.equal(scoreBucket(8.4), "8");
  assert.equal(scoreBucket(8.5), "9");
  assert.equal(scoreBucket(10), "10");
  assert.equal(scoreBucket(1), "1");
  assert.equal(scoreBucket(0), null, "zero has no bucket to plot");
  assert.equal(scoreBucket(0.4), null);
  assert.equal(scoreBucket(10.6), null);
  assert.equal(scoreBucket(-1), null);
  assert.equal(scoreBucket(null), null);
  assert.equal(scoreBucket("nope"), null);
});

test("every legacy status spelling folds into a current state", () => {
  assert.equal(canonicalStatus("plan_to_watch"), "want_to_watch");
  assert.equal(canonicalStatus("on_hold"), "watch_later");
  assert.equal(canonicalStatus("dropped"), "not_interested");
  assert.equal(canonicalStatus("favorites"), "want_to_watch");
  for (const status of LIST_STATUSES) assert.equal(canonicalStatus(status), status);
  assert.equal(canonicalStatus("invented"), null);
  assert.equal(canonicalStatus(undefined), null);
});

test("a missing or partial document reads as a full set of zeros", () => {
  assert.equal(distributionTotal(readScoreDistribution(undefined)), 0);
  assert.equal(distributionTotal(readScoreDistribution({})), 0);
  assert.equal(distributionTotal(readScoreDistribution({ scoreDistribution: "junk" })), 0);
  assert.equal(statusTotal(readStatusCounts(undefined)), 0);
  assert.equal(statusTotal(readStatusCounts({ statusCounts: 7 })), 0);
  assert.deepEqual(
    readScoreDistribution({ scoreDistribution: { "8": 3 } }),
    { ...emptyScoreDistribution(), "8": 3 },
  );
});

test("reading folds legacy aggregate keys and drops unusable values", () => {
  const counts = readStatusCounts({
    statusCounts: { on_hold: 2, dropped: 1, invented: 5, watching: "x", completed: -4 },
  });
  assert.equal(counts.watch_later, 2);
  assert.equal(counts.not_interested, 1);
  assert.equal(counts.completed, 0, "a negative count reads as zero");
  assert.equal(counts.watching, 0, "a non-numeric count reads as zero");
  assert.equal(statusTotal(counts), 3);
});

test("a delta moves one bucket and clamps at zero", () => {
  let distribution = emptyScoreDistribution();
  distribution = applyScoreDelta(distribution, "7", 1);
  distribution = applyScoreDelta(distribution, "7", 1);
  assert.equal(distribution["7"], 2);
  distribution = applyScoreDelta(distribution, "7", -1);
  distribution = applyScoreDelta(distribution, "7", -1);
  assert.equal(distribution["7"], 0);
  distribution = applyScoreDelta(distribution, "7", -1);
  assert.equal(distribution["7"], 0, "a counter never goes negative");
});

test("deltas never mutate the distribution they were handed", () => {
  const original = emptyScoreDistribution();
  const next = applyScoreDelta(original, "5", 1);
  assert.equal(original["5"], 0);
  assert.equal(next["5"], 1);
  const statuses = emptyStatusCounts();
  const moved = applyStatusDelta(statuses, "watching", 1);
  assert.equal(statuses.watching, 0);
  assert.equal(moved.watching, 1);
});

test("an unplottable score and an unknown status move nothing", () => {
  const distribution = applyScoreDelta(emptyScoreDistribution(), scoreBucket(0), 1);
  assert.equal(distributionTotal(distribution), 0);
  const counts = applyStatusDelta(emptyStatusCounts(), "invented", 1);
  assert.equal(statusTotal(counts), 0);
});

// ---------------------------------------------------------------------------
// Absolute recompute (the backfill path)
// ---------------------------------------------------------------------------

test("the recompute rebuilds counts, sums, distribution, and breakdown together", () => {
  let aggregate = emptyAggregate();
  addRatingRow(aggregate, { overall: 8.5 });
  addRatingRow(aggregate, { overall: 6.4 });
  addListEntryRow(aggregate, { status: "watching" });
  addListEntryRow(aggregate, { status: "on_hold" });
  assert.equal(aggregate.ratingCount, 2);
  assert.equal(aggregate.scoreSum, 14.9);
  assert.equal(aggregate.listedCount, 2);
  assert.equal(aggregate.scoreDistribution["9"], 1, "8.5 rounds up into 9");
  assert.equal(aggregate.scoreDistribution["6"], 1);
  assert.equal(aggregate.statusCounts.watching, 1);
  assert.equal(aggregate.statusCounts.watch_later, 1, "on_hold folds into watch_later");
});

test("the recompute is idempotent — replaying the same rows changes nothing", () => {
  const rows = [
    { overall: 8.5 },
    { overall: 3 },
    { overall: 0 },
  ];
  const listRows = [{ status: "watching" }, { status: "completed" }];
  const run = () => {
    let aggregate = emptyAggregate();
    for (const row of rows) addRatingRow(aggregate, row);
    for (const row of listRows) addListEntryRow(aggregate, row);
    return aggregate;
  };
  const first = run();
  const second = run();
  assert.deepEqual(second, first);
});

test("the recompute skips a list row with no status it can count honestly", () => {
  const aggregate = emptyAggregate();
  addListEntryRow(aggregate, { status: "invented" });
  addListEntryRow(aggregate, {});
  assert.equal(aggregate.listedCount, 0);
  assert.equal(statusTotal(aggregate.statusCounts), 0);
});

test("a rating with no plottable score still counts as a rating", () => {
  const aggregate = emptyAggregate();
  addRatingRow(aggregate, { overall: 0 });
  addRatingRow(aggregate, { overall: "junk" });
  assert.equal(aggregate.ratingCount, 2);
  assert.equal(distributionTotal(aggregate.scoreDistribution), 0);
});

test("the anime id comes from the row, falling back to the document id", () => {
  assert.equal(animeIdOf({ animeId: "16498" }, "doc-id"), "16498");
  assert.equal(animeIdOf({}, "doc-id"), "doc-id");
  assert.equal(animeIdOf({ animeId: "" }, "doc-id"), "doc-id");
});

test("a migrated document is recognised so a second run writes nothing", () => {
  let aggregate = emptyAggregate();
  addRatingRow(aggregate, { overall: 8.5 });
  addListEntryRow(aggregate, { status: "watching" });
  const fields = aggregateFields(aggregate, "NOW");
  assert.equal(aggregateMatches(fields, aggregate), true);
  assert.equal(fields.averageScore, 8.5);
  assert.equal(fields.scoreSum, 8.5);
});

test("a pre-migration document is recognised as needing a write", () => {
  const aggregate = emptyAggregate();
  addRatingRow(aggregate, { overall: 8.5 });
  addListEntryRow(aggregate, { status: "watching" });
  // Exactly what the older deploy left behind.
  assert.equal(
    aggregateMatches({ ratingCount: 1, scoreSum: 8.5, averageScore: 8.5, listedCount: 1 }, aggregate),
    false,
    "a document with no distribution is not migrated",
  );
  // A drifted number is caught too, which is what makes the run self-healing.
  assert.equal(
    aggregateMatches({ ...aggregateFields(aggregate, "NOW"), ratingCount: 7 }, aggregate),
    false,
  );
});

test("a pre-migration document whose legacy key already matches is not rewritten needlessly", () => {
  const aggregate = emptyAggregate();
  addListEntryRow(aggregate, { status: "on_hold" });
  // The stored key is the legacy spelling, but it normalises to the same
  // canonical bucket the recompute produced, so it must not count as drift.
  const stored = aggregateFields(aggregate, "NOW");
  stored.statusCounts = { on_hold: 1 };
  assert.equal(aggregateMatches(stored, aggregate), true);
  const canonical = aggregateFields(aggregate, "NOW");
  canonical.statusCounts = { watch_later: 1 };
  assert.equal(aggregateMatches(canonical, aggregate), true);
  // A document that predates the migration has neither field, whatever its
  // counts say, and is written once to publish them.
  assert.equal(
    aggregateMatches({ listedCount: 1, statusCounts: { on_hold: 1 } }, aggregate),
    false,
  );
});

test("presence is tracked separately from the numbers", () => {
  // A missing aggregate and an all-zero one read as the same numbers, so only
  // an explicit presence check can keep them apart. That distinction is the
  // whole point: the client shows "not counted yet" for a missing aggregate,
  // and a real all-zero aggregate is a different fact with a different UI.
  assert.equal(hasScoreDistribution(undefined), false);
  assert.equal(hasScoreDistribution({}), false);
  assert.equal(hasScoreDistribution({ scoreDistribution: null }), false);
  assert.equal(hasScoreDistribution({ scoreDistribution: "nope" }), false);
  assert.equal(hasScoreDistribution({ scoreDistribution: emptyScoreDistribution() }), true);
  assert.equal(hasStatusCounts({}), false);
  assert.equal(hasStatusCounts({ statusCounts: emptyStatusCounts() }), true);
});

test("a document whose only ratings are unplottable is still migrated", () => {
  // Zero scores raise the rating count but land in no bucket. If the script
  // compared the (absent) numbers against an all-zero recompute it would call
  // the document converged and never publish, leaving the chart permanently
  // unavailable for that title.
  const aggregate = emptyAggregate();
  addRatingRow(aggregate, { overall: 0 });
  assert.equal(aggregate.ratingCount, 1);
  assert.equal(distributionTotal(aggregate.scoreDistribution), 0);
  assert.equal(
    aggregateMatches({ ratingCount: 1, scoreSum: 0, averageScore: 0 }, aggregate),
    false,
    "the absent distribution must be published even though it is all zero",
  );
  const migrated = aggregateFields(aggregate, "NOW");
  assert.equal(hasScoreDistribution(migrated), true);
  assert.equal(aggregateMatches(migrated, aggregate), true, "and it converges once written");
});

test("the recompute never produces a plot count above the rating count", () => {
  const aggregate = emptyAggregate();
  for (const overall of [1, 4, 7, 10, 10, 0, 5.5]) addRatingRow(aggregate, { overall });
  assert.ok(distributionTotal(aggregate.scoreDistribution) <= aggregate.ratingCount);
});

test("a doc that only ever collected list entries is not rewritten every run", () => {
  const aggregate = emptyAggregate();
  addListEntryRow(aggregate, { status: "watching" });
  // No scoreSum / ratingCount at all: absence means zero here, not "unknown".
  // The one write that publishes the aggregates is what makes every later run
  // a no-op, so this must hold for the canonical document the script writes.
  const stored = aggregateFields(aggregate, "NOW");
  assert.equal(aggregateMatches(stored, aggregate), true);
  assert.equal(aggregateMatches(stored, aggregate), true);
});
