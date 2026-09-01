import '../../../core/caching/ttl_cache.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../data/anime_http_client.dart';
import '../models/anime_models.dart';
import 'anime_repository.dart';

final class CachedAnimeRepository implements AnimeRepository {
  CachedAnimeRepository({
    required AnimeRepository inner,
    TtlCache? cache,
    DateTime Function()? clock,
    bool Function()? isOnline,
  }) : _inner = inner,
       _cache = cache ?? MemoryTtlCache(clock: clock),
       _clock = clock ?? DateTime.now,
       _isOnline = isOnline ?? (() => true);

  final AnimeRepository _inner;
  final TtlCache _cache;
  final DateTime Function() _clock;
  final bool Function() _isOnline;
  final Map<String, Future<dynamic>> _inflight = <String, Future<dynamic>>{};

  @override
  Future<Result<AnimePage>> searchAnime(
    String query, {
    int page = 1,
    int limit = 20,
  }) {
    final trimmed = query.trim().toLowerCase();
    return _cachedPage(
      'search:$trimmed:$page:$limit',
      AnimeCacheTtl.search,
      () => _inner.searchAnime(query, page: page, limit: limit),
    );
  }

  @override
  Future<Result<Anime>> getAnimeDetails(String id) {
    return _cached(
      'details:${id.trim()}',
      AnimeCacheTtl.details,
      () => _inner.getAnimeDetails(id),
      wrapCache: (anime) => anime.copyWith(fromCache: true),
    );
  }

  @override
  Future<Result<AnimePage>> getTrending({int page = 1, int limit = 20}) =>
      _cachedPage(
        'trending:$page:$limit',
        AnimeCacheTtl.trending,
        () => _inner.getTrending(page: page, limit: limit),
      );

  @override
  Future<Result<AnimePage>> getPopular({int page = 1, int limit = 20}) =>
      _cachedPage(
        'popular:$page:$limit',
        AnimeCacheTtl.popular,
        () => _inner.getPopular(page: page, limit: limit),
      );

  @override
  Future<Result<AnimePage>> getTop({int page = 1, int limit = 20}) =>
      _cachedPage(
        'top:$page:$limit',
        AnimeCacheTtl.top,
        () => _inner.getTop(page: page, limit: limit),
      );

  @override
  Future<Result<AnimePage>> getAiring({int page = 1, int limit = 20}) =>
      _cachedPage(
        'airing:$page:$limit',
        AnimeCacheTtl.airing,
        () => _inner.getAiring(page: page, limit: limit),
      );

  @override
  Future<Result<AnimePage>> getUpcoming({int page = 1, int limit = 20}) =>
      _cachedPage(
        'upcoming:$page:$limit',
        AnimeCacheTtl.upcoming,
        () => _inner.getUpcoming(page: page, limit: limit),
      );

  @override
  Future<Result<AnimePage>> getThisSeason({int page = 1, int limit = 20}) =>
      _cachedPage(
        'season-now:$page:$limit',
        AnimeCacheTtl.thisSeason,
        () => _inner.getThisSeason(page: page, limit: limit),
      );

  @override
  Future<Result<List<AnimeCharacter>>> getCharacters(String animeId) {
    return _cached(
      'characters:${animeId.trim()}',
      AnimeCacheTtl.characters,
      () => _inner.getCharacters(animeId),
    );
  }

  @override
  Future<Result<List<AnimeGenre>>> getGenres() {
    return _cached('genres', AnimeCacheTtl.genres, _inner.getGenres);
  }

  @override
  Future<Result<AnimePage>> getByGenre(
    String genreId, {
    int page = 1,
    int limit = 20,
  }) {
    return _cachedPage(
      'genre:${genreId.trim()}:$page:$limit',
      AnimeCacheTtl.genreList,
      () => _inner.getByGenre(genreId, page: page, limit: limit),
    );
  }

  @override
  Future<Result<List<AnimeSeasonYear>>> getAvailableSeasons() {
    return _cached(
      'seasons-index',
      AnimeCacheTtl.seasonsIndex,
      _inner.getAvailableSeasons,
    );
  }

  @override
  Future<Result<AnimePage>> getBySeason({
    required int year,
    required AnimeSeason season,
    int page = 1,
    int limit = 20,
  }) {
    return _cachedPage(
      'season:$year:${season.name}:$page:$limit',
      AnimeCacheTtl.seasonList,
      () => _inner.getBySeason(
        year: year,
        season: season,
        page: page,
        limit: limit,
      ),
    );
  }

  Future<Result<AnimePage>> _cachedPage(
    String key,
    Duration ttl,
    Future<Result<AnimePage>> Function() load,
  ) {
    return _cached<AnimePage>(
      key,
      ttl,
      load,
      wrapCache: (page) => page.copyWith(fromCache: true),
    );
  }

  Future<Result<T>> _cached<T>(
    String key,
    Duration ttl,
    Future<Result<T>> Function() load, {
    T Function(T value)? wrapCache,
  }) async {
    final existing = _cache.read<T>(key);
    final now = _clock();
    if (existing != null && existing.isFresh(now)) {
      final value = wrapCache?.call(existing.value) ?? existing.value;
      return Success<T>(value);
    }
    if (!_isOnline()) {
      if (existing != null) {
        final value = wrapCache?.call(existing.value) ?? existing.value;
        return Success<T>(value);
      }
      return const FailureResult(
        NetworkError(AnimeNetworkMessages.offline),
      );
    }

    final pending = _inflight[key];
    if (pending != null) {
      return await pending as Result<T>;
    }

    final future = load();
    _inflight[key] = future;
    try {
      final result = await future;
      result.fold(
        onSuccess: (value) => _cache.write<T>(key, value, ttl),
        onFailure: (_) {},
      );
      return result;
    } finally {
      _inflight.remove(key);
    }
  }
}
