import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/result.dart';
import '../data/anime_cache_codec.dart';
import '../models/anime_models.dart';
import 'anime_repository.dart';

/// Durable catalog cache stored in Firestore under the current user.
///
/// Sits above the in-memory TTL cache and the remote provider. After a
/// successful fetch it write-throughs the serialized result so a future
/// launch or an outage of the remote source still has catalog data. Reads
/// never block: failures fall back to whatever was cached (even stale),
/// matching how the memory cache serves offline data.
final class FirestoreCachedAnimeRepository implements AnimeRepository {
  FirestoreCachedAnimeRepository({
    required AnimeRepository inner,
    FirebaseFirestore? firestore,
    DateTime Function()? clock,
  }) : _inner = inner,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _clock = clock ?? DateTime.now;

  final AnimeRepository _inner;
  final FirebaseFirestore _firestore;
  final DateTime Function() _clock;

  @override
  Future<Result<AnimePage>> searchAnime(
    String query, {
    int page = 1,
    int limit = 20,
    AnimeSearchFilter? filter,
  }) {
    final resolved = filter ?? AnimeSearchFilter(text: query);
    return _durable(
      'search:${query.trim().toLowerCase()}:$page:$limit:${resolved.genreId}:${resolved.studioId}:${resolved.type?.name}:${resolved.season?.name}:${resolved.year}:${resolved.sort.name}',
      AnimeCacheTtl.search,
      () =>
          _inner.searchAnime(query, page: page, limit: limit, filter: resolved),
      encode: AnimeCacheCodec.pageToMap,
      decode: AnimeCacheCodec.pageFromMap,
    );
  }

  @override
  Future<Result<Anime>> getAnimeDetails(String id) {
    return _durable(
      'details:${id.trim()}',
      AnimeCacheTtl.details,
      () => _inner.getAnimeDetails(id),
      encode: AnimeCacheCodec.animeToMap,
      decode: AnimeCacheCodec.animeFromMap,
    );
  }

  @override
  Future<Result<AnimePage>> getTrending({int page = 1, int limit = 20}) =>
      _durable(
        'trending:$page:$limit',
        AnimeCacheTtl.trending,
        () => _inner.getTrending(page: page, limit: limit),
        encode: AnimeCacheCodec.pageToMap,
        decode: AnimeCacheCodec.pageFromMap,
      );

  @override
  Future<Result<AnimePage>> getPopular({int page = 1, int limit = 20}) =>
      _durable(
        'popular:$page:$limit',
        AnimeCacheTtl.popular,
        () => _inner.getPopular(page: page, limit: limit),
        encode: AnimeCacheCodec.pageToMap,
        decode: AnimeCacheCodec.pageFromMap,
      );

  @override
  Future<Result<AnimePage>> getTop({int page = 1, int limit = 20}) => _durable(
    'top:$page:$limit',
    AnimeCacheTtl.top,
    () => _inner.getTop(page: page, limit: limit),
    encode: AnimeCacheCodec.pageToMap,
    decode: AnimeCacheCodec.pageFromMap,
  );

  @override
  Future<Result<AnimePage>> getAiring({int page = 1, int limit = 20}) =>
      _durable(
        'airing:$page:$limit',
        AnimeCacheTtl.airing,
        () => _inner.getAiring(page: page, limit: limit),
        encode: AnimeCacheCodec.pageToMap,
        decode: AnimeCacheCodec.pageFromMap,
      );

  @override
  Future<Result<AnimePage>> getUpcoming({int page = 1, int limit = 20}) =>
      _durable(
        'upcoming:$page:$limit',
        AnimeCacheTtl.upcoming,
        () => _inner.getUpcoming(page: page, limit: limit),
        encode: AnimeCacheCodec.pageToMap,
        decode: AnimeCacheCodec.pageFromMap,
      );

  @override
  Future<Result<AnimePage>> getThisSeason({int page = 1, int limit = 20}) =>
      _durable(
        'season-now:$page:$limit',
        AnimeCacheTtl.thisSeason,
        () => _inner.getThisSeason(page: page, limit: limit),
        encode: AnimeCacheCodec.pageToMap,
        decode: AnimeCacheCodec.pageFromMap,
      );

  @override
  Future<Result<List<Anime>>> getAnimeSummaries(
    List<String> ids, {
    int chunkSize = 100,
  }) => _durable(
    'summaries:${_summaryKey(ids)}',
    AnimeCacheTtl.summaries,
    () => _inner.getAnimeSummaries(ids, chunkSize: chunkSize),
    encode: AnimeCacheCodec.summariesToMap,
    decode: AnimeCacheCodec.summariesFromMap,
  );

  String _summaryKey(List<String> ids) {
    final sorted = <String>[
      for (final id in ids)
        if (id.trim().isNotEmpty) id.trim(),
    ]..sort();
    return sorted.join('_');
  }

  @override
  Future<Result<List<AnimeCharacter>>> getCharacters(String animeId) =>
      _durable(
        'characters:${animeId.trim()}',
        AnimeCacheTtl.characters,
        () => _inner.getCharacters(animeId),
        encode: AnimeCacheCodec.charactersToMap,
        decode: AnimeCacheCodec.charactersFromMap,
      );

  @override
  Future<Result<AnimeCharacter>> getCharacterDetails(String characterId) =>
      _durable(
        'character:${characterId.trim()}',
        AnimeCacheTtl.characterDetails,
        () => _inner.getCharacterDetails(characterId),
        encode: AnimeCacheCodec.characterToMap,
        decode: AnimeCacheCodec.characterFromMap,
      );

  @override
  Future<Result<List<AnimeGenre>>> getGenres() => _durable(
    'genres',
    AnimeCacheTtl.genres,
    _inner.getGenres,
    encode: AnimeCacheCodec.genresToMap,
    decode: AnimeCacheCodec.genresFromMap,
  );

  @override
  Future<Result<AnimePage>> getByGenre(
    String genreId, {
    int page = 1,
    int limit = 20,
  }) => _durable(
    'genre:${genreId.trim()}:$page:$limit',
    AnimeCacheTtl.genreList,
    () => _inner.getByGenre(genreId, page: page, limit: limit),
    encode: AnimeCacheCodec.pageToMap,
    decode: AnimeCacheCodec.pageFromMap,
  );

  @override
  Future<Result<List<AnimeStudio>>> getStudios({int limit = 25}) => _durable(
    'studios-index:$limit',
    AnimeCacheTtl.studiosIndex,
    () => _inner.getStudios(limit: limit),
    encode: AnimeCacheCodec.studiosToMap,
    decode: AnimeCacheCodec.studiosFromMap,
  );

  @override
  Future<Result<AnimePage>> getByStudio(
    String studioId, {
    int page = 1,
    int limit = 20,
  }) => _durable(
    'studio:${studioId.trim()}:$page:$limit',
    AnimeCacheTtl.studioList,
    () => _inner.getByStudio(studioId, page: page, limit: limit),
    encode: AnimeCacheCodec.pageToMap,
    decode: AnimeCacheCodec.pageFromMap,
  );

  @override
  Future<Result<List<AnimeSeasonYear>>> getAvailableSeasons() => _durable(
    'seasons-index',
    AnimeCacheTtl.seasonsIndex,
    _inner.getAvailableSeasons,
    encode: AnimeCacheCodec.seasonsToMap,
    decode: AnimeCacheCodec.seasonsFromMap,
  );

  @override
  Future<Result<AnimePage>> getBySeason({
    required int year,
    required AnimeSeason season,
    int page = 1,
    int limit = 20,
  }) => _durable(
    'season:$year:${season.name}:$page:$limit',
    AnimeCacheTtl.seasonList,
    () => _inner.getBySeason(
      year: year,
      season: season,
      page: page,
      limit: limit,
    ),
    encode: AnimeCacheCodec.pageToMap,
    decode: AnimeCacheCodec.pageFromMap,
  );

  Future<Result<T>> _durable<T>(
    String key,
    Duration ttl,
    Future<Result<T>> Function() load, {
    required Map<String, dynamic> Function(T) encode,
    required T Function(Map<String, dynamic>) decode,
  }) async {
    final result = await load();
    if (result is Success<T> && !_alreadyCached(result.value)) {
      unawaited(_write(key, encode(result.value), ttl));
      return result;
    }
    if (result is Success<T>) return result;
    final cached = await _read(key);
    if (cached != null) {
      return Success<T>(decode(cached));
    }
    return result;
  }

  bool _alreadyCached(Object? value) {
    if (value is AnimePage) return value.fromCache;
    if (value is Anime) return value.fromCache;
    return false;
  }

  Future<void> _write(
    String key,
    Map<String, dynamic> payload,
    Duration ttl,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('anime_cache')
          .doc(_keyOf(key))
          .set(<String, dynamic>{
            'payload': payload,
            'savedAt': FieldValue.serverTimestamp(),
            'expiresAt': _clock().add(ttl),
          });
    } on Object {
      // The durable tier is best-effort: never fail the caller.
    }
  }

  Future<Map<String, dynamic>?> _read(String key) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('anime_cache')
          .doc(_keyOf(key))
          .get();
      final data = snap.data();
      if (data == null) return null;
      final payload = data['payload'];
      if (payload is! Map) return null;
      return Map<String, dynamic>.from(payload);
    } on Object {
      return null;
    }
  }

  static String _keyOf(String key) {
    return base64Url.encode(utf8.encode(key)).replaceAll('=', '');
  }
}
