# Anime Hub statistics aggregates — backfill and migration runbook

## What is being migrated

The Anime Hub statistics tab reads two server-owned aggregates on
`anime_stats/{animeId}`:

| Field                 | Buckets                                 | Source of truth                          |
| --------------------- | --------------------------------------- | ---------------------------------------- |
| `scoreDistribution`   | `"1"` … `"10"`                          | every member's `anime_ratings` document  |
| `statusCounts`        | `want_to_watch`, `watching`, `completed`, `watch_later`, `not_interested` | every member's `anime_lists` document |

Both are maintained inside the same Firestore transaction that already moves
`scoreSum`/`ratingCount`/`listedCount`, in
[`src/animeHubDomain.js`](src/animeHubDomain.js) and
[`src/animeListsDomain.js`](src/animeListsDomain.js). The bucketing rules live
in one place, [`src/animeStats.js`](src/animeStats.js), so the live write path
and the migration can never disagree about what a bucket means.

Ratings and list entries existed before these fields did, so documents written
by the previous deploy carry counts with no distribution. Until they are
rebuilt, the client renders an **unavailable** state for that title — it never
reconstructs a distribution from the handful of reviews it happened to load.
Writes landing in that window do not change that: a live rating or list change
updates the counts it can prove and leaves the aggregate absent (rule 7), so no
member can turn "unavailable" into a chart covering one action.

## Why a backfill is needed at all

`statusCounts` in particular cannot be derived from the old `listedCount`: the
old document recorded *that* a title was listed but never *in which state*, so
moving a member from "watching" to "completed" left no trace to correct. The
only honest source is the per-member list entry itself.

## The rules the aggregates obey

1. **Absolute, never incremental.** Every value is a count of source
   documents. There is no stored "migrated" flag that can drift.
2. **Clamped at zero.** A counter can never go negative, so replaying a write
   converges instead of accumulating debt.
3. **Canonical statuses.** Legacy spellings (`plan_to_watch`, `on_hold`,
   `dropped`, `favorites`) are folded into current states on read, on both the
   entry and the stored count, so a legacy document leaves the bucket it was
   actually tallied under.
4. **No inference.** A bucket exists only for a score that rounds into 1–10.
   A rating with all-zero criteria counts as a rating but is never plotted,
   which is why the distribution can legitimately sum to less than
   `ratingCount`. That is the honest reading, not a bug.
5. **A rating moved to another bucket by a change, not added twice.** Re-rating
   the same score nets to zero; changing it releases the old bucket and enters
   the new one.
6. **Clients cannot write any of it.** `firestore.rules` denies every write to
   `anime_stats`; see the "a client cannot forge the score distribution" case in
   `test/firestore.rules.test.js`.
7. **A live write never completes an aggregate it did not build.** An aggregate
   field is only maintained on a document that already publishes it, so a rating
   or list change landing between the deploy and the backfill cannot leave a
   chart that describes just that one member's action. The field stays absent,
   the client keeps reading it as unavailable, and the backfill publishes the
   true totals from the source rows. A document the transaction itself creates
   is the exception: nothing predates it, so its aggregates are already complete.

## Procedure

### 0. Deploy first

Deploy the functions that read the new fields. They read defensively, so a
title whose document has no distribution renders unavailable rather than
erroring, and a write landing in this window does not invent one (rule 7).
This is why deploying before migrating is the safe order.

```bash
cd functions && npm run deploy
```

### 1. Dry run

Never write on the first pass.

```bash
cd functions && npm run backfill:anime-stats
```

Read the summary line:

```
DRY RUN (pass --apply to write) written=… alreadyCorrect=… skippedNoStatsDoc=…
```

- `written` — documents whose recomputed values differ or that do not publish the
  aggregates yet. Each one is a title that would show a wrong or missing chart
  today.
- `skippedNoStatsDoc` — titles with source rows but no `anime_stats` document
  at all. These are **not** created: there is no wrong number on screen to fix,
  and the next real write seeds the aggregates correctly, because nothing
  predates a document the transaction creates.

### 2. Apply

```bash
cd functions && npm run backfill:anime-stats -- --apply
```

Useful flags: `--page-size <1..500>`, `--max-pages <n>`, and
`--start-after <uid>` to resume an interrupted run (the progress line prints
`resumeAfter=<uid>`).

The apply run also prints a sanity line:

```
sanity plotsBeyondRatingCount=0 statusesBeyondListedCount=0
```

Both counters must be `0`. A non-zero value means the scan and the live writers
disagree about the source rows — stop and investigate rather than re-running.

### 3. Confirm convergence

```bash
cd functions && npm run backfill:anime-stats -- --apply
```

A converged migration reports `written=0`. Anything else means writes are still
landing between runs; re-run until it settles.

## Safety properties

- **Dry run by default.** Nothing is written without `--apply`.
- **Additive, never destructive.** It writes aggregate fields onto existing
  `anime_stats` documents. It never deletes a document, never deletes a source
  row, and never zeroes a title it found no rows for.
- **Idempotent.** Values are recomputed from scratch, so a second run produces
  the same numbers as the first. A partial run cannot double-count.
- **Resumable.** Paging is by user document id, and `--start-after` continues
  from the last user the scan reported.
- **Tolerates concurrent writes instead of requiring a freeze.** A rating saved
  while the scan is in flight is picked up on the next run. Never stop
  accepting writes to run this.

## Rollback

There is nothing to roll back. The script only sets fields it recomputed, and
the previous deploy's read path ignores them. To return to the old behaviour,
revert the functions deploy; the aggregates remain in place, inert, and are
picked up again on the next deploy.

## Verification

```bash
cd functions
npm test                 # includes test/animeStats.test.js and the two domain suites
npm run check            # syntax-checks the script alongside the sources
cd .. && ./scripts/run_rules_emulator_gate.sh
```

The rules gate needs JDK 21; see the header of
[`../scripts/run_rules_emulator_gate.sh`](../scripts/run_rules_emulator_gate.sh).
