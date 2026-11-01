import '../models/anime_models.dart';

/// Relevance ranking for anime search results.
///
/// Priority (after normalizing query + titles across all title variants and
/// aliases, forgiving Latin/Arabic/Japanese inputs):
/// 0. exact title / alias match
/// 1. title / alias starts with the query
/// 2. title / alias contains the query
/// 3. fuzzy (Levenshtein) match tolerant of spelling slips and casing
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
    if (_fuzzyMatches(title, query)) return 3;
    return 99;
  }

  static bool _fuzzyMatches(String title, String query) {
    if (title.length < 2 || query.length < 3) return false;
    final maxDistance = query.length <= 4 ? 1 : 2;
    final lengthRatio = title.length * 3 < query.length * 2;
    if (lengthRatio) return false;
    final distance = _levenshtein(title, query);
    final normalized = distance * 10 <= query.length * 3;
    return distance <= maxDistance && normalized;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final previous = List<int>.generate(b.length + 1, (index) => index, growable: false);
    final current = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i += 1) {
      current[0] = i;
      for (var j = 1; j <= b.length; j += 1) {
        final substitution = previous[j - 1] + (a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1);
        current[j] = _min3(
          current[j - 1] + 1,
          previous[j] + 1,
          substitution,
        );
      }
      for (var j = 0; j <= b.length; j += 1) {
        previous[j] = current[j];
      }
    }
    return previous[b.length];
  }

  static int _min3(int a, int b, int c) {
    final lowest = a < b ? a : b;
    return lowest < c ? lowest : c;
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
    return <Anime>[...matched.map((entry) => entry.anime), ...unmatched];
  }
}
