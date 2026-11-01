#!/usr/bin/env node
"use strict";

// Rebuilds the server-authoritative Anime Hub aggregates from the documents
// that are actually the source of truth.
//
//   anime_stats/{id}.scoreDistribution  <- users/*/anime_ratings/*
//   anime_stats/{id}.statusCounts        <- users/*/anime_lists/*
//
// Why this exists: the aggregates were introduced after ratings and list
// entries already existed, so the documents written back then carry counts
// with no distribution. The charts read these fields and nothing else, so an
// un-migrated title would render an unavailable state forever.
//
// Safety properties, in the order they matter:
//
//   * absolute, never incremental — every value is recomputed from the source
//     rows, so a second run produces the same numbers as the first. There is
//     no "already migrated" flag to get out of sync and no partial run that
//     can double-count.
//   * additive, never destructive — it writes aggregate fields onto existing
//     `anime_stats` documents and never deletes one. A title with no stats
//     document is skipped rather than created, and a title with no source rows
//     is left exactly as it is, which is safer than writing zeros over a
//     count a concurrent write is still moving.
//   * dry run by default — nothing is written without `--apply`.
//   * resumable — pass `--start-after <uid>` to continue an interrupted run.
//
// Order of operations (the safe sequence, not an optional suggestion):
//
//   1. deploy the functions that read the new fields defensively;
//   2. run this script as a dry run and read the reported deltas;
//   3. run it with `--apply`;
//   4. re-run with `--apply`; a clean run reports written=0.
//
// Concurrent writes are tolerated rather than blocked: a rating saved while the
// scan is in flight is picked up on the next run, and a rating that moves a
// bucket after its anime was written is corrected on the next run. Never stop
// accepting writes to run this.

const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldPath, Timestamp } = require("firebase-admin/firestore");
const {
  emptyAggregate,
  addRatingRow,
  addListEntryRow,
  animeIdOf,
  aggregateMatches,
  aggregateFields,
  distributionTotal,
  statusTotal,
} = require("../src/animeStats");

const args = process.argv.slice(2);
const apply = args.includes("--apply");

function option(name, fallback) {
  const index = args.indexOf(name);
  return index === -1 ? fallback : args[index + 1];
}

const pageSize = Number(option("--page-size", "250"));
const startAfter = option("--start-after", null);
const maxPages = Number(option("--max-pages", "0"));

if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 500) {
  throw new Error("--page-size must be an integer from 1 to 500");
}
if (!Number.isInteger(maxPages) || maxPages < 0) {
  throw new Error("--max-pages must be a non-negative integer");
}

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

async function collectAggregates() {
  const aggregates = new Map();
  let cursor = startAfter;
  let pages = 0;
  let scannedUsers = 0;
  let scannedRows = 0;

  do {
    let query = db.collection("users").orderBy(FieldPath.documentId()).limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) break;

    for (const userDoc of snapshot.docs) {
      const [ratings, lists] = await Promise.all([
        userDoc.ref.collection("anime_ratings").get(),
        userDoc.ref.collection("anime_lists").get(),
      ]);
      scannedUsers += 1;
      for (const row of ratings.docs) {
        const data = row.data() || {};
        const animeId = animeIdOf(data, row.id);
        if (!aggregates.has(animeId)) aggregates.set(animeId, emptyAggregate());
        addRatingRow(aggregates.get(animeId), data);
        scannedRows += 1;
      }
      for (const row of lists.docs) {
        const data = row.data() || {};
        const animeId = animeIdOf(data, row.id);
        if (!aggregates.has(animeId)) aggregates.set(animeId, emptyAggregate());
        addListEntryRow(aggregates.get(animeId), data);
        scannedRows += 1;
      }
    }

    cursor = snapshot.docs[snapshot.docs.length - 1].id;
    pages += 1;
    console.log(
      `page=${pages} users=${scannedUsers} rows=${scannedRows} ` +
      `anime=${aggregates.size} resumeAfter=${cursor}`,
    );
    if (maxPages && pages >= maxPages) break;
    if (snapshot.size < pageSize) break;
  } while (true);

  console.log(`scanned users=${scannedUsers} rows=${scannedRows} anime=${aggregates.size}`);
  return aggregates;
}

async function main() {
  const aggregates = await collectAggregates();
  let written = 0;
  let alreadyCorrect = 0;
  let skippedNoStatsDoc = 0;

  for (const animeId of [...aggregates.keys()].sort()) {
    const aggregate = aggregates.get(animeId);
    const ref = db.collection("anime_stats").doc(animeId);
    const snap = await ref.get();
    if (!snap.exists) {
      // Nothing to repair: with no stats document no chart is being drawn from
      // a wrong number, and the next write seeds the aggregates correctly.
      skippedNoStatsDoc += 1;
      continue;
    }
    if (aggregateMatches(snap.data(), aggregate)) {
      alreadyCorrect += 1;
      continue;
    }
    if (apply) {
      await ref.update(aggregateFields(aggregate, Timestamp.now()));
    }
    written += 1;
  }

  const mode = apply ? "APPLY" : "DRY RUN (pass --apply to write)";
  console.log(
    `${mode} written=${written} alreadyCorrect=${alreadyCorrect} ` +
    `skippedNoStatsDoc=${skippedNoStatsDoc}`,
  );
  if (apply) {
    // A plot count above the rating count, or statuses above the listed count,
    // would mean the scan and the live writers disagree about the source rows.
    let plotsBeyond = 0;
    let statusesBeyond = 0;
    for (const aggregate of aggregates.values()) {
      if (distributionTotal(aggregate.scoreDistribution) > aggregate.ratingCount) plotsBeyond += 1;
      if (statusTotal(aggregate.statusCounts) > aggregate.listedCount) statusesBeyond += 1;
    }
    console.log(`sanity plotsBeyondRatingCount=${plotsBeyond} statusesBeyondListedCount=${statusesBeyond}`);
    console.log("re-run with --apply to confirm convergence (a clean run reports written=0)");
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
