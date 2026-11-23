/// Bounded, expiry-aware cache for short-lived signed media URLs.
///
/// The media Worker issues R2 URLs with a finite signature lifetime. Reaching
/// the Worker once per image rebuild wastes a round trip and, worse, can hand
/// the image decoder a URL that expires mid-session. This cache stores each
/// signed URL until shortly before its own expiry, so a URL is never served
/// after its signature is no longer valid.
library;

final class ResolvedMediaUrl {
  const ResolvedMediaUrl({required this.url, required this.expiresAt});

  final String url;
  final DateTime expiresAt;

  /// True when the URL is still usable at [now] with a safety margin applied.
  bool isUsableAt(DateTime now, Duration safetyMargin) =>
      expiresAt.isAfter(now.add(safetyMargin));
}

final class MediaUrlCache {
  MediaUrlCache({
    this.safetyMargin = const Duration(seconds: 30),
    this.maxEntries = 128,
    DateTime Function()? clock,
  }) : assert(maxEntries > 0, 'maxEntries must be positive'),
       _clock = clock ?? DateTime.now;

  /// How long before the signature's stated expiry a URL is considered stale.
  final Duration safetyMargin;
  final int maxEntries;
  final DateTime Function() _clock;
  final Map<String, ResolvedMediaUrl> _entries = <String, ResolvedMediaUrl>{};

  /// Returns a cached URL only when it is still fresh; stale entries are
  /// removed so a failed refresh cannot silently serve an expired signature.
  String? read(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (!entry.isUsableAt(_clock(), safetyMargin)) {
      _entries.remove(key);
      return null;
    }
    return entry.url;
  }

  void write(String key, ResolvedMediaUrl value) {
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void invalidate(String key) => _entries.remove(key);

  void clear() => _entries.clear();

  int get length => _entries.length;
}
