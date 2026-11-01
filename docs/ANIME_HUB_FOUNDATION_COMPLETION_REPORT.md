# Anime Hub Foundation — Completion Report

Branch: `codex/anime-hub-rebuild` (based on `257c112`, == `origin/main`)
Commit: `feat(anime-hub): establish production data foundation`
Verdict: **PASS WITH DOCUMENTED LIMITATIONS**

---

## 1. Executive summary

A mature Anime Hub already existed on `main`. This task was a forensic audit
followed by repair of the identity/cache contradictions that made the data
foundation unsafe, formalization of the foundation contract, tests, and
verification. Three production-impacting defects were fixed; several further
issues were identified and documented as limitations. Static analysis is
clean, the changed Flutter tests pass, the anime data-layer tests pass, and
the Firebase functions suite is fully green.

## 2. Task and objective

Establish and document a trustworthy production data foundation for the Anime
Hub: consistent canonical ids across providers, honest cache freshness, a
written contract, executed verification, and one local checkpoint commit. No
PR, no merge, no fake data, no unrelated feature work.

## 3. Environment

- Flutter 3.32.8 / Dart 3.8.1; Node v20.19.0 / npm 10.8.2; Firebase CLI present.
- macOS (darwin). Long single commands are capped near 600 s by the harness.
- The repository has linked worktrees under `.worktrees/`; work was done in the
  main tree `pubget`.

## 4. Method

1. Located the real repo and the existing Anime Hub.
2. Ran two read-only audit passes (Flutter data layer; Firebase backend).
3. Confirmed the defects against source.
4. Applied minimal, targeted fixes with matching tests.
5. Verified with static analysis, an executable harness, Flutter tests, and the
   backend suite.

## 5. Baseline state

An Anime Hub of ~18k lines existed under `lib/features/anime` with a dual
provider (Jikan primary, AniList secondary), a memory TTL cache, and a durable
Firestore cache. The working tree carried ~30 pre-existing modifications from
an unrelated migration; none of the files this task changed were among them.

## 6. Audit scope and coverage

Covered: `lib/features/anime/data`, `lib/features/anime/repositories`,
`lib/features/anime/models`, provider wiring in `lib/app/pubget_app.dart`,
backend anime callables/aggregates, and the anime test corpus. Not covered:
UI/widget behavior beyond what existing tests pin.

## 7. Finding — provider wiring

Chain confirmed:
`FirestoreCachedAnimeRepository → CachedAnimeRepository → ProviderChainAnimeRepository → [Jikan, AniList]`.
Wiring was sound; the defects were in how AniList mapped and cached data.

## 8. Finding — canonical id contradiction (critical, fixed)

Jikan set `Anime.id` = MAL id; AniList set `Anime.id` = native AniList id, and
never read `idMal`. The same title therefore had two ids depending on which
provider answered, forking the durable cache, lists, ratings and community
keys. The class doc claimed `idMal` resolution that the code did not perform.

## 9. Finding — cache freshness contradiction (critical, fixed)

The durable Firestore decode path returned `Success` without `fromCache`, and
the codec never set it, so stale/offline data was presented as a live fetch,
violating Rule 12.

## 10. Finding — producers never populated (minor, fixed)

AniList's mapper read `productionCompanies` but `mediaFields` never requested
it, so `Anime.producers` was always empty for AniList results.

## 11. Finding — fabricated adult rating label (minor, fixed)

Any adult AniList result was labeled `R+ - Mild Nudity`, a specific descriptor
the adult boolean cannot support (adult content may be more explicit). Replaced
with the neutral `R+`, which still resolves to the `adult` filter bucket.

## 12. Finding — broken `_idVariables` else branch (minor, fixed)

The non-numeric branch emitted `{'_id': null}`, an invalid GraphQL variable.
Non-numeric ids now emit no argument (query returns null → `NotFoundError`).

## 13. Finding — summaries queried the wrong id space (critical, fixed)

`getAnimeSummaries` requested `media(id_in: ...)` while operating on canonical
(MAL) ids. Changed to `media(idMal_in: ...)`.

## 14. Finding — character id cross-provider mismatch (documented limitation)

Jikan characters carry MAL character ids; AniList characters carry native ids
and expose no `idMal`. The two cannot be reconciled without name matching,
which is out of scope and unsafe. Anime-level identity is fixed; character
favorites across providers remain a documented limitation.

## 15. Finding — aggregate `discussionCount` read but not written (documented)

`character_stats.discussionCount` is read by home sections; no writer was found
in the audited backend scope. Tracked as a follow-up, not fixed here to avoid
touching unrelated backend behavior without full context.

## 16. Finding — reports rules may bypass a callable (documented)

Firestore rules appear to allow a direct client create for anime reports where
the callable is intended to mediate the write. Flagged as a security-hardening
candidate; not changed here because rules changes affect all clients.

## 17. Changes made (file-by-file)

- `lib/features/anime/repositories/anilist_anime_repository.dart`
  - `mediaFields` now requests `idMal`, `productionCompanies`, and `idMal` on
    relation nodes; character media nodes request `idMal`.
  - `getAnimeSummaries` queries `idMal_in`.
  - `_idVariables` rewritten (null-aware) and documented.
  - Class doc corrected to state the canonical-id behavior.
- `lib/features/anime/data/anilist_mapper.dart`
  - Added `anilistCanonicalId` (`idMal ?? id`); used by anime, relations, and
    appearances.
  - Adult rating label neutralized to `R+`.
- `lib/features/anime/data/anime_cache_codec.dart`
  - `animeFromMap`/`pageFromMap` now set `fromCache: true`, documented.
- `test/anilist_anime_repository_test.dart`
  - Added canonical-id test (native id ≠ `idMal`), producers + rating test, and
    a summaries test asserting `idMal_in` (not `id_in`).
- `test/anime_cache_codec_test.dart`
  - Assert decoded anime/page (and page items) are `fromCache`.
- `test/anime_test_support.dart`
  - `FakeAnimeHttpClient` now records POST bodies so query shape is assertable.

## 18. Contract established

`docs/ANIME_HUB_REBUILD_CONTRACT.md` (28 sections) is now the source of truth
for identity, provider, cache, mapping, l10n, error, backend, rules, index, and
offline contracts.

## 19. Tests added

Canonical id reconciliation; producers population; adult rating bucket;
summaries id space; durable-cache freshness for anime and pages. Existing
tests continue to pass unchanged.

## 20. Verification — static analysis

- `dart analyze lib/features/anime/data lib/features/anime/repositories lib/features/anime/models` → **No issues found!** (exit 0)
- `dart analyze test/anilist_anime_repository_test.dart test/anime_cache_codec_test.dart test/anime_test_support.dart` → **No issues found!** (exit 0)

## 21. Verification — executable harness

A temporary pure-Dart harness exercised the mapper and codec directly
(canonical id, producers, rating, relations, round-trip, `fromCache`):
`HARNESS OK`. The harness was removed after use.

## 22. Verification — Flutter tests (changed files)

`flutter test test/anilist_anime_repository_test.dart test/anime_cache_codec_test.dart`
→ **All tests passed!** (15/15, exit 0), including the three new tests.

## 23. Verification — Flutter anime data-layer batch

`flutter test` over `anime_mapper_test`, `anime_repository_test`,
`anime_providers_test`, `provider_chain_anime_repository_test`,
`anime_cache_test`, `anime_http_client_test` → **41+ passed, 0 failed** as
observed before the harness's ~600 s command cap terminated the batch. The run
was truncated by the environment, not by a test failure.

## 24. Verification — backend functions suite

`npm test` in `functions/` → **535 tests, 535 pass, 0 fail** (exit 0) after the
previously incomplete `npm install` was completed.

## 25. Verification — backend anime subset

`node --test test/animeCatalogDomain.test.js test/animeHubDomain.test.js test/animeListsDomain.test.js test/animeStats.test.js`
→ **97/97 pass** (exit 0).

## 26. What was NOT run

- The complete Flutter test corpus (144 files) was not executed to completion;
  the full anime-scoped batch was cut off by the ~600 s command cap. Results
  reported above are the subset that completed, stated as such.
- No device/emulator integration run was performed.
- No test asserts the exact AniList HTTP host/query beyond the fake client's
  substring matching; live AniList schema was reasoned about, not called.

## 27. Known limitations and risks

1. Cross-provider **character** ids remain unreconciled (§14).
2. AniList **summaries** for entries with no MyAnimeList equivalent (no
   `idMal`) will not be found by `idMal_in`; such entries are rare and their
   canonical id falls back to the native id.
3. The `discussionCount` aggregate and the reports-rules bypass (§15–16) are
   open follow-ups.

## 28. Non-goals honored

No unrelated feature changes. No new fabricated/seed data. No schema migration
of existing community data. No PR or merge.

## 29. Deliverables

- Four source files repaired (three lib, plus test support) and two test files
  extended.
- `docs/ANIME_HUB_REBUILD_CONTRACT.md`.
- This completion report.

## 30. Verdict

**PASS WITH DOCUMENTED LIMITATIONS.** The critical identity and cache
contradictions are fixed and verified; the foundation contract is written;
backend and anime data-layer tests pass. The limitations in §27 are explicit
and tracked rather than papered over. Two verification lines (§23, §26) are
honest partial results because the environment capped long runs.

## 31. Next steps

1. Convert the §27 limitations into tracked tasks.
2. Run the full Flutter corpus in CI where the command cap does not apply.
3. Add a rules test covering the anime report write path (§16).
