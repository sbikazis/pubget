# Kirari — Phase 0 Forensic Audit

**Audit baseline:** `main` at `b86182f8fd80788b5268345fc6dfa44815c949f7` (2026-10-31)  
**Implementation branch:** `feat/kirari-system-rebuild`  
**Status:** Phase 0 evidence captured; implementation must not be called complete until the acceptance gates below pass.

## 1. Scope and non-negotiable constraints

Kirari is a distinct short-video/Reels product domain, not a rename of the existing Edits feature. The implementation target is an independent, versioned data model and backend domain with integration contracts to Pubget axes 02, 05, 06, 09, 10, 16, 18, 19, 21, 23, 24, and 25.

Requirements carried into this audit:
- Server is the source of truth. Clients never write aggregate counters, publication status, moderation decisions, rankings, or reward outcomes.
- Gallery-only source selection; vertical videos 3–60 seconds, up to 500 MB; resumable/retryable upload, one active upload per user, server-enforced daily limit of 10.
- Lifecycle: Uploading → Processing → Preparing → Published, with explicit Failed/Rejected/Deleted terminal states, idempotent transitions and retry recovery.
- Server pipeline: validation, processing, 360p/540p/720p renditions, cover generation, moderation gate, metadata publication.
- Editor: trim, speed, audio selection, timed text, light filters, cover selection, non-destructive preview.
- Audio library: only published/eligible user audio can be reused; preserve original creator and attribution; audio detail/feed surfaces.
- One unified ReelViewer with one active player, bounded preloading/cache, adaptive quality, deterministic disposal, and paginated feed.
- Separate For You / Following / Trending feeds; behavioral/content/social/negative signals; 70–90% exploitation and 10–30% exploration; creator/topic diversity; seen ring; cold start; velocity-based Trending; hashtag pages.
- Metrics: Impression, View, Qualified View (at least 3 seconds), Completion, Replay at 95%; batched client events are untrusted input and must be filtered/deduplicated server-side. All counters and daily aggregates are server-owned.
- Comments and interactions are server-mediated and idempotent: likes, saves, shares, reports, block, mute, not-interested; flat parentId replies, pagination/sorting, comment likes, mentions, pinning, creator marker, sticker comments, rate limits, optimistic rollback/retry.
- Moderation, takedown, privacy, block/mute filtering, audit records, ownership checks, rate limits and idempotency are required.
- Preserve working Pubget systems; do not modify `lib_legacy/`; do not introduce fake/placeholder/dead UI; do not add packages without a compelling reason.

## 2. Repository map (confirmed at audit baseline)

### Product/specification and current-state evidence
- `docs/PUBGET_1_0_SPEC.md`: locked product specification. Existing Edits is specified in §§42–49; it does not define Kirari as a separate domain.
- `docs/PUBGET_1_0_REBUILD_MATRIX.md`: live compliance matrix.
- `docs/CURRENT_STATE_MASTER.md`: current architecture/state inventory.
- `attached_assets/Pasted--PROMPT-10-Pubget-Edits-Platform-Edits-Gal-178824475499_1788244754999.txt`: earlier Edits-specific prompt; explicitly deferred Hashtags/Sounds/Audio pages/Duet/Remix. Kirari is therefore additive and must not silently mutate Edits semantics.
- `docs/EDITS_PLATFORM_DIAGNOSTIC.md`: historical Edits pipeline diagnosis and fixes.

### Existing video backend
- `functions/src/editsConfig.js`
- `functions/src/editsDomain.js`
- `functions/src/editPipeline.js`
- `functions/src/ranking.js`
- `functions/src/recommendationEngine.js`
- `functions/index.js`
- `functions/test/editsDomain.test.js`
- `functions/test/editPipelineAspect.test.js`
- `firestore.rules`
- `storage.rules`

### Existing Flutter video surfaces
- `lib/features/edits/models/edit_models.dart`
- `lib/features/edits/repositories/edits_repository.dart`
- `lib/features/edits/repositories/firebase_edits_repository.dart`
- `lib/features/edits/providers/edits_provider.dart`
- `lib/features/edits/providers/edit_upload_manager.dart`
- `lib/features/edits/screens/edit_feed_page.dart`
- `lib/features/edits/screens/edit_upload_page.dart`
- `lib/features/edits/widgets/edit_comments_sheet.dart`
- `lib/features/reels/screens/reels_feed_page.dart`
- `lib/features/reels/screens/reels_upload_page.dart`
- `lib/app/pubget_app.dart`, `lib/app/app_router.dart`, `lib/app/app_shell.dart`

### Cross-domain integration points
- Authentication identity and session: axes 02 / 23.
- Respect/Fans/Friends/Block: axis 05 and existing `functions/src/socialGraph.js`.
- Groups and membership: axis 06.
- Home discovery cards: axis 09.
- Existing Edits: axis 10 / Prompt 10 (keep data and behavior intact).
- Notifications: axis 16 / notification builder and callables.
- Social graph: axis 18 / socialGraph and recommendation engine.
- Settings/privacy/localization: axis 19.
- Deep links/share: axis 21 / `lib/core/links/pubget_links.dart`.
- Security: axis 23 / Firestore and Storage rules.
- Offline/reliability: axis 24.
- Testing: axis 25 / Flutter, Functions, rules-emulator suites.

## 3. Evidence-backed gap matrix

| Area | Current evidence | Kirari gap / root cause | Required implementation |
|---|---|---|---|
| Domain isolation | `functions/src/editsDomain.js` owns collection `edits`; `functions/index.js` registers Edits callables. `functions/src/reelsDomain.js` exists but is not registered in the function index at baseline. | No independent Kirari domain, callable contract, schema version, or dedicated client repository/provider. Existing Reels route is not proof of an independent backend. | Add `kirari` domain, dedicated collections/subcollections, callables/triggers, typed client interfaces, explicit versioning and migration-safe isolation. |
| Existing Reels UI | `lib/features/reels/screens/reels_feed_page.dart` delegates to the existing Edit feed in the current implementation. | Reels route is effectively an Edits alias; it cannot satisfy Kirari feed, editor, audio, and interaction requirements. | Replace with Kirari UI without changing existing Edits routes/data. |
| Upload constraints | Existing Edits config permits 180 seconds and 100 MB. | Conflicts with Kirari's 3–60 seconds and 500 MB limits. | Independent Kirari config; enforce all limits server-side before allocating upload sessions. |
| Upload lifecycle | Existing Edits uses Storage upload plus callable finalization and Storage processing. | No evidence of Kirari's resumable/background upload contract, single-active-upload lock, 10/day server quota, or explicit Preparing state. | Durable upload session, resumable object path, lease/lock, quota transaction, retry/backoff, idempotency key, recoverable state machine. |
| Processing | `functions/src/editPipeline.js` processes one MP4 and thumbnail. | It is Edits-specific; no Kirari rendition ladder 360/540/720 or cover/metadata lifecycle. | Independent processor and rendition metadata; avoid claiming adaptive playback until renditions are actually produced and selected. |
| Audio | Prompt 10 explicitly deferred sounds/audio pages. Existing edit model has an audioId field but no proven Kirari audio library contract. | No published-audio ownership/reuse/attribution domain for Kirari. | Audio asset schema, publication/moderation state, ownership and attribution, reuse authorization, audio detail/feed. |
| Editor | Existing Edit upload page is a simple video-first composer. | No complete Kirari editor with trim/speed/timed text/filter/cover/non-destructive preview. | Editor state model and export metadata contract; only expose controls whose processing/export semantics are implemented. |
| Viewer | Existing Edit feed has per-item player management/prefetch; Reels route aliases it. | No single unified Kirari viewer contract guaranteeing one active controller across all feed types. | One viewer/player owner, visibility arbitration, preload budget, cache policy, adaptive rendition selection, lifecycle and route cleanup. |
| Feeds and ranking | Existing Edits feed ranks published `edits` with heuristic score; ranking weights are Edits/discovery-oriented. | No separate For You / Following / Trending feed APIs, exploration ratio, seen ring, hashtag pages, or Kirari behavioral model evidenced. | Server feed endpoints with stable cursors, explicit candidate sources, diversity, negative signals, cold start, velocity trending, and explainable deterministic fallback. |
| Metrics | Edits domain has impressions, playback sessions, view and completion counters; qualified threshold is currently configured as 10% in `editsConfig.js`. | Kirari requires ≥3-second qualification and replay at 95%; reusing Edits counters would corrupt product semantics. | Independent event schema, batched ingestion, server verification/deduplication, server-only aggregate counters and daily stats. |
| Interactions/comments | Edits domain supports likes, comments, comment likes/reports, share/save/negative signals. | Kirari needs independent idempotent actions, block/mute/not-interested filtering, flat parentId comments, pin/creator markers and rate limits. | Transactional Kirari action domain and cursor-paginated comment endpoints. |
| Security | Firestore rules explicitly deny client writes to Edits and its aggregate counters; Storage rules have Edits/Reels namespaces. | No Kirari-specific collection or object-path rules. Existing Edits rules cannot be assumed safe for new documents. | Explicit Kirari read/write rules, owner-scoped staging, immutable originals, processed objects server-only, no catch-all allow. |
| Integrations | Pubget already has social graph, notifications, home discovery, deep links and settings modules. | No verified Kirari integration contracts. | Use public projections and server-owned events; block/mute visibility applied before feed delivery; route notifications/deep links to Kirari IDs. |
| Localization/UX | Arabic/English infrastructure exists; feature bodies remain inconsistently localized per current-state audit. | Kirari screens would inherit mixed-language and RTL defects unless designed explicitly. | Arabic/English strings, RTL/LTR layout, loading/empty/offline/error/retry/processing/moderation states. |
| Verification | Existing test suites cover Edits and general product domains, but no complete Kirari acceptance suite exists. | No test evidence for Kirari state machine, quotas, idempotency, rules, playback, editor, feeds or moderation. | Unit, widget, integration and emulator tests; GitHub Actions verification; report exact results. |

## 4. Root-cause summary

1. Kirari does not exist as a complete independent product domain at the audit baseline. The current Reels entry point reuses Edits UI and must not be mistaken for Kirari.
2. Existing Edits contracts are intentionally different (180s / 100MB / 10%-based qualified view). Reusing them would violate Kirari's limits and analytics semantics.
3. The repository already has useful primitives (Firebase Functions, Admin transactions, Storage processing, social graph, notifications, Flutter repository/provider architecture), but there is no evidence yet that the Kirari-specific upload, audio, feed, editor, metrics, or security contracts are implemented.
4. The audit baseline has a known CI failure on the same main SHA for APK and Hosting workflows (runs 41211962609 and 41211962587); the failure logs must be checked before attributing future PR failures to Kirari.
5. This audit is a static repository inspection through GitHub source APIs. It does not claim local Flutter/Functions/rules execution. Runtime verification must be performed by GitHub Actions or an actual test environment before the PR is represented as passing.

## 5. Implementation sequence and gates

### Gate A — Server foundation
- Independent schema/version constants and state machine.
- Authenticated, validated, idempotent upload-session creation; one-active-upload and daily quota transaction.
- Storage object ownership/path validation and finalize/retry processor.
- 360/540/720 renditions + cover; publish only after all required artifacts and moderation checks succeed.
- Server-only counters and explicit event ingestion.
- Unit tests for state transitions, quota, idempotency, retry, duplicate triggers, ownership, and invalid inputs.

### Gate B — Social domain
- Idempotent likes/saves/shares/reports/block/mute/not-interested.
- Flat parentId comments with pagination/sorting, likes, pinning, creator marker, mentions, stickers and rate limits.
- Social graph visibility filters; notifications and deep-link event contracts.

### Gate C — Discovery
- For You / Following / Trending APIs with cursors.
- 70–90% exploit / 10–30% explore candidate mix, diversity caps, seen ring, cold-start path, velocity trending and hashtag pages.
- Server-derived ranking signals only; no client-supplied score/counters.

### Gate D — Flutter experience
- Kirari repository/provider and dedicated routes/screens.
- Resumable upload manager and gallery-only validation.
- Non-destructive editor state and supported export metadata.
- Unified ReelViewer with one active controller, visibility arbitration, bounded prefetch/cache and cleanup.
- Audio library and reuse attribution.
- Complete loading/empty/offline/error/retry/moderation states in Arabic and English.

### Gate E — Security and acceptance
- Firestore/Storage emulator rules tests.
- Flutter unit/widget/integration tests and Functions tests.
- Build/analyze/test CI checks.
- Verify existing Edits, Groups, Home, Notifications, Social, Deep Links and Settings remain compatible.
- Update live rebuild matrix and current-state docs with evidence, not assumptions.

## 6. Definition of done (not yet met)

Kirari is complete only when:
- Every required screen and action is connected to a real backend contract.
- No placeholder, fake count, dead control, client-owned aggregate, or silently swallowed failure remains in Kirari.
- Upload can recover across app lifecycle/network interruptions and cannot exceed server quotas or duplicate publication.
- Processing produces and records all required renditions/cover and only publishes after moderation/validation.
- Feed tabs, audio, hashtags, comments, moderation and viewer behavior work end-to-end.
- Security rules deny unauthorized client writes and tests prove ownership/privacy boundaries.
- Cross-domain integration tests prove block/mute, Respect/Fans, Home, notifications, deep links and settings behavior.
- Flutter analyze/test/build, Functions tests, and Firestore/Storage emulator tests pass, with exact logs recorded.
- `lib_legacy/` has zero changes.
