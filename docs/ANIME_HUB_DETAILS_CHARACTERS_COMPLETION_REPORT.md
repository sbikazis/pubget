# Anime Hub Details & Characters Universe — Completion Report

Branch: `codex/anime-hub-rebuild`
Parent commit: `73d2d3c` (Phase 2 discovery)
Prompt: **PROMPT 03 — PUBGET ANIME DETAILS & CHARACTERS UNIVERSE** (Phase 3)
Verdict: **PASS WITH DOCUMENTED LIMITATIONS**

---

## 1. Executive summary

Phase 3 completed the Anime Details & Characters Universe on top of the Phase 1
data foundation and the Phase 2 discovery system. New work: staff/voice credits
end to end (model → mappers → codec → all five repository tiers → provider →
details UI), a sensitive-content notice for adult-rated titles, navigable
appearance rows, a view-all cast page with client-side search, and a real
report-anime workflow wired through the shared report catalog on both client and
backend. A genuine layout defect was found and fixed: the characters/cast tab was
not scrollable and overflowed its viewport by 15 px. Static analysis is clean and
all executed Flutter tests pass; the functions suite passes 26/26. The full
Flutter corpus is still capped by the environment and is reported as unrun.

## 2. Task and objective

Deliver the details and characters surfaces using real data only: staff and voice
credits, per-criteria community ratings gated on social, character profiles and
favorites, the Popular Characters global ranking, the Pubget community sections,
the statistics tab, trailer playback through the existing Reels player, a
view-all cast page, and a report-anime flow. Hard prohibitions: no episode lists,
no players, no watch buttons, no streaming sections, no fabricated data, no new
dependencies, no PR/merge. Localize every user-visible string.

## 3. Environment

- Flutter 3.32.8 / Dart 3.8.1; Node v20.19.0; macOS.
- Long single commands capped near 600 s; the full Flutter corpus (144 files)
  does not complete within it.
- `dart format` (3.8.1 tall-style) MUST NOT be run on touched files (see §10).

## 4. What already existed (verified, not re-built)

The details page already had three tabs (details / characters & cast /
statistics), a hero header, criteria ratings gated on the social provider, the
five-state My List sheet, the community reviews/discussion sections, the
statistics charts, trailer playback via the shared Reels player, the
popular/favorite character pages, and a restricted-write `anime_stats` /
`character_stats` ruleset. Phase 3 verified these and added the surfaces below.

## 5. Changes — staff and voice credits

- `lib/features/anime/models/anime_models.dart`: `AnimeStaff`
  (id/name/imageUrl/roles + `rolesLabel`).
- `lib/features/anime/data/jikan_mapper.dart`: `mapJikanStaff` (`anime/{id}/staff`).
- `lib/features/anime/data/anilist_mapper.dart`: `mapAniListStaffEntry` /
  `mapAniListStaff` / `_staffName` (`Media.staff.edges`).
- `lib/features/anime/data/anime_cache_codec.dart`: `staffToMap` / `staffFromMap`.
- `AnimeRepository.getStaff` + `AnimeCacheTtl.staff` (12 h), implemented in all
  five tiers: Jikan, AniList, cached (`staff:{animeId}`), firestore-cached, and
  provider-chain.
- `lib/features/anime/providers/anime_providers.dart`: `AnimeDetailsProvider`
  staff state (`_staff/_staffState/_staffFailure`, `staff`/`staffState`/
  `staffFailure` getters, `retryStaff()`, `unawaited(_loadStaff)` in `load()`).
- `lib/features/anime/screens/anime_details_page.dart`: info-only staff strip in
  `_CharactersSection` (cards `Key('staff-${id}')`).
- Localization: `staffTitle`, `charactersSearchEmpty`, `searchInCharacters`.

## 6. Changes — details polish

- **Sensitive-content notice:** `_InfoTab` renders `AnimeSensitiveContentNotice`
  after `_FactsCard` when `anime.ageRating == AnimeAgeFilter.adult`.
  `Anime.ageRating` maps Jikan `R-`/`R+`/`Rx` (and `R -`) to
  `AnimeAgeFilter.adult`.
- **Appearance navigation:** `_appearanceBlock` rows are wrapped in an `InkWell`
  that opens `AnimeLinks.openDetails`.
- **Scrollable tabs (bug fix):** `_CharactersTab` is now wrapped in a
  `SingleChildScrollView`; previously the section overflowed its viewport by
  15 px (detected by the widget test suite).

## 7. Changes — view-all cast page

- `lib/features/anime/providers/anime_cast_provider.dart` (new): loads the cast
  via `getCharacters`, exposes `search`/`visible`, and maps failures through
  `animeFailureState` for offline/error consistency.
- `lib/features/anime/screens/anime_cast_page.dart` (new): search field
  `Key('anime-cast-search')`, cards `Key('cast-${id}')`.
- `lib/features/anime/widgets/anime_widgets.dart`: `AnimeLinks.castPath` /
  `openCast` → `/anime/cast?animeId=`.
- `lib/app/pubget_app.dart`: `/anime/cast` route + page import.
- "See all" `PubgetTextButton` `Key('anime-see-all-cast')` in the details
  characters header.

## 8. Changes — report-anime workflow

Client:

- `AnimeHubSocialRepository.reportAnime({animeId, reason, details})` in the
  interface, the Firebase implementation (callable `reportAnime` with
  `animeId`/`category`/`detail`), the unavailable implementation, and
  `AnimeHubSocialProvider.reportAnime` (returns `ValidationError` when no anime
  is bound).
- `lib/features/anime/widgets/anime_hub_widgets.dart`: shared `animeReportReasons`
  + `promptAnimeReport(...)` (reason dialog `anime-report-$value`, confirm
  `anime-report-confirm`, accept `anime-report-confirm-accept`), wired through
  `_ReviewsSection._submitReviewReport` and `_MoreMenu._report`.
- Localization: `reportAnime`, `confirmReport`, `reportConfirmContent(reason)`,
  `reportReasonLabel(key)`, `reportSubmitted`, `reportFailed`, `pubgetUser`,
  `copyLink`. Fixed the popup Copy label and the character-URL semantic label to
  use `copy.copyLink`.

Backend (`functions`, shared `REPORT_REASONS` catalog):

- `reportAnime` + `animeReportRef` + `enforceAnimeReportRateLimit` in
  `functions/src/animeHubDomain.js`; registered in the module return object and
  `functions/index.js`.
- Idempotent per reporter at `anime_reports/{animeId}/reports/{reporterId}` with
  `repeatCount`; rate limit on `animeReportRate` (60-minute window, max 10),
  bypassed for a repeat report of the same title.
- `firestore.rules`: `anime_reports/{animeId}/reports/{reporterId}` and
  `animeReportRate/{actor}` are read-only for the owner/admin, write false.

## 9. Changes — tests

- `test/anime_mapper_test.dart`: `mapJikanStaff` / `mapAniListStaff`.
- `test/anime_cache_codec_test.dart`: staff round trip.
- `test/anime_providers_test.dart`: characters + staff side by side; staff
  failure does not sink the characters strip (expects offline).
- `test/anime_cast_provider_test.dart` (new): load/filter/empty/failure.
- `test/anime_hub_social_test.dart`: `reportAnime` (+ fake override).
- `test/anime_screens_test.dart`: adult/general sensitive-notice gating, staff
  strip + see-all cast, cast page search.
- `test/anime_test_support.dart`: `FakeAnimeRepository` staff/staffFailure/
  `getStaff`; `sampleAnime(rating:)`.
- `test/provider_chain_anime_repository_test.dart`: `_FlakyRepository.getStaff`.
- `functions/test/animeHubDomain.test.js`: +2 tests (idempotent/rate-limited
  reports; unknown reason + abuse gate).

## 10. Formatter churn

Dart 3.8.1's `dart format` emits tall-style output that rewrites large swathes of
this repo's old-style code. It was not run on any touched file; edits were kept
in the repo's existing style.

## 11. Verification — static analysis

`dart analyze lib <touched anime/phase-3 tests>` → **No issues found!** (exit 0).

## 12. Verification — executed tests

| Batch | Result |
| --- | --- |
| `functions`: `node --test test/animeHubDomain.test.js` | **26 pass** |
| `anime_screens_test.dart` | **35 pass** |
| `anime_providers_test.dart` | pass |
| `anime_cast_provider_test.dart` | 3 pass |
| `anime_hub_social_test.dart` + `anime_mapper_test.dart` + `anime_cache_codec_test.dart` | 31 pass |
| `provider_chain_anime_repository_test.dart` | 4 pass |

## 13. What was NOT run

- The complete Flutter corpus (144 files) does not complete within the ~600 s
  cap; only the targeted batches above were executed.
- No device/emulator integration run; no live Jikan/AniList network call.

## 14. Acceptance gates

| Gate | Result |
| --- | --- |
| Real staff/voice credits end to end | **PASS** |
| Sensitive-content notice for adult titles | **PASS** |
| Appearance rows navigate to the title | **PASS** |
| View-all cast page with search | **PASS** |
| Report-anime on client + backend, rate-limited | **PASS** |
| No episode list / player / watch / streaming surface | **PASS** (none added) |
| Localized copy for all new strings | **PASS** |
| Static analysis clean | **PASS** |
| Executed tests green | **PASS** |
| Full corpus green | **NOT VERIFIED** (environment cap) |
| Anime favorites single source of truth | **BLOCKED** (documented — §15) |

## 15. Known limitations and risks

1. **Full corpus unverified** under the harness cap (§13); CI can close this.
2. **Anime favorites dual source of truth** (profile `favoriteAnimeIds` vs.
   library `isFavorite`) is intentionally left unchanged and remains a
   documented limitation. Character favorites use a single `character_favorites`
   repository (idempotent `setCharacterFavorite`).
3. **Staff-only page** not added: staff render as info-only cards, per the
   contract non-goal.

## 16. Contract updated

`docs/ANIME_HUB_REBUILD_CONTRACT.md` gained §31 (details and characters contract:
real data, no broadcasting surface, independent section loading, character
favorites, report catalog/idempotency/rate limit, localization, scrollable tabs)
and §32 (Prompt 03 non-goals). Now 32 sections.

## 17. Non-goals honored

No new dependencies. No fabricated data. No streaming/broadcasting feature. No
separate staff page. No PR or merge. Pre-existing migration modifications in
unrelated files were left untouched.

## 18. Next steps

1. Run the full Flutter corpus in CI (removes the `NOT VERIFIED` gate).
2. Phase 4: final integration and PR.
