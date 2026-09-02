/// Normalizes user-typed search input without inventing ranking.
abstract final class SearchQuery {
  static const minLength = 2;
  static const maxLength = 80;

  static String normalize(String raw) {
    final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.length <= maxLength) return collapsed;
    return collapsed.substring(0, maxLength);
  }

  static String prefix(String raw) => normalize(raw).toLowerCase();

  static bool isRunnable(String raw) => prefix(raw).length >= minLength;
}
