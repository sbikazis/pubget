import '../models/anime_models.dart';

/// Relevance ranking for anime search results.
///
/// Priority (after normalizing query + titles):
/// 1. exact title / alias match
/// 2. title / alias starts with the query
/// 3. title / alias contains the query
/// Within each tier: higher score, then better (lower) MAL popularity rank.
abstract final class AnimeSearchRanker {
  static String normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static int matchTier(Anime anime, String rawQuery) {
    final query = normalize(rawQuery);
    if (query.isEmpty) return 99;
    final titles = <String>[
      anime.title,
      ...anime.alternativeTitles,
    ].map(normalize).where((title) => title.isNotEmpty);

    var best = 99;
    for (final title in titles) {
      final tier = _tierFor(title, query);
      if (tier < best) best = tier;
      if (best == 0) return 0;
    }
    return best;
  }

  static int _tierFor(String title, String query) {
    if (title == query) return 0;
    if (title.startsWith(query)) return 1;
    if (title.contains(query)) return 2;
    return 99;
  }

  /// Stable sort: match tier → score desc → popularity asc → title.
  ///
  /// When [keepUnmatched] is true (remote API pages), non-matching titles are
  /// kept after ranked hits so a Jikan/page payload is never wiped empty.
  /// Local catalog preview should leave [keepUnmatched] false.
  static List<Anime> rank(
    List<Anime> source,
    String rawQuery, {
    bool keepUnmatched = false,
  }) {
    final query = normalize(rawQuery);
    if (query.isEmpty) return List<Anime>.of(source);

    final scored = source
        .map((anime) => (anime: anime, tier: matchTier(anime, query)))
        .toList(growable: false);

    final matched = scored.where((entry) => entry.tier < 99).toList();
    matched.sort((a, b) {
      final byTier = a.tier.compareTo(b.tier);
      if (byTier != 0) return byTier;
      final scoreA = a.anime.score ?? -1;
      final scoreB = b.anime.score ?? -1;
      final byScore = scoreB.compareTo(scoreA);
      if (byScore != 0) return byScore;
      final popA = a.anime.popularity ?? 1 << 30;
      final popB = b.anime.popularity ?? 1 << 30;
      final byPop = popA.compareTo(popB);
      if (byPop != 0) return byPop;
      return a.anime.title.toLowerCase().compareTo(b.anime.title.toLowerCase());
    });

    if (!keepUnmatched) {
      return matched.map((entry) => entry.anime).toList(growable: false);
    }

    final unmatched = scored
        .where((entry) => entry.tier >= 99)
        .map((entry) => entry.anime);
    return <Anime>[
      ...matched.map((entry) => entry.anime),
      ...unmatched,
    ];
  }
}
