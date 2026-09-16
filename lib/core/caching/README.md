# Caching boundary

`TtlCache` is an in-memory, TTL-aware cache. The first consumer is Anime Hub.

- Fresh entries are returned without hitting the remote source.
- Expired entries are ignored when online and may still be served when offline.
- The implementation is swappable (`MemoryTtlCache` today) so a persisted
  cache can be added later without changing domain repositories.
