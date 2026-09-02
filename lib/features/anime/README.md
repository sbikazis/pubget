# Anime Hub

Independent catalog domain. The UI never talks to the remote provider.

```text
UI (screens/widgets)
  → Provider (hub / list / details)
    → AnimeRepository (contract)
      → CachedAnimeRepository
        → JikanAnimeRepository (adapter)
          → ResilientAnimeHttpClient
            → External catalog API
```

Replace the provider by implementing `AnimeRepository` (or swapping only
`JikanAnimeRepository`) in `lib/app/pubget_app.dart`. Screens, widgets,
providers, Home, and Search stay unchanged.

## Contract

`AnimeRepository` returns `Result<T>` with domain models from
`models/anime_models.dart`. IDs are opaque strings. Pagination uses
`AnimePage.hasNextPage`.

## Current adapter

Jikan v4 (`https://api.jikan.moe/v4`), no API key.

| Repository method | Jikan source |
| --- | --- |
| `searchAnime` | `GET /anime?q=` |
| `getAnimeDetails` | `GET /anime/{id}/full` |
| `getTrending` | `GET /top/anime?filter=favorite` |
| `getPopular` | `GET /top/anime?filter=bypopularity` |
| `getTop` | `GET /top/anime` |
| `getAiring` | `GET /top/anime?filter=airing` |
| `getThisSeason` | `GET /seasons/now` |
| `getUpcoming` | `GET /seasons/upcoming` |
| `getCharacters` | `GET /anime/{id}/characters` |
| `getGenres` | `GET /genres/anime?filter=genres` |
| `getByGenre` | `GET /anime?genres=` |
| `getAvailableSeasons` | `GET /seasons` |
| `getBySeason` | `GET /seasons/{year}/{season}` |

Rate limit: requests are serialized (~350ms gap), HTTP 429 uses `Retry-After`
(capped at 5s), and only timeout / 5xx / 429 are retried (max 2 retries).

## Caching

In-memory `TtlCache`. TTL examples: details/characters 6h, genres/seasons
index 24h, trending/popular/top 15m, airing 10m, search 5m. Offline + cache
returns cached data with `fromCache`. Offline + no cache returns `NetworkError`.

## Pagination

Page numbers start at 1. `loadMore` appends, ignores duplicate in-flight pages,
and keeps previous items if the next page fails.

## Search

Home discovery search still uses `HomeRepository` for groups/people/events and
adds first-page anime from `AnimeRepository` when the query has at least 2
characters. Anime Hub has its own debounced search (280ms).

## Deep links

- `/anime` hub
- `/anime/{id}` details
- `/anime/browse?kind=trending|popular|top|airing|thisSeason|upcoming`
- `/anime/genre?genreId=`
- `/anime/season?year=&season=winter|spring|summer|fall`

Protected like other domains: unauthenticated visits go to login, then return.

## Favorites

Uses existing `favoriteAnimeIds` on the user profile via
`updateSocialProfile`. Only opaque anime IDs are stored (max 50).
