/// Live/fuzzy matching for anime and character pickers.
abstract final class GroupFuzzy {
  static bool matches(String query, String haystack) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    final hay = haystack.toLowerCase();
    if (hay.contains(needle)) return true;
    if (_subsequence(needle, hay)) return true;
    if (needle.length >= 3 && _nearToken(needle, hay)) return true;
    return false;
  }

  static bool _subsequence(String needle, String hay) {
    var index = 0;
    for (var i = 0; i < hay.length && index < needle.length; i++) {
      if (hay[i] == needle[index]) index++;
    }
    return index == needle.length;
  }

  static bool _nearToken(String needle, String hay) {
    for (final token in hay.split(RegExp(r'[^a-z0-9\u0600-\u06ff]+'))) {
      if (token.isEmpty) continue;
      if (token.contains(needle) || needle.contains(token)) return true;
      if ((token.length - needle.length).abs() > 1) continue;
      if (_edits(needle, token) <= 1) return true;
    }
    return false;
  }

  static int _edits(String a, String b) {
    if (a == b) return 0;
    if ((a.length - b.length).abs() > 1) return 2;
    if (a.length == b.length) {
      var diffs = 0;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) diffs++;
        if (diffs > 1) return diffs;
      }
      return diffs;
    }
    final longer = a.length > b.length ? a : b;
    final shorter = a.length > b.length ? b : a;
    var skip = 0;
    var i = 0;
    var j = 0;
    while (i < longer.length && j < shorter.length) {
      if (longer[i] == shorter[j]) {
        i++;
        j++;
        continue;
      }
      skip++;
      if (skip > 1) return skip;
      i++;
    }
    return skip + (longer.length - i);
  }
}
