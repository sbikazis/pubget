# Production operation evidence — 2026-08-31

This appendix transcribes the non-secret command results produced in the interactive Replit Agent session for project `pubget-aaf27`. The chat/session transcript is the primary approval and execution record. This file makes the relevant identifiers and aggregate results reviewable with the repository; it is not an immutable Google Cloud audit export and does not replace a full data backup.

## Rules backup

Pre-rollout configuration snapshot:

- Directory: `backups/firebase-production-20260831T161330Z/`
- Firestore and Storage source files captured.
- Metadata includes project, release/ruleset names, capture timestamp, and SHA-256 values.

## Public-profile migration

Dry-run result:

```json
{
  "scannedUsers": 513,
  "existingPublicProfiles": 0,
  "missingPublicProfiles": 513,
  "profilesNeedingRefresh": 0
}
```

Apply result:

```json
{
  "scannedUsers": 513,
  "writtenPublicProfiles": 513
}
```

Post-apply structural verification:

```json
{
  "users": 513,
  "publicProfiles": 513,
  "missingProfiles": 0,
  "forbiddenFieldDocuments": 0,
  "malformedIdentityDocuments": 0
}
```

The forbidden-field check covered account/finance/subscription/moderation/token fields and did not print user content.

## Rules deployment receipt

Firebase CLI reported successful compilation and release of both rules files.

Post-release API comparison:

| Service | Ruleset | Deployed SHA-256 | Local SHA-256 | Exact |
|---|---|---|---|---|
| Firestore | `projects/pubget-aaf27/rulesets/e9e08477-1f07-45e8-84d7-b465b51360cc` | `26ddf69a2021f8351ab1a2f3ebe545d095cc590f2e66b647658b62e53fb9d09e` | Same | Yes |
| Storage | `projects/pubget-aaf27/rulesets/22a0ee4d-401a-4415-b4ef-2826c2ad2396` | `7a497a1f7daa56e6ef1aa97a84241ff354266cd24c83ba9166d0855ed1937bbf` | Same | Yes |

These hashes describe the deployed hardened files, not the earlier files in the backup directory. A mismatch with backup hashes is expected because the backup is the rollback source.

## Cloud Functions receipt

Firebase CLI reported successful create/update operations. A subsequent `firebase functions:list --json` reported these nine functions as `ACTIVE`:

- `disbandGroup`
- `leaveMafiaGame`
- `markDisconnectedPlayers`
- `onJoinRequest`
- `onNewGroupMessage`
- `onNewPrivateMessage`
- `processExpiredLobbies`
- `processPhaseTransitions`
- `syncPublicProfile`

Regions:

- `onJoinRequest`, message triggers, and `syncPublicProfile`: `europe-west1`
- callable and Mafia scheduled functions: `us-central1`

These regions are the session-transcript-derived output of `firebase functions:list`, not values inferred from the current source. The current Firestore trigger declarations do not specify a region, while the two callables explicitly specify `us-central1`. Existing deployed triggers were updated in `europe-west1`, and `syncPublicProfile` was reported there by the deployment/list output. This source/deployment-region divergence should be resolved by explicitly declaring the intended region before a future clean deployment.

## Mafia indexes and scheduler evidence

Firestore Admin API reported `READY` for:

- `mafia_games(status, countdownEndsAt, __name__)`
- `mafia_games(status, phaseEndsAt, __name__)`

Observed failures before fixes:

- `FAILED_PRECONDITION: The query requires an index`
- `Firestore transactions require all reads to be executed before all writes`

After index readiness and transaction/export corrections, scheduler logs showed informational invocations at:

- `processExpiredLobbies`: 2026-08-31T16:32:12Z, 16:33:11Z, 16:34:02Z, 16:35:04Z
- `processPhaseTransitions`: 2026-08-31T16:33:07Z, 16:34:14Z, 16:35:15Z

No prior index/transaction error appeared in those observed post-readiness cycles.

## Executed tests

`npm test` completed:

```text
tests 36
pass 36
fail 0
```

Composition:

- 27 Firestore rule tests executed through the emulator.
- 7 Storage rule tests executed through the emulator.
- 2 pure Mafia leave-transition unit tests.

The command also shut down the Firestore and Storage emulators cleanly.

## Approved unnamed-group deletion

The user was shown two destructive confirmations:

1. Delete full group trees rather than roots only.
2. Proceed with all 31 unnamed groups despite the discovery that they contained members/messages/data.

Safety guard immediately before deletion:

- Expected unnamed roots: 31
- Actual unnamed roots: 31
- Selection: missing, non-string, or whitespace-only `name`

Delete result:

| Collection level | Documents |
|---|---:|
| Group roots | 31 |
| `games` | 153 |
| `members` | 54 |
| `messages` | 3,836 |
| `requests` | 224 |
| `characters` | 141 |
| **Total** | **4,439** |

Verification:

```json
{
  "totalGroups": 113,
  "unnamedGroupsRemaining": 0,
  "residualDeletedGroupSubdocuments": 0
}
```

No full content export was created before this deletion. The approval and aggregate command outputs exist in the session transcript, but content recovery is not provided by this repository.

## Reproduction/independent verification commands

The following non-secret checks can be rerun by an authorized operator:

```bash
npm test
firebase functions:list --project pubget-aaf27 --json --non-interactive
firebase firestore:indexes --project pubget-aaf27 --json --non-interactive
```

Ruleset content and Firestore aggregate verification require an authorized Firebase CLI/API session. OAuth tokens and credential material must never be printed or checked in.
