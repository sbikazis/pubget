# Incident and recovery report

Report date: 2026-08-31  
Project: `pubget-aaf27`

## Evidence standard

This report distinguishes observed facts from hypotheses. It does not attribute activity to an attacker without identity, timestamp, and audit evidence. No credential contents, user profile data, message bodies, or personal identifiers are recorded here.

## Available evidence

- Current repository and Firebase configuration.
- Firestore and Storage rules before/after security hardening.
- Firebase CLI/API resource listing.
- Cloud Functions deployment state and scheduler logs.
- Aggregate Firestore counts and structural checks.
- Emulator test results.
- Configuration backup under `backups/firebase-production-20260831T161330Z/`.
- Session command-output transcript summarized in `PRODUCTION_EVIDENCE_20260831.md`.

The backup contains rules/configuration and metadata, not a full Firestore or Storage data export.
The production evidence appendix is a transcript-derived audit summary, not an immutable Cloud Audit Log export.

## Observed abnormal data

### Unnamed group documents

A production read-only scan found:

- 144 total group roots before cleanup.
- 31 group roots with missing/non-string/blank `name`.
- No image fields on those 31 roots.
- The roots were not empty: they referenced or contained founder/counter/last-message metadata and direct subcollections.

Direct child documents discovered before deletion:

- 54 members
- 3,836 messages
- 224 requests
- 153 games
- 141 characters

No conclusion can be drawn from this structure alone about compromise. Plausible explanations include interrupted/legacy creation flows, old schema behavior, client defects, or unauthorized writes under earlier permissive rules.

### Public-profile absence before migration

A production scan found 513 private user documents and zero public-profile documents before the projection backfill. This was a migration prerequisite, not proof of compromise.

## Production actions ledger

### Security configuration rollout

**Action:** Backfilled 513 `public_profiles`, deployed Cloud Functions, Firestore rules, Storage rules, and required Firestore indexes.  
**Reason:** Prevent client privacy/authority breakage when switching reads to server-owned public profiles and activating stricter rules.  
**Evidence:** 513/513 count verification; sensitive-field structural scan reported zero forbidden fields; deployed rule SHA-256 hashes matched local files; all nine functions reported `ACTIVE`; scheduler indexes reached `READY`.  
**Rollback:** Pre-rollout rule/configuration snapshot is available in `backups/firebase-production-20260831T161330Z/`. Data projection rollback requires an explicit migration decision; deleting public profiles is not recommended while current clients depend on them.

### Unnamed group cleanup

**Action:** Recursively deleted the 31 confirmed unnamed group roots and all discovered direct child documents after two explicit confirmations of destructive scope.  
**Reason:** User-directed cleanup of groups without names, including associated data.  
**Deterministic selection:** Root `groups` documents whose `name` was missing, non-string, or blank after trimming. The operation used a safety guard requiring exactly 31 matching roots immediately before deletion.  
**Deleted:** 4,439 Firestore documents total: 31 roots plus 4,408 child documents across `games`, `members`, `messages`, `requests`, and `characters`.  
**Verification:** 113 group roots remained; zero unnamed roots remained; zero documents remained in the checked child paths for deleted roots.  
**Recovery:** No full content backup was created for these records. Recovery is not available from this repository; only Firebase/Google-managed retention or external exports, if any, could restore content.

## Scheduler incident discovered during rollout

`processExpiredLobbies` initially logged `FAILED_PRECONDITION` because the required `mafia_games(status, countdownEndsAt)` index did not exist. After the index became ready, execution exposed a Firestore transaction ordering error: a group read occurred after a game write.

The transaction was corrected to perform reads before writes. A second index for `mafia_games(status, phaseEndsAt)` was added, and `processPhaseTransitions` was restored to exports after identifying an overwritten module export. Subsequent scheduler log entries showed normal informational invocations without the prior errors.

## What is proven

- Earlier production rules were materially more permissive than the deployed hardened rules.
- Unnamed groups existed and contained substantial child data.
- The approved cleanup removed the selected roots and checked child paths.
- Scheduler failures existed and were corrected.
- Current rules deny the tested unauthorized operations.

## What is not proven

- A compromised UID or named attacker.
- The creator or cause of malformed group roots.
- Whether any historical balance, premium, role, or Mafia result was forged.
- The exact creation timestamps of all abnormal records.
- Complete historical access logs for every Firestore/Storage read and write.
- Recovery of the deleted group content.

## Future incident procedure

1. Freeze criteria; do not label records malicious from shape alone.
2. Capture a full Firestore/Storage export before destructive recovery.
3. Preserve Cloud Audit Logs and function logs with absolute timestamps.
4. Generate a dry-run manifest containing paths, reason codes, evidence source, and proposed action.
5. Require explicit approval for delete/repair.
6. Prefer archive/quarantine where data ownership or intent is uncertain.
7. Verify aggregate counts and invariants after mutation.
