# Anime Hub Discovery System — Completion Report

Branch: `codex/anime-hub-rebuild` (based on `257c112`, == `origin/main`)
Parent commit: `219998f` (Phase 1 foundation)
Prompt: **PROMPT 02 — PUBGET ANIME HUB DISCOVERY SYSTEM** (Phase 2)
Verdict: **PASS WITH DOCUMENTED LIMITATIONS**

---

## 1. Executive summary

Phase 2 delivered the Anime Hub discovery system on top of the Phase 1 data
foundation: Latest Updates, Anime Search with a full filter sheet, Global Anime
Ranking, Pubget Community Ranking, and the five-status My List. The work was
verifiable and mostly additive: score-range filtering threaded through every
tier (model, both providers, caches, provider request keys), the search screen
was rewritten so filters live in a bottom-sheet with active-filter chips, the
Latest Updates app bar gained search/home/drawer actions, and a race-condition
guard was added so a slow early query can never clobber the latest results. A
formatter-induced churn problem (new Dart "tall-style" `dart format` against
old-style code) was detected and fully reverted. Static analysis is clean and
172 targeted Flutter tests pass (0 fail); the full corpus is still capped by the
environment.

## 2. Task and objective

Implement the discovery surfaces: Latest Updates, Anime Search, Search Filters,
Global Anime Ranking, Pubget Community Ranking, and My List (five statuses),
using real data, with tests and verification. Constraints: real anime only
(no fake/dummy/seed data, no fabricated ratings, no fake provider responses);
empty success = empty state, failed request = error state; no
AnimeDetailsPage/CharacterDetailsPage work (Phase 3); no new dependencies;
prefer existing architecture; honor the Phase 1 contract.

## 3. Environment

- Flutter 3.32.8 / Dart 3.8.1; Node v20.19.0 / npm 10.8.2; macOS.
- Long single commands capped near 600 s by the harness; the full Flutter
  corpus (144 files) does not complete within it.

## 4. What already existed (verified, not re-built)

Global Anime Ranking and Pubget Community Ranking were present and tested
(widget tests "both ranking pages share one ranked anime card" and "popular
characters use the shared ranked character card"). My List already exposed the
five personal states through `AnimePersonalState` with localized labels,
wire-value backward compatibility, and edit-time sorting (tests pass). This
phase verified those surfaces (`anime_my_list_test`, ranking widget tests) and
focused new work on Search, Filters, and Latest Updates.

## 5. Changes — score-range filtering (model and data layer)

- `lib/features/anime/models/anime_models.dart`
  - `AnimeSearchFilter` gains `minScore` / `maxScore` (0–10 scale, matching the
    providers' `Anime.score`), `hasScoreRange`, `copyWith(..., clearMinScore,
    clearMaxScore)`.
  - `matchesCatalog` applies score bounds only when the title actually carries
    a score; an unknown score is never silently dropped by a client-side
    preview.
- `lib/features/anime/repositories/jikan_anime_repository.dart`
  - `_searchQuery` forwards `min_score` / `max_score`; new `_scoreParam` trims a
    trailing `.0`; bounds are emitted only when set.
- `lib/features/anime/repositories/anilist_anime_repository.dart`
  - `MediaPage` query declares `$averageScore_greater` / `$averageScore_lesser`
    and `_searchFilters` scales the 0–10 bounds by 10 (AniList is 0–100).
- Cache keys carry the bounds in every tier: `anime_providers.dart`
  (`_requestKey`), `cached_anime_repository.dart`, and
  `firestore_cached_anime_repository.dart`.

## 6. Changes — search screen and filter sheet

- `lib/features/anime/screens/anime_search_page.dart` (rewritten)
  - Filters moved from inline rows into a bottom sheet (`PubgetBottomSheet`)
    with per-dimension chip sections (type, season, year, genre, studio,
    status, age) plus a score `RangeSlider`.
  - App-bar filter action (`anime-search-filter`) shows a `Badge.count` of
    active dimensions; active filters surface as removable chips
    (`anime-active-filter-<dim>`).
  - Sheet keys: `filter-apply`, `filter-reset`, `filter-score-slider`,
    `filter-type-*`, `filter-season-*`, `filter-year-*`, `filter-genre-*`,
    `filter-studio-*`, `filter-status-*`, `filter-age-*`.
  - Localization for all new copy through `anime_mapping.dart` / `anime_copy.dart`
    (`filterScore`, `filterScoreMin`, `filterScoreMax`, `scoreRangeLabel`).
- `lib/features/anime/screens/anime_browse_page.dart`
  - Latest Updates (`latest: true`) gets a dedicated app bar: search leading
    (`anime-latest-search` → `/anime/search`), home action (`anime-latest-home`
    → Anime Hub), drawer action (`anime-latest-drawer`). RTL mirrors via
    leading/actions.

## 7. Changes — race-condition guard

`AnimeListProvider` search responses carry their request generation; a response
is discarded when a newer generation already owns the list. Verified by a new
test where three overlapping queries ("a", "an", "ani") resolve newest-first
and the stale responses must not clobber the latest results.

## 8. Changes — tests

- `test/anime_test_support.dart`: `FakeAnimeRepository.searchGates` map lets
  tests hold individual search responses open.
- `test/anime_search_test.dart`: race-guard test; score-range catalog test;
  score filter reaches the repository test.
- `test/anime_repository_test.dart`: Jikan `min_score`/`max_score` query test;
  unset bounds omitted test.
- `test/anilist_anime_repository_test.dart`: score bounds forwarded as
  `averageScore_greater`/`lesser` (70 / 95) test.
- `test/anime_screens_test.dart`: "hub type and season chips search without a
  name" updated to open the filter sheet, pick chips, and apply.

## 9. Formatter churn — found and reverted

Dart 3.8.1's `dart format` emits "tall-style" output that rewrites large
swathes of this repo's pre-existing old-style code. After formatting the 15
changed files, the diffs contained unrelated reflow. All changed files were
reverted to HEAD and the logical edits re-applied in the repo's existing style;
`git diff --stat` afterwards shows only intended hunks (15 files, 222 insertions,
10 deletions). `dart format` was not run repo-wide and the surviving wide-line
exceptions (e.g. the AniList query strings) predate this work.
**Lesson for later prompts:** do not run `dart format` on touched files for this
repo unless a dedicated formatting commit is wanted.

## 10. Verification — static analysis

`dart analyze lib/features/anime lib/core/l10n test/{anime_search,anime_screens,
anime_repository,anilist_anime_repository}_test.dart test/anime_test_support.dart`
→ **No issues found!** (exit 0)

## 11. Verification — executed tests (172 passed, 0 failed)

| Batch | Tests |
| --- | --- |
| `anime_search_test.dart` (incl. race + score) | 20 pass |
| `anime_repository_test.dart` (incl. Jikan score) | 42 pass |
| `anilist_anime_repository_test.dart` (incl. AniList score) | 10 pass |
| `anime_screens_test.dart` (incl. sheet interaction) | 31 pass |
| providers/l10n/pagination/my_list/chain/cache/mapper batch | 69 pass |

The only non-passing line was invoking `test/anime_test_support.dart` directly —
a support file with no `main()`, which is not a test and cannot be "run". No
real test failure was observed.

## 12. What was NOT run

- The complete Flutter corpus (144 files) does not complete within the ~600 s
  cap; only the targeted batches above were executed to completion.
- No device/emulator integration run; no live Jikan/AniList network call.

## 13. Acceptance gates

| Gate | Result |
| --- | --- |
| Latest Updates shows real newest-first catalog, paginated | **PASS** (existing + verified; pagination tests pass) |
| Anime Search works with and without a name query | **PASS** |
| Search Filters (type/season/year/genre/studio/status/age/score) | **PASS** (sheet + both providers + cache keys) |
| Score filter respects provider scales | **PASS** (0–10 normalized both providers) |
| Race-conditional search (out-of-order responses) | **PASS** (guard + test) |
| Global Anime Ranking / Community Ranking | **PASS** (pre-existing, verified) |
| My List five statuses | **PASS** (pre-existing, verified) |
| Localized copy for all new strings | **PASS** |
| Static analysis clean | **PASS** |
| Tests executed green | **PASS** (172 executed) |
| Full corpus green | **NOT VERIFIED** (environment cap; honest partial) |
| Community rating values on discovery cards | **BLOCKED** (documented limitation — see §14.3) |

## 14. Known limitations and risks

1. **Full corpus unverified** under the harness cap (§12); CI can close this.
2. **Community ratings on discovery cards** remain a documented limitation:
   there is no batch `anime_stats` endpoint, and per-card live scoring would
   exceed rate-limit guidance. Cards show the external/global score and the
   app's community aggregate where already loaded.
3. The repo's old-style formatting is now heterogeneous next to the rewritten
   `anime_search_page.dart` (which is intentionally formatted); this is visual
   only and analyzer-clean.

## 15. Contract updated

`docs/ANIME_HUB_REBUILD_CONTRACT.md` gained §29 (Search and filter contract:
single filter shape, cache keys in every tier, 0–10 score scale with provider
conversion, bounds only when set, generation guard) and §30 (Prompt 02
non-goals reaffirmed). Now 30 sections.

## 16. Non-goals honored

No new dependencies. No fake/seed data, no fabricated ratings. No
AnimeDetailsPage/CharacterDetailsPage/character work. No PR or merge. Pre-existing
migration modifications in other files were left untouched.

## 17. Deliverables

- 10 lib files and 5 test files changed (Phase 2 scope only).
- `docs/ANIME_HUB_REBUILD_CONTRACT.md` updated.
- This completion report.

## 18. Next steps

1. Run the full Flutter corpus in CI (removes the `NOT VERIFIED` gate).
2. Track the community-rating-on-cards limitation (§14.2) as a backlog item.
3. Phase 3: details/characters surfaces per the roadmap.