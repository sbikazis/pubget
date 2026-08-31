# Pubget security audit report

Audit date: 2026-08-31  
Scope: Flutter/Firebase authorization, privacy, Mafia lifecycle, messaging, Storage, Cloud Functions, incident evidence, and regression evidence.

## Executive summary

No verified Critical vulnerability remains in the reviewed authorization rules. The strongest verified controls are self-only private account reads, server-only financial/subscription fields, trusted public-profile projection, participant/member checks, sender identity binding, server-owned Mafia outcomes, and default-deny Storage paths.

Two High findings remain. They must not be represented as fixed:

1. Cross-group exposure of full Mafia history to any authenticated user.
2. A race in Mafia history/stat writing that can increment statistics more than once under concurrent/retried execution.

Production rollout and cleanup actions occurred before this report was finalized and are recorded in `INCIDENT_AND_RECOVERY_REPORT.md`. Aggregate command results and deployment identifiers are transcribed in `PRODUCTION_EVIDENCE_20260831.md`. Their execution is a scope deviation from the original audit-only task, but each destructive action had explicit user approval and post-action verification in the session transcript.

## Severity summary

| Severity | Open | Verified fixed/mitigated | Not verified |
|---|---:|---:|---:|
| Critical | 0 | 0 | 0 |
| High | 2 | 0 | 0 |
| Medium | 4 | Multiple authorization controls | App Check live behavior |
| Low | 2 | Replay prevention by deterministic IDs | Product intent for vote visibility |
| Informational | 4 | Default deny and trusted identity controls | Full Flutter device regression |

## Critical

No Critical issue was verified.

Direct client writes to currency, premium/subscription state, moderation fields, Mafia private roles, winners, and resolver state are denied by current rules.

## High

### SEC-H-01 — Cross-group Mafia history disclosure

**Status:** Open, verified by source inspection.  
**Resource:** `mafia_history/{gameId}`.  
**Evidence:** `firestore.rules`; `functions/src/mafia/historyWriter.js`.

The rule allows every authenticated user to read Mafia history. The server writer stores complete player details including role/team/outcome. A user who is not a participant or group member can therefore request another game's history.

**Risk:** Cross-tenant privacy disclosure and post-game role/history enumeration.

**Required remediation:** Restrict reads to authorized participants/group members, or create a sanitized public projection that excludes private role/team details. Add a negative emulator test for an unrelated authenticated user.

### SEC-H-02 — Non-transactional Mafia history idempotency

**Status:** Open, verified race by source inspection.  
**Resource:** History writing and per-user game statistics.  
**Evidence:** `functions/src/mafia/historyWriter.js`.

The writer reads `historyWritten` before constructing a batch that increments user statistics. Concurrent or retried invocations can both pass the initial check and both apply increments.

**Risk:** Inflated games/wins/losses and inconsistent completion markers.

**Required remediation:** Claim history writing transactionally or use a per-game, per-user idempotency ledger checked in the same transaction as each increment. Add a concurrent invocation test.

## Medium

### SEC-M-01 — App Check not enforced

**Status:** Open; absence verified, production effect not measured.  
**Evidence:** Callable declarations in `functions/index.js`.

Authentication and authorization are enforced, but callable endpoints do not use `enforceAppCheck`. Valid authenticated clients or automated scripts can generate abusive traffic.

**Risk:** Abuse, cost amplification, and automated callable replay. App Check is defense-in-depth and must not replace authorization.

### SEC-M-02 — Partial cleanup state during group disband

**Status:** Mitigated but residual risk remains.  
**Evidence:** `functions/index.js`; `firestore.rules`.

The deletion marker blocks clients while cleanup runs, and retries are supported. Storage is deleted before Firestore recursive deletion. A persistent Firestore failure can leave a blocked group and notifications/state awaiting retry.

**Required remediation:** Add structured cleanup outcome logs, an operator retry procedure, and an orphan detector for `deletionPending`.

### SEC-M-03 — Legacy media retention/privacy

**Status:** Open, product-policy dependent.  
**Evidence:** `storage.rules`.

Legacy group/DM media remains readable according to current membership/participation rather than message tombstone state. Edit media is authenticated-readable.

**Risk:** Removed message media can remain retrievable if its object path is known. Severity depends on intended public/private policy.

### SEC-M-04 — Reward completion race residual

**Status:** Partially mitigated.  
**Evidence:** `functions/src/mafia/rewardDistributor.js`.

Per-user fixed transaction IDs protect balance increments, but the game-level completion check occurs outside a transaction. Duplicate balance credit was not demonstrated; duplicate side effects or inconsistent completion state remain possible.

## Low

### SEC-L-01 — Client-controlled Mafia intent timestamps

`submittedAt` and vote `time` are not bounded to server time. Deterministic create-only IDs and authoritative phase checks prevent same-round overwrite/replay, but audit timestamps can be misleading.

### SEC-L-02 — Vote visibility

Group members can read vote documents during the game. This may permit vote sniping or collusion. Confirm intended game design before changing it.

## Informational and positive controls

- Private user roots are self-only; collection listing is denied.
- Public profiles are server-maintained and reject client writes.
- Message identity, role, avatar, and premium claims are compared with trusted data.
- Private chats enforce immutable participants and recipient-scoped receipts.
- Group client root deletion is denied; server cleanup is used.
- Storage has explicit supported paths, MIME limits, size ceilings, participant/member checks, and uploader ownership.
- Mafia role assignment, rewards, history, outcomes, and resolver state are server-controlled.
- Unsupported Firestore/Storage paths are denied by absence of an allow rule.

## Items not verified

- Full Flutter analyze/build/device regression: Flutter SDK was unavailable in this environment.
- Live registration, upload, message, and gameplay smoke tests using dedicated production test accounts: no test identities were created.
- App Check enforcement and metrics: not enabled/tested.
- Attribution of historical malformed records to a person, UID, exploit, or timestamp: evidence is insufficient.
- Completeness of Storage deletion outside known `groups/{groupId}/` prefixes.

## Recommended order

1. Fix SEC-H-01 and add cross-group history tests.
2. Fix SEC-H-02 with transactional idempotency and concurrency tests.
3. Complete the separate economy integrity task for remaining reward/subscription behavior.
4. Run the separate Flutter build/device task.
5. Roll out App Check in monitor-first mode as described in `APP_CHECK_ROLLOUT.md`.
