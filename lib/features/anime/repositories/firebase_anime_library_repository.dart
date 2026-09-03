import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/anime_list_models.dart';
import 'anime_library_repository.dart';

final class FirebaseAnimeLibraryRepository implements AnimeLibraryRepository {
  FirebaseAnimeLibraryRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  @override
  Future<Result<AnimeListPage>> getList({
    AnimeListStatus? status,
    String? cursor,
    int limit = 20,
  }) => _guard(() async {
    final result = await _functions.httpsCallable('getAnimeList').call(
      <String, dynamic>{
        if (status != null) 'status': status.wireValue,
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    return AnimeListPage.fromMap(Map<String, dynamic>.from(result.data as Map));
  });

  @override
  Future<Result<AnimeListEntry>> setEntry({
    required String animeId,
    required AnimeListStatus status,
    String title = '',
    int? rating,
  }) => _guard(() async {
    final result = await _functions.httpsCallable('setAnimeListEntry').call(
      <String, dynamic>{
        'animeId': animeId,
        'status': status.wireValue,
        'title': title,
        if (rating != null) 'rating': rating,
      },
    );
    final data = Map<String, dynamic>.from(result.data as Map);
    return AnimeListEntry(
      animeId: data['animeId'] as String? ?? animeId,
      status:
          AnimeListStatusCodec.tryParse(data['status'] as String?) ?? status,
      title: title,
      rating: (data['rating'] as num?)?.toInt() ?? rating,
    );
  });

  @override
  Future<Result<void>> removeEntry(String animeId) => _guard(() async {
    await _functions.httpsCallable('removeAnimeListEntry').call(
      <String, dynamic>{'animeId': animeId},
    );
  });

  @override
  Future<Result<List<CharacterFavorite>>> getCharacterFavorites() =>
      _guard(() async {
        final result = await _functions
            .httpsCallable('getCharacterFavorites')
            .call();
        final data = Map<String, dynamic>.from(result.data as Map);
        final raw = data['items'] as List<Object?>? ?? const <Object?>[];
        return raw
            .whereType<Map>()
            .map(
              (item) =>
                  CharacterFavorite.fromMap(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false);
      });

  @override
  Future<Result<CharacterFavorite>> setCharacterFavorite({
    required String characterId,
    required bool favorite,
    String name = '',
    int? rating,
  }) => _guard(() async {
    final result = await _functions.httpsCallable('setCharacterFavorite').call(
      <String, dynamic>{
        'characterId': characterId,
        'favorite': favorite,
        'name': name,
        if (rating != null) 'rating': rating,
      },
    );
    final data = Map<String, dynamic>.from(result.data as Map);
    return CharacterFavorite(
      characterId: data['characterId'] as String? ?? characterId,
      name: name,
      rating: (data['rating'] as num?)?.toInt() ?? rating,
    );
  });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on Object catch (error) {
      return FailureResult(_fail(error));
    }
  }
}

Failure _fail(Object error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' || 'permission-denied' => PermissionError(
        error.message ?? 'Anime lists require a signed-in account.',
      ),
      'unavailable' || 'deadline-exceeded' => const NetworkError(
        'Check your connection and try again.',
      ),
      'invalid-argument' => ValidationError(
        error.message ?? 'That list update is not valid.',
      ),
      _ => UnknownError(error.message ?? 'Anime list update failed.'),
    };
  }
  return const UnknownError('Anime list update failed.');
}
