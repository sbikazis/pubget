# Phase-01 Firestore Index Audit

Date: 2026-09-21
Rule applied: only add an index when the query is **proven to run against production** from a wired
path (onCall export or scheduled trigger), or used by the client.

## Baseline

`firestore.indexes.json` carried **44** composite indexes covering edits/groups/respects/mafia_games/
privateChats/events/games/game_history/fanWorks/economyTransactions/anime_lists/anime_stats/reels.
All existing entries were re-verified against their callers; none is orphaned.

## PROVEN MISSING → added (2)

| # | Collection | Index | Query (live path) | Impact when missing |
|---|---|---|---|---|
| 1 | `friendships` | `userIds` array-contains + `status` (ASC) | `recommendationEngine.js:61-72` `friendships.where(userIds,array-contains,uid).where(status,==,accepted/blocked)` — runs on every `getDiscoveryFeed` | Query throws `FAILED_PRECONDITION`; is swallowed by `.catch(() => ({docs:[]}))`, so friend/blocks silently drop from discovery |
| 2 | `games` | `status` (ASC) + `waitingDeadlineAt` (ASC) | `gamesDomain.js:1292-1297` `processExpiredGames` (scheduled every 1 min) `.where(status,==,"WAITING").where(waitingDeadlineAt,<=,now).orderBy(waitingDeadlineAt)` | Waiting-lobby auto-cancel silently fails every cycle |

Both are **live production paths**; approved under the "only when proven needed" rule.
REVIEW-CAUGHT CORRECTION: an initial draft also added `groups(isSearchable, __name__)` for the
`refreshGroupActivityScores` cursor query. That is invalid Firestore (single-field composite + `__name__`) —
the automatic single-field index already serves `.where(isSearchable,==).orderBy(__name__)`. It was REJECTED
by the repo's own contract test `firestore_indexes_test.dart` ("composite indexes are not redundant
single-field + __name__ entries") and removed before commit.

All three are **live production paths**; approved under the "only when proven needed" rule.

## Checked and NOT needing an index

- `groups isSearchable + createdAt` (existing), `+ lastMessageAt` (existing), `+ searchName` (existing).
- `games status + deadlineAt` (existing) covers the `IN_PROGRESS` path (`gamesDomain.js:1325-1330`).
- `messages where createdAt >= cutoff orderBy createdAt desc` — single field range+order → no composite (`discoveryEngine.js:99-102`).
- `events status+endAt/startAt` (existing), `respects fromUserId+toUserId` (existing).
- `groups isSearchable + __name__` cursor paging (`discoveryEngine.js:81-92`) — served by the automatic
  single-field index; adding it as a composite is INVALID Firestore (rejected by contract test).
- `games status+type` in `mafiaDomain.processMafiaLifecycle` (`mafiaDomain.js:964`) is **dead code**
  (not exported in `index.js`) → explicitly NOT added.
- Reels/audio composite queries (`audioDomain.js`) are dead module code → explicitly NOT added.

## Current state

`firestore.indexes.json` now holds **46** entries (44 baseline + 2 proven additions). No deletions.
Status: needs to be deployed to production Firestore (managed index creation via `firebase firestore:indexes` when infra deploy runs).