/// Matching for the global search box (spec §6).
///
/// The previous behaviour was a prefix check, so a typo — or one missing letter
/// in an Arabic name — returned nothing and read as "no such thing exists".
/// These helpers add *tolerant* matching without inventing results: every
/// non-null score means the candidate genuinely contains the query's characters
/// in order.
///
/// Deliberately a pure function rather than a search-service call: fuzzy
/// ranking belongs where the candidate list already is, so it works offline and
/// is unit-testable without a backend.
abstract final class SearchRank {
  /// Arabic diacritics (tashkeel) and tatweel. Members type `انمى` while the
  /// catalog holds `أنمى`, and nobody expects to need the hamza to find it.
  static final _diacritics = RegExp(r'[\u064B-\u065F\u0670\u0640]');
  static final _alef = RegExp('[أإآ]');
  static final _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  /// Lower-cases, strips diacritics, folds alef variants and collapses
  /// punctuation to single spaces. Applied to both sides before comparing.
  static String fold(String raw) {
    var value = raw.toLowerCase();
    value = value.replaceAll(_diacritics, '');
    value = value.replaceAll(_alef, 'ا');
    value = value.replaceAll('ى', 'ي');
    value = value.replaceAll('ة', 'ه');
    value = value.replaceAll(_nonWord, ' ').trim();
    return value.replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Returns null when [candidate] does not match, otherwise a score where
  /// higher is better. Tiers, best first:
  ///   exact (1000) > prefix (800) > word prefix (600) > substring (400)
  ///   > in-order subsequence (200 down to 1, by tightness).
  static int? score(String query, String candidate) {
    final q = fold(query);
    final c = fold(candidate);
    if (q.isEmpty) return null;
    if (c.isEmpty) return null;
    if (c == q) return 1000;
    if (c.startsWith(q)) return 800 - (c.length - q.length).clamp(0, 99);
    final at = c.indexOf(q);
    if (at >= 0) {
      final atWordStart = at == 0 || c[at - 1] == ' ';
      return atWordStart ? 600 - (c.length - q.length).clamp(0, 99) : 400;
    }
    return _subsequence(q, c);
  }

  static bool matches(String query, String candidate) =>
      score(query, candidate) != null;

  /// Characters of [query] appearing in [candidate] in order, penalised by the
  /// gaps between them so `naruto` beats a scattered accidental match.
  static int? _subsequence(String q, String c) {
    var cursor = 0;
    var gaps = 0;
    var lastHit = -1;
    for (var i = 0; i < q.length; i += 1) {
      final found = c.indexOf(q[i], cursor);
      if (found < 0) return null;
      if (lastHit >= 0) gaps += found - lastHit - 1;
      lastHit = found;
      cursor = found + 1;
    }
    final score = 200 - gaps - (c.length - q.length).clamp(0, 150);
    return score < 1 ? 1 : score;
  }

  /// Ranks [items] by [keyOf], dropping non-matches, preserving input order for
  /// equal scores (so a stable server order is not scrambled by the filter).
  static List<T> rank<T>(
    Iterable<T> items,
    String query,
    String Function(T item) keyOf,
  ) {
    final scored = <({T item, int score, int index})>[];
    var index = 0;
    for (final item in items) {
      final score = SearchRank.score(query, keyOf(item));
      if (score != null) scored.add((item: item, score: score, index: index));
      index += 1;
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.index.compareTo(b.index);
    });
    return <T>[for (final entry in scored) entry.item];
  }
}
