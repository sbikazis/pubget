# PLANRB — Pubget Production Recovery Plan

**Status:** DRAFT — Phase 0 (ground truth) must run before any fix is trusted
**Created:** 2026-10-08
**Spec of record:** `docs/PUBGET_MASTER_SPEC.md` (LOCKED — wins every conflict)
**Source reports:** `PUBGET_GAP_ANALYSIS_AND_ROADMAP.md` (2026-09-17 @ `195670c`), `GAP_AUDIT.md`, `SECURITY_AUDIT_REPORT.md` (2026-08-31), `PUBGET_PROJECT_STATE.md`, `CURRENT_STATE_MASTER.md`

---

## 0. Honesty note — why this plan starts with verification

The repo's own reports were written at **different revisions and contradict each other**:

| Claim in reports | Status in CURRENT tree (verified 2026-10-08) |
|---|---|
| `flutter analyze` = 34 errors (duplicate Mafia stacks, missing `GameStrings` getters, uninitialized `final mafia`) | **Unverified** — must re-run; `analyze_out.txt`/`analyze_after.txt` in repo root are STALE artifacts of the pre-rebuild legacy codebase (Windows paths, `lib/app.dart`, `test/widget_test.dart` — none exist in the current tree). Do not trust them. |
| `functions/index.js` redefines `const mafiaDomain` → SyntaxError | **FIXED** — single definition at `functions/index.js:185` |
| `gamesDomain.js:678-717` unclosed `transaction.create` → all game callables dead | **FIXED** — all `transaction.create` calls properly closed (`gamesDomain.js:358, 764, 772, 807, 809, 1290`) |
| `_mockCharacters` (4 hardcoded RP characters) | **FIXED** — zero matches in `lib/` |
| `reelsDomain.js` dead, never imported | **CONFIRMED STILL DEAD** — no `reelsDomain` reference anywhere in `functions/index.js` |
| 8 pre-existing Flutter test failures (K1) | **OPEN** — rows 7–8 fixed by control-panel redesign; ~6 remain (shell drawer, golden 3.85% pixel diff, edits copy drift ×2, bans ×2) |
| `firebase deploy --only functions` | **PENDING** — PROMPT 1/2/3 all marked "NOT deployed" |
| `flutter build apk` | **INTERRUPTED** during phase-B close |

**Rule:** no task in this plan may be marked done on a report's claim alone. Every phase re-verifies against the live tree.

---

## Phase 0 — Ground truth (بوابة التحقق) — gate for everything

1. Run `flutter analyze` → record real error/warning/info counts to `docs/ANALYZE_CURRENT.md` (replaces stale `analyze_out.txt`)
2. Run `flutter test` → full pass/fail list; diff against the 8 known K1 failures
3. Run `npm run check` (`node --check` on every `functions/` file) + `npm test` → compare against the claimed 217/217
4. Run `npm run test:rules` against the Firestore emulator (`FIRESTORE_EMULATOR_HOST=127.0.0.1:8080`)
5. Re-audit every claim in `PUBGET_GAP_ANALYSIS_AND_ROADMAP.md` against the live tree; tag each ✅ still-broken / ✅ fixed / ⚠️ changed

**Acceptance:** one doc with real numbers. Phases 1–15 only execute on confirmed defects.

---

## Phase 1 — Unblock build & deploy (فك الانسداد)

1. **Client compile:** if Phase 0 shows analyzer errors (duplicate Mafia stack `features/games/mafia` vs `features/mafia`, missing `GameStrings` getters — `nightResult`, `voteResult`, `yourRole`, `alive`, `eliminated`, `noKill`, `saved`, `spectating`, `waitingNight`, `kill`, `investigate`, `protect`, `vote`, `selectTarget`, `mafiaWins`, `townWins` — uninitialized `final mafia` in `game_models.dart`, `test/mafia_screens_test.dart` against old interfaces) → unify to ONE Mafia stack, add getters, initialize the field, update tests
2. **Backend deploy:** `firebase deploy --only functions` (pending since PROMPT 1/2/3)
3. **APK:** `flutter build apk --debug` + on-device smoke test
4. **CI gate:** add a workflow step running `flutter analyze` + `flutter test` + `npm run check` + `npm test` + `npm run test:rules` before any deploy (today only `build.yml` builds the APK, with an unpinned Flutter version)

**Acceptance:** analyze = 0 errors · tests green · functions deployed · APK built.

---

## Phase 2 — Navigation integrity & mock removal (سلامة التنقل)

1. Register the `/reels/upload` route (the create sheet currently routes to an unregistered path → `UnknownLinkPage`), or repoint it to the edits upload page
2. Delete dead routes `/games/waiting`, `/games/room`; remove the orphan `games_center_v2` stack and its "Mafia arrives in Prompt 2" placeholder
3. Verify zero mock data in `lib/` (grep sweep for hardcoded character/person lists)
4. Post-join membership must write a real membership record — no `uid: ''` stubs
5. Top app bar order per spec 4.1: `[logo] [coins] [dragon store] [search] [notifications+badge] [avatar] [menu]`

**Acceptance:** no dead routes · no mocks · spec bar order.

---

## Phase 3 — Anime Hub repair (إصلاح Anime Hub) — user-reported broken

**Reproduce first** (device + emulator, with Jikan reachable AND blocked):

1. Open `/anime` hub, search, details, characters, library, ratings — record the exact failure signature (crash / blank / wrong data / stale)
2. Verify `ResilientAnimeHttpClient`: 429 handling (`Retry-After` capped 5s), timeout/5xx retry (max 2), ~350ms request serialization
3. Verify `FirestoreCachedAnimeRepository` write-through fallback (Jikan outage → stale cache with `fromCache` flag, never a blank screen)
4. Fix mapping/pagination bugs found; add spec §2.1 states (Skeleton / Empty / Error+Retry / Offline) on every anime screen
5. l10n: replace hardcoded `'Report'` (`anime_details_page`) and any EN literals with `AppStrings`
6. Moderation: review `needs/flagged` resolution depends on Phase 10
7. Depth per spec 16.2: ratings + character interests as first-class discovery fuel

**Acceptance:** hub works on device with Jikan up **and** down · error states visible · zero hardcoded EN in anime screens.

---

## Phase 4 — Kirari / Reels (الريلز) — largest build, spec axis 15

1. Wire `functions/src/reelsDomain.js` into `functions/index.js` (currently dead code)
2. Flow: `+ ← Reels` entry, validation (≤60s, vertical, ≤500MB), light editor (trim / speed / cover / simple text)
3. Metadata: hashtags, anime/character tags from the catalog (no free text), mentions, audio attribution
4. Audio system: audio page, original/reuse, attribution, `MediaService` abstraction
5. Unified player: preload / cache / adaptive quality; view counting (≥3s, anti-bot)
6. Three feeds: **For You** (behavioral recs exploit 70–90 / explore 10–30), **Following**, **Trending** (velocity)
7. Upload management: 10/day cap, retry, idempotency, non-blocking UI
8. Creator analytics (real numbers only — no fake views) + `needs_review` moderation state
9. Firestore schema: independent subcollections + composite indexes (`firestore.indexes.json`)

**Acceptance:** reelsDomain unit tests + rules tests + emulator E2E.

---

## Phase 5 — Games & Mafia (الألعاب والمافيا)

1. Game Center reachable from group chat only; 2/day limit; 15-min waiting rooms; idempotent rewards (`earn_game_win_{difficulty}` / `earn_game_draw` / `earn_game_loss`); clean result archive
2. Mafia: full Arabic l10n; **verify player limits vs spec 13.2** (spec says 7–15; the gap analysis claims the code has 4–8 — verify and align); role-privacy audit; server-owned return/idle windows
3. Verify two precision bugs from the gap analysis and fix if still present:
   - `guessCharacter.js:274` — loser in the answer phase wrongly awarded the turn
   - `eventsDomain.js:1827` — prediction `winnerIds` must be **user IDs**, not option IDs (PROMPT 3's `resolveEvent` may already cover this)

**Acceptance:** 217+ backend tests green · Mafia E2E · reward-ledger tests.

---

## Phase 6 — Events (الأحداث)

1. Prediction `winnerIds` fix (Phase 5.3)
2. l10n for the create screen (hardcoded EN)
3. Result-lock UI — `resolveEvent` is server-side per PROMPT 3; wire the client to it
4. Quiz per-question timer: add server `timePerQuestionMs` + UI, or explicitly descope

**Acceptance:** `eventsDomain.test.js` (35 tests) green · client wired to `preview/resolve/getAnalytics`.

---

## Phase 7 — Chat pillar completion (إكمال الدردشة)

1. Verify Phase-B claims hold: retry / media / reconnect, voice hold-to-talk, stickers, camera, react / reply / pin, read receipts
2. Replace any remaining snackbar placeholders (sticker / audio / GIF / reply / forward / report) with real implementations — spec forbids fake features
3. `chat_game_activity.actionLabel` hardcoded EN → `AppStrings`
4. Group unread from `lastReadAt` (gap: not implemented in `lib/features/groups`)
5. Group media page: currently shows only the loaded chat-window slice — build a real paginated media library

**Acceptance:** chat widget tests green · no placeholder snackbars · paginated media library.

---

## Phase 8 — Groups completeness (المجموعات)

1. `updateGroupSettings` / `unbanMember` exist server-side with **zero Flutter UI** — build founder settings + unban UI (bans-page fixtures already failing, K1 rows 5–6)
2. Roleplay join: real character catalog (server-side `animeCatalogDomain`) with suggestions + search
3. Role change: verify the "always sends `senpai`" bug is gone (GAP_ANALYSIS says fixed; GAP_AUDIT called it CRITICAL — verify)
4. Kick/ban client-side permission checks

**Acceptance:** group screens tests green · roleplay uses the real catalog.

---

## Phase 9 — Economy / Store / Premium / Ads (الاقتصاد)

1. Billing seam: provider-agnostic Billing Layer interface (no Play Billing yet — spec lock)
2. **Premium activation codes (spec 19.4):** admin-issued codes, server-side redeem callable, ledger entry, `subscriptionType=premium` + `premiumExpiresAt`
3. **Ads** (spec: income source, **NOT** removable by coins): real AdMob integration — blocked until console-side AdMob + App Check activation (see Blocked); placements with frequency/cooldown, load/no-fill/failure states, rewarded ads, crash-free degradation. Remove the static `Sponsored` placeholder card once real placements exist
4. Store: rarity tiers Common..Mythic; technical-extensions section; physical products stay deferred (rules allow read; no UI)
5. Replace `restorePremiumPurchases` no-op (`{deferred:true, payment_provider_not_configured}`) with real restore once the billing seam exists

**Acceptance:** economyDomain tests · ledger idempotency · entitlement tests.

---

## Phase 10 — Moderation & admin (الإشراف) — spec axis 23

1. Server-side moderation callables: resolve `needs_review` (edits / anime reviews / fan works), report queue, restrict / remove / restore
2. Moderator gating: reuse the `groupModerator` / `rankV2` pattern; platform moderators via custom claims (**never** a writable Firestore role)
3. Emulator rule tests for every new callable; never weaken `firestore.rules` / `storage.rules`

**Acceptance:** rules tests green · moderation E2E on emulator.

---

## Phase 11 — Localization & RTL (التعريب)

1. l10n sweep: every hardcoded EN screen → `AppStrings` (onboarding, search, private list, notifications inbox, edit profile, friend requests, guide, events create, games, fan works, anime 'Report', mafia AR-only sections, `chat_game_activity`, `give_respect`, members council, `games_v2`)
2. Decide: extend `AppStrings` or introduce real `.arb` / `gen_l10n` — spec demands 100% bilingual (one stray word in the wrong locale is a critical defect)
3. RTL QA: arrows, directional icons, alignment, scroll, numbers/dates, bottom sheets, drag-to-send

**Acceptance:** `app_language_test` pattern extended · zero EN literals under the `ar` locale.

---

## Phase 12 — Deep links, search, sharing (الروابط والبحث)

1. Align deep links to spec 2.3: `/profile/{username}` (today `/profile?uid=`), `/reel/{id}`, `/work/{id}`, `/hashtag/{tag}`, `/audio/{id}`, `/group/{id}`
2. Add a `/g/**` hosting-rewrite parser in the Flutter web entry (currently none)
3. Search: entity-type filter; reels / character / hashtag / audio search; fuzzy matching; recent history
4. Share builders for edits + store (missing); rich previews where possible

**Acceptance:** deep-link tests · search tests.

---

## Phase 13 — Quality, states, analytics, performance (الجودة)

1. Unified screen states everywhere (Skeleton / Loaded / Empty / Error / Offline / Permission / Expired / Retry) — spec 1.3/2.1; kill no-op retries (`onRetry: () {}`) and fake success (onboarding skip while offline)
2. K1 test sweep: fix or refresh the remaining pre-existing failures (shell drawer, golden 3.85% pixel diff, edits copy drift ×2, bans ×2)
3. Regenerate the stale golden under a CI baseline
4. Analytics: real measurement (opens / completion / engagement / retention) replacing the `LoggingAnalytics` stub — privacy-preserving
5. Performance budget: measure; no full rebuilds; video preload+dispose; remove duplicate listeners; 300ms interaction target
6. Widget tests: Mafia play, edit playback, inbox retry/hasMore, roleplay reservation; multi-user Mafia integration

**Acceptance:** full `flutter test` green · analyze 0 errors.

---

## Phase 14 — Security hardening (الأمان)

1. Re-verify the SECURITY_AUDIT fixes hold (Mafia history participants-only reads; transactional `historyWriter`)
2. Verify trust boundaries: `lastMessageAt` / `lastMessageText` server-only in rules; Mafia night/vote/chat callables-only; nested `groups/.../games` not moderator-writable; `user_seen` not client-writable; `avatarUrl` via callable (not direct write); `PubgetUser.toMap` vs rules allowlist alignment
3. App Check enforcement (console-side — see Blocked)

**Acceptance:** rules emulator tests including negative cases.

---

## Phase 15 — Release (الإطلاق)

1. Pin the Flutter version in CI (`subosito/flutter-action` currently unpinned `stable`)
2. `flutter build apk --release` with signing (`key.properties` from secrets)
3. Final visual QA vs spec 0.3/1.3: FAB luxury, palette discipline, deliberate dark/light, full RTL
4. Update `CURRENT_STATE_MASTER.md` + this plan's completion evidence

**Acceptance:** signed APK · docs updated.

---

## Blocked (console-side, outside the repo)

- AdMob activation, App Check enforcement, FCM web credentials — Firebase/Play console actions
- Real payment provider — spec locks monetization to admin activation codes now; billing later
- Physical products — intentionally deferred by spec

## Execution rules (from the locked spec)

- One branch per phase + full PR gate: analyze=0 · tests green · build ok · rules tests if rules touched
- Server is truth · idempotency · explicit state machines · no fake data · no dead buttons
- `lib_legacy/` is reference-only — never import it
- Any conflict: `docs/PUBGET_MASTER_SPEC.md` wins
