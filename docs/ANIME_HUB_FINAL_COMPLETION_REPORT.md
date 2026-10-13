# Anime Hub Rebuild — Final Completion Report (Prompt 04)

Phase 4 closes the rebuild: it audits the whole feature against the contract,
integrates the concurrent `origin/main` work, resolves the one open discovery
limitation (community ratings on cards), runs the validation suites, and lands a
single pull request. It does **not** deploy anything and does **not** merge to
`main`.

## 1. Branch and integration state

- Work is committed on `codex/anime-hub-rebuild` over the three phase commits:
  `219998f` (Phase 1 foundation), `73d2d3c` (Phase 2 discovery), `a606f1f`
  (Phase 3 details/characters/report-anime).
- `origin/main` (`d3681fe`, PRs #148/#149/#150) was merged into the branch as
  merge commit `e0b8a4b`. The merge was **clean** — the two files touched on both
  sides kept both workstreams:
  - `firebase_anime_hub_social_repository.dart`: the report-anime callable (ours)
    plus the transient-Firebase `_guard`/retry + failure-mapper (main).
  - `anime_details_page.dart`: the staff strip and scrollable characters tab
    (ours) plus the shared `AppImageLoader` reel path (main).
- The pre-existing unstaged migration files in the original checkout are
  already merged to `main` and byte-identical to it, so nothing unique was lost.

## 2. Audit results

- **Integration/navigation** — every `/anime*` route resolves to a live
  destination; `anime_hub_page.dart` is dead code on `main` too and is left in
  place (documented, not deleted). No broken back-navigation or provider leak
  found.
- **Backend/security** — `animeHubDomain.js` derives the actor from the auth
  context only, caps every string, validates scores as 0–10 integers, and runs
  upsert/delete/report through transactions with cooldown and idempotency
  guards. `firestore.rules` keeps `anime_lists`, `anime_ratings`, `anime_stats`,
  `character_stats`, `anime_reports`, and the rate docs client-write-false.
- **Characters** — `setCharacterFavorite` is an idempotent transaction that
  writes `character_stats/{id}.favoritesCount`, so Popular Characters ranks by
  distinct favouring users, not by write count.
- **Cache/offline** — durable cache keys carry every filter constraint; offline
  reads surface the cached banner and offline state; no cross-account leak
  (user lists are re-guarded by `_userId`).
- **Localization/visual** — no hardcoded user-facing string in the new surfaces;
  strings flow through `AnimeCopy`. The characters-tab overflow was fixed in
  Phase 3 and is covered by a test.
- **Secrets/artifacts** — no secrets, keys, or debug prints in the branch diff.

## 3. The one implementation added in Phase 4: batched community stats

The Phase 2 report documented that discovery cards could not show Pubget
community ratings because no aggregate-by-id endpoint existed, and that
per-card live scoring was deliberately avoided. Phase 4 resolves this without
fabrication and without N+1 reads:

- **Backend** — new signed-in callable `getAnimeCommunityStats({animeIds})`
  reads the server-authoritative `anime_stats` store in chunks of 10 (the
  Firestore `in` limit) for up to 30 ids. A title with no document is simply
  **absent** from the result, never reported as zero. Registered in
  `functions/index.js`; unit-tested against the same fake DB as the rest of the
  domain.
- **Client** — `AnimeHubSocialRepository.getAnimeCommunityStats` (Firebase and
  unavailable implementations).
- **Provider** — `AnimeHubSocialProvider.loadStatsFor(ids)` fills the existing
  `_statsById` cache that `statsFor` already serves, de-duping by cached and
  in-flight ids so a rebuild issues no request and each unseen title is fetched
  at most once.
- **UI** — `AnimePaginatedList` (the shared scroller behind search and browse)
  batches the ids on screen after the frame. Cards keep reading `statsFor`, so
  no card widget forks and a title without an aggregate keeps its external
  score.

## 4. Validation evidence

| Suite | Result |
| --- | --- |
| `dart analyze` (whole tree) | No issues found |
| Flutter — logic batch (17 files) | **145 passed** |
| Flutter — widget/provider batch (8 files) | **83 passed** |
| Flutter — merged main-side suites (app shell / home / discovery) | **18 passed** |
| Backend — anime domain files (`animeHubDomain`, `animeListsDomain`, `animeStats`, `animeCatalogDomain`, `animeChainRebirth`) | **107 passed** |
| New backend batch tests | 3 added, all green |
| New client tests | `loadStatsFor` unit test + grid-wiring widget test, both green |

**Honest scope note (PARTIAL):** the *entire* repository corpus was **not** run
to completion within the ~600s budget — it is far larger than the feature. The
backend suite additionally contains emulator-dependent files
(`*.live.emulator`, `firestore.rules`, `storage.rules`, `*.e2e`) that require a
running Firebase emulator and installed `functions/node_modules`; in the fresh
integration worktree those fail on `Cannot find module` and hang once deps are
present, so they are reported as not-run here rather than passed. Every suite
that touches the anime hub — client and backend — is green.

## 5. Remaining documented limitations

- `anime_hub_page.dart` is unreferenced dead code (present on `main`; left
  untouched to avoid scope creep).
- The dual source of truth for *anime* favourites (profile `favoriteAnimeIds`
  vs. library `isFavorite`) is inherited and unchanged (contract §31.4).
- Discovery cards show a Pubget aggregate only once the server holds one; the
  external score remains the fallback. This is by design, not a gap.

## 6. What this phase does not do

No Firebase Functions deploy, no production config change, no merge to `main`.
The deliverable is the branch pushed and one pull request opened against
`origin/main`.
