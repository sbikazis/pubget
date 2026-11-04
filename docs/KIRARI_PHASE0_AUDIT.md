# Kirari Phase 0 — Main Source Audit (Initial Findings)

**Baseline:** `main` commit `6a35447ac8344f1da0cec1eef58f172c1728499d`  
**Working branch:** `feature/15-kirari-production-rebuild`  
**Status:** Initial source evidence captured. This is not the final 15.1–15.20 matrix and does not assert production readiness.  
**Limits:** GitHub source inspection only. Firebase Emulator, Flutter analyzer/build, device/network profiling, and deployed-config verification have not run in this environment.

## Findings

| ID | Priority | Evidence | Root cause / impact | Remediation |
|---|---|---|---|---|
| KIR-001 | High | `lib/features/kirari/data/kirari_repository.dart`: `getFeed`, hashtag, audio, and creator-feed methods resolve video/cover Storage URLs inside sequential loops with awaited `getDownloadURL()`. | Serial round trips make feed hydration latency scale with each reel and amplify poor-network delay. | Resolve URLs concurrently with bounded concurrency; isolate per-item failures; consider stable server-issued media access contract. Add latency and partial-failure tests. |
| KIR-002 | High | Same repository, `uploadSource`: `putFile()`; `snapshotEvents.listen()` is not retained/canceled; repository API exposes progress only, not task lifecycle. | Upload task/listener ownership is incomplete; pause/resume/cancel and listener disposal are not represented at this layer. | Introduce owned upload-job object with task/subscription lifecycle, progress, cancellation, persistence/recovery, retry and idempotent finalize. Test route exit/background/relaunch. |
| KIR-003 | High | `storage.rules`: `/kirari/{userId}/{reelId}/source.mp4` permits 500 MiB; processed `/reels/{userId}/{fileName}` permits 100 MiB. Upload screen checks source against 500 MiB. | Source and processed rendition limits differ without a documented output cap; pipeline outputs may be rejected or contract drift may break media. | Define source/rendition caps separately, align pipeline, rules, copy and tests. Do not broaden rules without validating path, owner, MIME and output size. |
| KIR-004 | High | `lib/features/kirari/screens/kirari_upload_page.dart`: literal status copy such as “Preparing secure upload…” and “Uploading video…”; `KirariCopy` contains localized copy but not all statuses used by screen. | Upload UI bypasses central localization, creating English leakage in Arabic and inconsistent wording. | Route every status, error, editor label and accessibility label through central `AppStrings/KirariCopy`; add Arabic/RTL widget tests. |
| KIR-005 | High | `firestore.rules` denies client writes to `/kirari/{reelId}` and nested comments/actions/playback sessions; `functions/src/kirariDomain.js` performs transactional updates and server increments. | Server-authority direction is present, but source inspection does not establish full callable coverage, legal state transitions, or concurrency/idempotency correctness. | Preserve server-only mutations; add Emulator Rules + multi-user callable tests for like/unlike, comments, qualified views, completion, replay, reports and moderation. |
| KIR-006 | High | `functions/src/kirariPipeline.js` writes reel `status: published` while moderation can remain `review_pending`; public Firestore visibility requires published AND approved. | Processing status and moderation status are represented independently with ambiguous user-facing lifecycle; can create processed-but-not-public content that looks published to some code paths. | Define one authoritative transition table; keep review-pending explicitly non-public; audit all feed/detail/media queries and test restricted/takedown behavior. |
| KIR-007 | Medium | Repository selects rendition in several paths using fixed 540 → 360 → 720 preference. | Fixed preference is not bandwidth/device adaptive and may select an unsuitable rendition. | Centralize network-aware policy with bounded switching/hysteresis; test low bandwidth, missing renditions, and playback continuity. |
| KIR-008 | Medium | `kirari_feed_page.dart` owns active/prefetch controllers, reporter and timer; upload/details own video controllers and async UI state. Dispose calls exist. | Presence of dispose calls alone does not prove listener/timer/controller exclusivity, background handling, or race-free async callbacks. | Audit every lifecycle branch; add controller ownership/pool and app lifecycle tests; verify only one active player and all timers/listeners stop. |
| KIR-009 | Medium | Repository throws raw `StateError` for missing playback/upload-session fields and passes callable/Storage errors through. | Domain failures are not consistently classified at repository boundary; raw technical errors can leak or produce inconsistent retry UX. | Translate backend codes into typed failures; localize user copy; retain structured diagnostics without showing raw Firebase details. |
| KIR-010 | Medium | Firestore and Storage rules independently gate reel, audio and processed media visibility. | Cross-resource consistency (deleted/restricted reel, audio reuse, profile/feed/search/hashtag visibility, stale media access) is not established by the rule clauses alone. | Add visibility/takedown matrix across all surfaces and secure media access tests. |

## Confirmed architecture map

- Flutter screens: `lib/features/kirari/screens/kirari_feed_page.dart`, `kirari_upload_page.dart`, `kirari_reel_details_page.dart`, `kirari_moderation_page.dart`.
- Repository/model/client: `lib/features/kirari/data/kirari_repository.dart`.
- Copy: `lib/features/kirari/l10n/kirari_copy.dart` uses central `AppStrings`, but some upload statuses bypass it.
- Backend domain: `functions/src/kirariDomain.js`.
- Media pipeline: `functions/src/kirariPipeline.js`.
- Visibility/access helpers: `functions/src/reelVisibility.js`, `functions/src/reelMediaAccess.js`.
- Security: `firestore.rules`, `storage.rules`.
- Existing tests: `functions/test/kirariDomain.test.js`, `kirariNotifications.test.js`, `kirariPipeline.test.js`. Their existence is not proof they pass or cover Emulator integration.

## Phase 0 work still open

1. Complete per-requirement matrix for 15.1–15.20 with exact evidence.
2. Inspect every exported callable and Flutter call site, including integration axes 02/05/06/09/10/16/18/19/21/23/24/25.
3. Verify schema, all query/index pairs, state machine legality, idempotency and quota race behavior.
4. Inspect comments/replies, audio, notifications, recommendation/trending, analytics, moderation/takedown and respect/reward ledger end-to-end.
5. Run Firebase Emulator Rules + Functions tests, Flutter analyze/widget/integration tests, release build, and low-bandwidth/device profiling.
6. Verify deployed Functions/Rules and Cloudflare media behavior match source; repository inspection cannot establish deployment state.
7. Record packages, CI evidence, and any blocked paid-service requirements.

**Gate: Phase 0 remains OPEN. No production-ready claim. No code implementation is approved until the complete evidence matrix is consolidated.**

## Additional integration findings (pass 2)

| ID | Priority | Evidence | Root cause / impact | Remediation |
|---|---|---|---|---|
| KIR-011 | High | `docs/KIRARI_OPERATIONS.md` says canonical `/reel/:id` resolves Edits when ID belongs to Edits and Kirari otherwise. But `lib/features/reels/screens/reel_details_page.dart` implements canonical `/reel/:reelId` using only `EditsRepository.getEdit()`; the independent Kirari details screen is `lib/features/kirari/screens/kirari_reel_details_page.dart`. | The canonical route's data source is Edits-only, so a Kirari reel deep link may be treated as missing or render the wrong detail model instead of dispatching by domain. | Add explicit domain resolution (prefer server/route contract, not fragile client probing); route to the matching detail/viewer context; preserve login return and unavailable states; integration-test both Edits and Kirari IDs. |
| KIR-012 | High | `lib/features/reels/reels_brand.dart` defines literal `name='Reels'` and `arabicName='ريلز'`; Kirari copy separately uses `Kirari` / `كيراري`. Requirement specifies one central `AppStrings.productReelsName`. | Multiple product-name authorities can drift across navigation, branding, localization and screens; inconsistent label appears to user. | Replace local brand literals with central product-name constant and localization; audit every navigation/entry surface and test Arabic/English. |
| KIR-013 | High | `docs/KIRARI_OPERATIONS.md` explicitly says recovery after process death restarts upload from persisted local file to same object path; it is not byte-offset continuation or background upload after app closes. | Current recovery is whole-file retry, not true resumable transfer; large uploads on weak networks can restart from zero and consume data/time. | Implement SDK-supported resumable session recovery or clearly scoped upload-job backend; persist session/progress safely, verify generation/idempotency and cleanup. If platform cannot guarantee background continuation, disclose that UX limitation and avoid claiming full resumability. |
| KIR-014 | High | `docs/KIRARI_OPERATIONS.md` states automated moderation is text-based only and there is no visual/audio classification or creator appeal workflow. | Anime edits are primarily video/audio; text-only moderation leaves media abuse/copyright/unsafe-content gaps and no appeal path. | Document launch policy and risk acceptance; implement provider-agnostic media review hook, human escalation/appeal and takedown audit. If automated media review requires unavailable paid service, mark BLOCKED and keep appropriate manual controls. |

These additions are source/documentation verified; they are not runtime failures reproduced on device.