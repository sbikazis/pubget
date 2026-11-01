# Phase-01 Rules Gate — Execution Protocol and Results

Date: 2026-09-21

## How to run (deterministic)

Requirements: JDK 21 (Firestore emulator), `firebase` CLI 15.x on PATH.

```bash
./scripts/run_rules_emulator_gate.sh
```

The runner validates the JDK major version (>=21), then executes
`firebase emulators:exec --project demo-pubget-security --only firestore,storage` running both rule
suites through the injected emulator host env (project id is the one the tests actually initialize:
`demo-pubget-security`).

## Coverage matrix (sensitive access paths already enforced + tested)

Firestore 49 tests (`functions/test/firestore.rules.test.js`):
- profile write ownership + coins are server-owned (`:181`)
- private profiles vs public projections separation (`:186`)
- group messages member-readable, callable-only-writable (`:212`)
- stale public projection rejected after privacy change (`:240`)
- public profile lists resist poisoned docs (`:251`)
- mafia lifecycle + private roles not client-writable (`:261`)
- private interaction data scoped to owner (`:265`)
- private-chat docs participant-readable, not client-writable (`:270`)
- private messages participant-readable, callable-only-writable (`:282`)
- events member-readable, never client-writable (`:300`)

Storage 12 tests (`functions/test/storage.rules.test.js`):
- avatar auth + UID ownership (`:53`), private avatars owner-only read (`:59`)
- group image changes only by Firestore group owner (`:93`)
- group media: membership + uploader path ownership (`:98`)
- immutable `*_original.*` for server pipeline (`:112`)
- character images: membership + path UID (`:138`)
- private-chat media participant-only (`:143`)
- MIME + size ceilings (`:174`)
- edit resumable updates owner-only (`:194`), group staging pre-create owner-write (`:212`)

## Results (REAL run, 2026-09-21)

| Suite | Pass | Fail | Exit |
|---|---|---|---|
| Firestore rules | **49** | **0** | **0** |
| Storage rules | **12** | **0** | **0** |

## Correction to prior artifacts

The earlier `.p01_state/P01_CLOSURE_*.txt` claimed "7 real storage.rules contract defects (5 pass/7 fail)".
That was an artifact of running the emulator under the DEFAULT project (`demo-pubget`) while the tests
initialize `demo-pubget-security`; with `--project demo-pubget-security` the **unmodified** rules are
12/12 green. No storage.rules change was needed; the defect list is retracted.