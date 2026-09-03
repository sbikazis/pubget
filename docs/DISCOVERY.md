# Discovery and creator ranking

Home discovery is a ranked, personalized surface. Widgets never score content. The client asks Cloud Functions for a `DiscoveryFeed`; ranking, rising scores, qualified views, publication, and creator milestones stay on the server.

## Architecture

UI → HomeProvider → HomeRepository → `getDiscoveryFeed` → `recommendationEngine` → ranking + Firestore

Sensitive writes (anime lists, character favorites, Fan Work revisions, edit metrics) are callable-only. Firestore rules reject client creates/updates on those documents.

## Ranking formula

Content-specific weights live in `functions/src/ranking.js` (`WEIGHTS`). Each type uses the same components with different emphasis:

```
score = relevance + freshness + engagement + quality + social + velocity + creator
      − negativeFeedback − repetition − abuse
```

| Type | Dominant signals |
|---|---|
| Edit | qualified watch, completion, freshness, anime relevance |
| Group | interest overlap, rising velocity, response/quality, not member count |
| Person | shared anime/characters, mutuals, respect; never the viewer or blocked users |
| Fan Work | relevance, quality, freshness, engagement, copyright completeness |
| Event | group membership, start freshness, participation |
| Anime | interest overlap minus already-listed titles |

Scores are deterministic. Identical inputs produce identical order. Raw client counters are ignored.

## Personalization and cold start

`isColdStart` is true when the viewer has fewer than two combined anime, group, and friend signals. Cold start still returns every content type, mixing quality/trending/rising rather than hiding categories. `mixExploration` injects a 20% tail so popular items cannot occupy an entire page.

Diversity caps (`DIVERSITY`) keep a page from repeating the same creator or group more than twice.

## Rising groups

`calculateRisingScore` uses velocity, unique participants, profile completeness, reply rate, regularity, and activity. Large inactive groups are penalized. Burst/spam message rates are penalized. Member count is never the ranking key. `risingEligible` still requires a real activity floor.

## Anti-manipulation

- Unique-user qualified views, once per account/edit/day
- Self-views never increment public qualified/completion counters
- Playback sessions expire and cap credited seconds
- Repeat refresh cannot rewrite scores; ranking reads server aggregates
- Blocked users and non-searchable/private groups are excluded
- Moderation-rejected Fan Works are dropped before ranking
- Fan Work comments, likes, and comment reports are callable-only; clients cannot increment `commentsCount`

## Caching and pagination

Section pages use target-id cursors. Anime Hub keeps its existing in-memory/repository cache. Personalized feeds are not stored in a shared cache. Offline Home/Anime/Fan Work screens continue to distinguish loading, cached, error, and retry.

## Creator milestones

Existing achievements own rewards. Prompt 19 adds `edit_milestone` (five published edits) and `creator_fan_milestone` (first fan), granted only from server `evaluate` events.
