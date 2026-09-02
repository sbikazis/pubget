import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/caching/ttl_cache.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/features/anime/repositories/cached_anime_repository.dart';

import 'anime_test_support.dart';

void main() {
  test('cache hit does not call the inner repository twice', () async {
    final inner = FakeAnimeRepository();
    var now = DateTime(2026, 1, 1, 12);
    final cache = CachedAnimeRepository(
      inner: inner,
      cache: MemoryTtlCache(clock: () => now),
      clock: () => now,
      isOnline: () => true,
    );

    await cache.getAnimeDetails('52991');
    await cache.getAnimeDetails('52991');
    expect(inner.detailsCalls, 1);
  });

  test('expired cache is refetched when online', () async {
    final inner = FakeAnimeRepository();
    var now = DateTime(2026, 1, 1, 12);
    final store = MemoryTtlCache(clock: () => now);
    final cache = CachedAnimeRepository(
      inner: inner,
      cache: store,
      clock: () => now,
      isOnline: () => true,
    );
    await cache.getTrending();
    now = now.add(const Duration(hours: 2));
    await cache.getTrending();
    expect(inner.trendingCalls, 2);
  });

  test('offline with cache returns cached data', () async {
    final inner = FakeAnimeRepository();
    var online = true;
    final cache = CachedAnimeRepository(
      inner: inner,
      isOnline: () => online,
    );
    await cache.getPopular();
    online = false;
    inner.failure = const NetworkError();
    final result = await cache.getPopular();
    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull!.fromCache, isTrue);
  });

  test('offline without cache returns a network failure', () async {
    final inner = FakeAnimeRepository();
    final cache = CachedAnimeRepository(
      inner: inner,
      isOnline: () => false,
    );
    final result = await cache.searchAnime('frieren');
    expect(result.failureOrNull, isA<NetworkError>());
    expect(inner.searchCalls, 0);
  });

  test('in-flight duplicate details requests share one call', () async {
    final inner = FakeAnimeRepository();
    final cache = CachedAnimeRepository(inner: inner);
    await Future.wait([
      cache.getAnimeDetails('52991'),
      cache.getAnimeDetails('52991'),
    ]);
    expect(inner.detailsCalls, 1);
  });
}
