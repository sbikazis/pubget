# Phase-01 Idempotency Contract for Sensitive Actions

Date: 2026-09-21
Rule: every **state-changing** onCall that is retried by the client (network flake, double-tap, retry) must
produce the same end state if executed twice. Enforcement era is a unique-keyed doc **created**
inside a transaction, or a deterministic document ID.

## Verified mechanisms per domain

| Sensitive action | Mechanism | Location |
|---|---|---|
| `createGroup` | optional client `idempotencyKey` → `users/{uid}/groupCreateKeys/{key}` (server `create()` in lock) | `groupsDomain.js:172-175` |
| `startEditUpload` / `finalizeEditUpload` | `idempotencyKey` → `editUploadKeys/{creatorId}_{key}` claimed in the write batch | `editsDomain.js:103-106, 163-164, 697` (finalize documented idempotent) |
| Economy grants/claims/transfers | deterministic `txId`; ledger `economyTransactions/{txId}` created once + per-user `transactions/{txId}`; duplicate detection (`reason: "duplicate"`) | `economyDomain.js:190-212, 245, 408-455, 561` |
| Mafia actions (all player actions) | `games/{id}/action_receipts/{uid}_{actionId}` claimed inside one transaction | `mafia/actionDomain.js:20-56` |
| Mafia game-history write | claimed inside one transaction (SEC-H-02) | `mafia/historyWriter.js:10` |
| Mafia rewards | `rewardsDistributed` flag on game doc → exactly-once distribution | `mafia/rewardDistributor.js:4` |
| `createGame`/`joinGame` | `game_request_idempotency/{uid}_{requestKey}` claimed in transaction; `startGame`/`advance` idempotent across internal transitions | `gamesDomain.js:620, 998, 1180` |
| `initializeGame` / `startGame` | double-transition guarded by `stateVersion` checks + event `eventId` uniqueness (`{gameId}_{kind}`) | `gamesDomain.js`/mafia events |
| `giveRespect` | deterministic doc ID `respects/{pair}` (retries overwrite the same doc; cooldown enforced) | `socialGraph.js:104` |
| Friend requests & responses | deterministic/paired doc IDs with transaction reads | `socialGraph.js` |
| Content moderation reports | unique per-user/target report keys | shared pattern |

## Client contract (required by retry paths)

1. For every **monetary or ownership transfer** and group/game/event creation, the client MUST send an
   `idempotencyKey` (UUID, 128-char bound) when available.
2. Idempotent success = same `{ ok: true }` on retry — clients must treat a repeated call like success.
3. Keys must NEVER depend on wall-clock dates (except server-side daily buckets, which are domain caps, not idempotency).

## Gap analysis (honest)

- `createGroup` handles missing key by falling through to a **non-idempotent** creation path
  (`idempotencyKey ? lock : create`) — a double-tap without a key can create two groups.
  Phase-01 action: contract documents the key; making the key **mandatory** is deferred to a behavior
  change phase (requires client + tests update) — tracked as OPEN-2.
- `giveRespect` is idempotent-by-keying but **not** idempotent-by-value (a retry with a different value
  overwrites). Mitigated by cooldown + value bounds; acceptable and documented here.
- Reels/audio (dead) have no contract and need none until the module is wired.