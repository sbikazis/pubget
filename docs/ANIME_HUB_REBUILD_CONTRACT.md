# Anime Hub Data Foundation Contract

Status: **Established** by Prompt 01 — ANIME-HUB-FOUNDATION.
Authority: this document is the single source of truth for the Anime Hub data
layer. Where code and this contract disagree, the disagreement is a defect.

---

## 1. Purpose and scope

This contract fixes the *data foundation* of the Anime Hub: the provider
adapters, the caching tiers, the canonical identity of catalog entities, and
the wire contract between the Flutter client and the Firebase backend. It
covers only read/catalog/identity concerns plus the list/rating/favorite write
surfaces that depend on identity. It does not redesign UI, navigation, or
unrelated features.

## 2. Definitions

- **Canonical id** — the single string id under which an anime is cached,
  favorited, listed, rated, and keyed in community stores.
- **Primary provider** — Jikan (MyAnimeList). **Alternative provider** — AniList.
- **Tier** — one of: memory TTL cache, durable Firestore cache, remote provider.
- **fromCache** — boolean on `Anime`/`AnimePage` marking a value served from a
  local tier rather than a live network fetch.
- **Fresh** — produced by a live remote fetch in the current request.
- **Rule 12** — the operating rule that cached/offline data must be surfaced
  as cached, never presented as a live result.

## 3. Repository layer chain (authoritative)

```
FirestoreCachedAnimeRepository        (durable tier, outer)
  └─ CachedAnimeRepository            (in-memory TTL + in-flight dedupe)
       └─ ProviderChainAnimeRepository (primary/secondary fallback)
            ├─ JikanAnimeRepository    (primary)
            └─ AniListAnimeRepository  (secondary)
```

Wiring lives in `lib/app/pubget_app.dart`. The durable tier is the outermost
wrapper and is consulted only when every inner tier fails.

## 4. Canonical identity contract

1. Every `Anime.id` MUST be the MyAnimeList id when the answering provider can
   supply one.
2. Jikan supplies the MAL id natively (`mal_id`).
3. AniList MUST map `idMal` to the canonical id and fall back to AniList's
   native `id` **only** when `idMal` is absent.
4. Related-anime edges and character animeography MUST use the same canonical
   rule so navigation never crosses id spaces.
5. Batch summaries MUST be requested and matched in the canonical id space.
6. Community/library stores MUST be keyed on the canonical id.

## 5. Provider precedence and fallback contract

The chain returns the primary provider's result when it succeeds. Only on a
primary failure (error, rate limit, timeout, or offline) does it fall back to
the alternative provider. Fallback MUST NOT be observable as a different id
space (see §4).

## 6. Provider status contract

`ProviderChainAnimeRepository` exposes `AnimeProviderStatus` so the UI can
state which provider answered. Status MUST reflect the provider that actually
produced the returned data, not the provider that was attempted first.

## 7. Freshness and cache contract (Rule 12)

1. A value produced by a live fetch has `fromCache == false`.
2. A value served from any local tier has `fromCache == true`.
3. Decoding from the durable tier MUST set `fromCache == true`.
4. The UI renders its offline/stale affordance when `fromCache == true`.
5. Cached data MUST NEVER be emitted with `fromCache == false`.

## 8. Durable cache layout contract

Durable entries live under `users/{uid}/anime_cache/{base64Url(key)}` with a
`payload`, `savedAt`, and `expiresAt`. Writes are best-effort and never fail
the caller. A read is attempted only after a full miss/failure of inner tiers.

## 9. In-memory cache contract

`CachedAnimeRepository` performs TTL caching plus in-flight request dedupe.
Cache hits and offline serves are marked `fromCache: true`. Expired entries may
be served as a last resort when the inner catalog fails, still marked cached.

## 10. Jikan mapping contract

`mapJikanAnime` sets `id = mal_id`, maps titles (Arabic/English/Japanese),
genres, studios, producers, relations, ratings, images, trailer and external
links. Malformed entries are skipped, never thrown.

## 11. AniList mapping contract

`mapAniListAnime` sets `id` via the canonical rule (§4), maps native title to
the Japanese slot, maps romaji/english to alternatives, strips HTML, maps
genres/studios/producers/relations, and derives a neutral adult rating (§13).
Malformed entries are skipped, never thrown.

## 12. Field-manifest contract

Each provider request MUST request the fields the mapper consumes. A mapper
reading a field the query never selects is a defect (it silently yields null).
AniList `mediaFields` MUST include `id`, `idMal`, `productionCompanies`, and
`idMal` on relation/character media nodes.

## 13. Rating / age-rating contract

`Anime.ageRating` derives the filter bucket from the rating string. Providers
that only expose an adult boolean MUST map to a rating that resolves to the
`adult` bucket; they MUST NOT fabricate a narrower descriptor than the data
supports (e.g. a specific "Mild Nudity" label) for content that may be more
explicit.

## 14. Localization contract

All Anime Hub copy resolves through the localization mapping
(`lib/core/l10n/anime_mapping.dart`, `lib/features/anime/l10n/`). API payload
values (titles, Japanese names, MAL ids) pass through untranslated. Unknown
keys pass through rather than disappearing.

## 15. Error taxonomy contract

Network outcomes map to the core failure types: `NotFoundError` (404),
`RateLimitedError` (429), `UnavailableError` (5xx), `MalformedDataError`,
`TimeoutError`, `NetworkError`/offline. Callers branch on failure type, never
on string matching.

## 16. Pagination contract

Pages carry `items`, `page`, `hasNextPage`. `hasNextPage` drives "load more".
Page numbers are 1-based. Duplicate items within a page are dropped.

## 17. Batch summaries contract

`getAnimeSummaries(ids)` performs chunked batch fetches, preserves the caller's
id space, deduplicates by canonical id, and returns partial results plus the
first failure only when nothing was collected.

## 18. Characters and favorites contract

Characters are mapped with id, name, role, favorites, image, voice actors, and
animeography. Character favorites are keyed by character id. Cross-provider
character identity is a documented limitation (§ in completion report) because
AniList characters expose no MyAnimeList id.

## 19. Community / library key contract

Anime library entries, lists, ratings, and community feeds are keyed by the
canonical anime id. Because the canonical id is provider-stable (§4), the same
title keyed via either provider resolves to one record.

## 20. Backend callable contract

Anime callables (`functions/src/animeListsDomain.js`, `animeHubDomain.js`)
run as `onCall` in `us-central1`, require authentication, and enforce the
write cooldown. Callables validate arguments before touching Firestore.

## 21. Backend aggregate contract

Aggregates (`functions/src/animeStats.js`, `character_stats`) are recomputed
from source data. Any counter read by the client MUST have a writer; a
read-only counter is a defect to be tracked.

## 22. Firestore rules contract

Anime collections enforce owner- or membership-scoped access. Rules MUST NOT
allow a client to bypass a callable to write data the callable is meant to
mediate (e.g. aggregate counters). Rules are reviewed alongside callables.

## 23. Index contract

Every compound query issued by the client or functions MUST be backed by an
entry in `firestore.indexes.json`. Missing indexes are defects.

## 24. Offline behavior contract

Offline with cache → cached data marked `fromCache`. Offline without cache →
a network failure surfaced to the UI. The app never blocks on the durable tier.

## 25. Non-goals

Building a new Anime Hub from scratch; changing unrelated features; schema
migrations of existing community data; redesigning UI; introducing fake/seed
data anywhere.

## 26. Invariants

1. No `Anime.id` differs by provider for the same title.
2. No cached value is emitted as fresh.
3. No mapper reads a field its query does not request.
4. No user-facing string is hardcoded outside the localization mapping.
5. No malformed provider payload throws across the repository boundary.

## 27. Verification requirements

Static analysis MUST be clean for changed scopes. Mapping/codec logic MUST be
covered by executed tests (unit or harness). Backend changes MUST pass the
functions suite. Unrun checks MUST be reported as unrun, never as passing.

## 28. Governance

Any change to identity, cache, or provider semantics MUST update this contract
in the same change. This document is versioned with the code.

## 29. Search and filter contract (Prompt 02 — discovery)

1. `AnimeSearchFilter` is the single filter shape; the UI only ever mutates the
   provider through `applyFilter`, never through bespoke query strings.
2. Every constraint the filter carries MUST be forwarded to the answering
   provider and MUST appear in the request cache key of every tier
   (`_requestKey` in the provider, the search cache keys in both durable
   wrappers). A constraint absent from one tier is a defect.
3. Filtering a locally held catalog snapshot
   (`AnimeListProvider.applyFilter` while a catalog is open) MUST pass each
   item through `AnimeSearchFilter.matchesCatalog`; a title whose rating is
   unknown MUST NOT be silently dropped by a score bound.
4. Score bounds use the 0–10 scale that both providers already expose
   (`Anime.score`). AniList's 0–100 `averageScore` is scaled back to 0–10 by
   the mapper, so the filter bounds are multiplied by 10 when forwarded to
   AniList and sent verbatim to Jikan (`min_score`/`max_score`, trailing `.0`
   trimmed).
5. A score bound MUST be emitted only when set; omitting an unset bound is the
   default and MUST stay true for both providers.
6. Search result generations are ordered by request; a response MUST be
   discarded when a newer generation already owns the list, so a slow early
   query can never clobber the latest results (race-condition guard).

## 30. Prompt 02 — non-goals reaffirmed

The discovery system reuses the Phase 1 foundation unchanged. No new
dependencies were introduced. Community rating values on discovery cards are
now served by the batched `getAnimeCommunityStats` callable added in §33; a card
shows the Pubget aggregate only when the server actually holds one for that
title, and falls back to the external score otherwise. Per-card live
(one-request-per-title) scoring is still deliberately avoided.

## 31. Details and characters contract (Prompt 03)

1. **Real data only.** Every title, character, staff member, voice role,
   appearance, synopsis, rating, favorite count and ranking shown on the details
   and characters surfaces originates from the answering provider or the Pubget
   backend. No value is fabricated, seeded, or inferred to fill a gap.
2. **No broadcasting surface.** The details page exposes no episode list, no
   player, no watch button, and no streaming section. A trailer is shown only
   when the provider returns a genuine trailer URL, and it plays through the
   existing shared Reels player — never a bespoke player.
3. **Independent section loading.** The characters and staff strips load
   independently of the title payload; a failure in one MUST NOT sink the other
   or the page. `NetworkError`/`TimeoutError` map to the offline state via
   `animeFailureState`; only genuine provider errors surface as `error`.
4. **Character favorites** are persisted through the single
   `character_favorites` repository with an idempotent `setCharacterFavorite`.
   The pre-existing dual source of truth for anime favorites (profile
   `favoriteAnimeIds` vs. library `isFavorite`) is intentionally left unchanged
   and remains a documented limitation.
5. **Reporting** reuses the shared `REPORT_REASONS` catalog
   (`["inappropriate","spam","copyright","harassment","other"]`) on both the
   client and the backend. `reportAnime` mirrors `reportEvent`: the client sends
   `{animeId, category, detail}`, the backend stores idempotently per reporter at
   `anime_reports/{animeId}/reports/{reporterId}` (with `repeatCount`) and rate
   limits via `animeReportRate` (60-minute window, 10 max), bypassed for a
   repeat report of the same title.
6. **Localization.** Every new user-visible string is declared in
   `anime_mapping.dart` and surfaced through `AnimeCopy`; widgets never
   hardcode an Arabic or English label. Data tokens (staff roles, genres,
   status) remain provider-original.
7. **Scrollable tabs.** Each details tab is independently scrollable; a tab's
   content MUST NOT overflow its viewport.

## 32. Prompt 03 — non-goals reaffirmed

No new dependencies. No fabricated data. No streaming/broadcasting feature. No
separate staff-only page (staff render as info-only cards). No PR or merge
(final integration is reserved for Prompt 04).

## 33. Final integration contract (Prompt 04)

1. `origin/main` is merged into the branch; the merge is a fast-forwardable
   commit whose only textual overlaps are resolved by keeping both workstreams
   (the report-anime flow and the transient-Firebase retry guard in the social
   repository; the staff strip and the shared `AppImageLoader` reel path in the
   details page).
2. **Batched community aggregates.** `getAnimeCommunityStats({animeIds})` is a
   signed-in callable that reads the server-authoritative `anime_stats` store in
   chunks of 10 (Firestore `in` limit) for up to 30 ids, returning the same
   shape as the single-title read. It never fabricates a value: a title with no
   document is simply absent, never reported as zero.
3. **Discovery grid wiring.** `AnimePaginatedList` batches the ids on screen and
   asks the social provider to fill its stats cache after the frame; the
   provider de-dupes by cached and in-flight ids, so each unseen title is
   fetched at most once and a rebuild issues no request. Cards read the cache
   through the existing `statsFor` lookup, so no card widget forks.
4. **Non-goals.** The callable adds no schema, no dependency, and no client-side
   aggregation; ranking pages keep their dedicated `listTopRated`/
   `listMostListed` reads. No production deploy, no merge to main from this
   phase.
