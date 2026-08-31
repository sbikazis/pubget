# Security and regression test evidence

Evidence date: 2026-08-31

Command and production results in this document are session-transcript-derived summaries, not immutable Cloud Audit Log evidence. Identifiers, aggregate output, provenance, and reproduction commands are retained in `PRODUCTION_EVIDENCE_20260831.md`.

## Executed checks

| Check | Result |
|---|---|
| Firestore rules through Emulator | 27 passed |
| Storage rules through Emulator | 7 passed |
| Pure Mafia leave-transition unit tests | 2 passed |
| Combined `npm test` result | 36 passed, 0 failed |
| JavaScript syntax checks for modified Mafia schedulers | Passed in the recorded session |
| `git diff --check` | Passed in the recorded session |
| Firestore rules compilation | Session transcript reports success with non-blocking unused helper/variable warnings |
| Storage rules compilation | Session transcript reports success |
| Cloud Functions deployment analysis/dry-run | Session transcript reports success |
| Production rule-content hash comparison | Session-transcript-derived API comparison reported exact Firestore/Storage matches |
| Production Cloud Functions state | Session-transcript-derived list reported 9 functions `ACTIVE` |
| Mafia indexes | Session-transcript-derived Admin API checks reported countdown and phase indexes `READY` |
| Post-fix scheduler logs | Session-transcript-derived logs showed informational invocations; prior errors did not recur in observed cycles |

## Legitimate-flow coverage

- Owner edits ordinary profile presentation data.
- Authenticated users read public profiles.
- Group member sends canonical text/media messages.
- Private-chat participant sends text, image, video, audio, and sticker messages.
- Recipient updates delivered/read receipts.
- Free/custom entitlement group creation.
- Applicant submits a join request with matching founder notification.
- Moderator accepts/rejects requests atomically.
- Member leaves and releases their own character reservation.
- Moderator removes a non-founder with the exact counter mutation.
- Group member creates and joins a waiting Mafia lobby.
- Living Mafia player submits canonical vote/chat/night intent.
- Storage owner/member/participant uploads to supported paths.

## Attack/negative coverage

- Cross-user private profile reads and user collection listing.
- Client public-profile creation/update/delete.
- Coin balance and protected account-field forgery.
- Group message sender ID/name/avatar/role/premium forgery.
- Private message sender/participant/receipt forgery.
- Oversized text and unsupported message/event types.
- Group member-counter, role, removal, and character-reservation forgery.
- Invalid Mafia player bounds, stale/far-future lobby expiry, wrong phases/numbers/targets.
- Client writes to Mafia outcomes/private roles.
- Cross-account sticker/rating/fan identifiers.
- Unauthorized Storage avatar/group/character/private-chat access.
- Unsupported MIME types, oversized media, and unreviewed Storage paths.

## Gaps requiring dedicated tests

- Cross-group `mafia_history` privacy rejection after SEC-H-01 is fixed.
- Concurrent/retried history writer execution after SEC-H-02 is fixed.
- Concurrent reward distribution and completion-marker behavior.
- Cleanup retry/orphan recovery after injected Storage or Firestore failure.
- App Check callable rejection and staged enforcement metrics.
- Full Flutter provider/model contract tests on a machine with Flutter SDK.
- Dedicated production test-account smoke flows for registration, messages, uploads, group lifecycle, and Mafia.

## Flutter limitation

Flutter analyze/build/device tests were not executed in this environment because the Flutter SDK was unavailable. Existing `analyze_out.txt`, `analyze_after.txt`, `test_results.txt`, and `test_out.txt` are interrupted or warning-heavy historical outputs and are not treated as passing evidence.

## Interpretation

The 34 emulator-backed rule tests plus 2 pure unit tests provide strong evidence for the paths and transitions explicitly covered. They do not prove the absence of vulnerabilities in untested paths, Admin SDK logic, concurrency, App Check, or live device integration. The retained aggregate execution transcript is in `PRODUCTION_EVIDENCE_20260831.md`.
