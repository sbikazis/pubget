/// Swappable in-memory TTL cache used by domains that need request caching.
abstract interface class TtlCache {
  CacheEntry<T>? read<T>(String key);

  void write<T>(String key, T value, Duration ttl);

  void remove(String key);

  void clear();
}

final class CacheEntry<T> {
  const CacheEntry({
    required this.value,
    required this.storedAt,
    required this.ttl,
  });

  final T value;
  final DateTime storedAt;
  final Duration ttl;

  bool isFresh(DateTime now) => now.isBefore(storedAt.add(ttl));
}

final class MemoryTtlCache implements TtlCache {
  MemoryTtlCache({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, CacheEntry<Object?>> _entries =
      <String, CacheEntry<Object?>>{};

  @override
  CacheEntry<T>? read<T>(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (entry.value is! T) {
      _entries.remove(key);
      return null;
    }
    return CacheEntry<T>(
      value: entry.value as T,
      storedAt: entry.storedAt,
      ttl: entry.ttl,
    );
  }

  @override
  void write<T>(String key, T value, Duration ttl) {
    _entries[key] = CacheEntry<Object?>(
      value: value,
      storedAt: _clock(),
      ttl: ttl,
    );
  }

  @override
  void remove(String key) => _entries.remove(key);

  @override
  void clear() => _entries.clear();
}
