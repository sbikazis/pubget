import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/anime_models.dart';
import 'anime_repository.dart';

enum AnimeProviderStatus { primary, secondary }

/// Tries a list of [AnimeRepository] providers in order. A permanent failure
/// (not found, invalid request, permission) is returned immediately; a
/// transient provider failure (timeout, network, rate limit, outage, malformed
/// payload) falls through to the next provider so the hub keeps working when
/// the primary catalog source is down. The active status is exposed through
/// [status] so the UI can hint that the backup provider is serving data.
final class ProviderChainAnimeRepository implements AnimeRepository {
  ProviderChainAnimeRepository({required List<AnimeRepository> providers})
    : assert(providers.isNotEmpty),
      _providers = List<AnimeRepository>.unmodifiable(providers);

  final List<AnimeRepository> _providers;

  final ValueNotifier<AnimeProviderStatus> status = ValueNotifier(
    AnimeProviderStatus.primary,
  );

  Failure? get lastFailure => _lastFailure;
  Failure? _lastFailure;

  void dispose() => status.dispose();

  @override
  Future<Result<AnimePage>> searchAnime(
    String query, {
    int page = 1,
    int limit = 20,
    AnimeSearchFilter? filter,
  }) =>
      _run((provider) => provider.searchAnime(
            query,
            page: page,
            limit: limit,
            filter: filter,
          ));

  @override
  Future<Result<Anime>> getAnimeDetails(String id) =>
      _run((provider) => provider.getAnimeDetails(id));

  @override
  Future<Result<AnimePage>> getTrending({int page = 1, int limit = 20}) =>
      _run((provider) => provider.getTrending(page: page, limit: limit));

  @override
  Future<Result<AnimePage>> getPopular({int page = 1, int limit = 20}) =>
      _run((provider) => provider.getPopular(page: page, limit: limit));

  @override
  Future<Result<AnimePage>> getTop({int page = 1, int limit = 20}) =>
      _run((provider) => provider.getTop(page: page, limit: limit));

  @override
  Future<Result<AnimePage>> getAiring({int page = 1, int limit = 20}) =>
      _run((provider) => provider.getAiring(page: page, limit: limit));

  @override
  Future<Result<AnimePage>> getUpcoming({int page = 1, int limit = 20}) =>
      _run((provider) => provider.getUpcoming(page: page, limit: limit));

  @override
  Future<Result<AnimePage>> getThisSeason({int page = 1, int limit = 20}) =>
      _run((provider) => provider.getThisSeason(page: page, limit: limit));

  @override
  Future<Result<List<AnimeCharacter>>> getCharacters(String animeId) =>
      _run((provider) => provider.getCharacters(animeId));

  @override
  Future<Result<AnimeCharacter>> getCharacterDetails(String characterId) =>
      _run((provider) => provider.getCharacterDetails(characterId));

  @override
  Future<Result<List<AnimeGenre>>> getGenres() =>
      _run((provider) => provider.getGenres());

  @override
  Future<Result<AnimePage>> getByGenre(
    String genreId, {
    int page = 1,
    int limit = 20,
  }) =>
      _run(
        (provider) => provider.getByGenre(genreId, page: page, limit: limit),
      );

  @override
  Future<Result<List<AnimeStudio>>> getStudios({int limit = 25}) =>
      _run((provider) => provider.getStudios(limit: limit));

  @override
  Future<Result<AnimePage>> getByStudio(
    String studioId, {
    int page = 1,
    int limit = 20,
  }) =>
      _run(
        (provider) => provider.getByStudio(studioId, page: page, limit: limit),
      );

  @override
  Future<Result<List<AnimeSeasonYear>>> getAvailableSeasons() =>
      _run((provider) => provider.getAvailableSeasons());

  @override
  Future<Result<AnimePage>> getBySeason({
    required int year,
    required AnimeSeason season,
    int page = 1,
    int limit = 20,
  }) =>
      _run((provider) => provider.getBySeason(
            year: year,
            season: season,
            page: page,
            limit: limit,
          ));

  Future<Result<T>> _run<T>(
    Future<Result<T>> Function(AnimeRepository provider) call,
  ) async {
    Failure? failure;
    Result<T>? lastResult;
    for (var index = 0; index < _providers.length; index++) {
      try {
        final result = await call(_providers[index]);
        if (result is Success<T>) {
          _updateStatus(primary: index == 0, failure: null);
          return result;
        }
        if (result is FailureResult<T>) {
          lastResult = result;
          if (shouldFallbackToBackupProvider(result.failure)) {
            failure = result.failure;
            _lastFailure = failure;
            continue;
          }
          _updateStatus(primary: index == 0, failure: null);
          return result;
        }
        _updateStatus(primary: index == 0, failure: null);
        return result;
      } on Object catch (error) {
        final mapped = error is Failure
            ? error
            : const UnknownError('Unable to load anime right now.');
        failure = mapped;
        lastResult ??= FailureResult<T>(mapped);
      }
    }
    _updateStatus(primary: false, failure: failure);
    return lastResult ??
        FailureResult<T>(
          const UnavailableError(),
        );
  }

  void _updateStatus({required bool primary, required Failure? failure}) {
    if (primary) {
      _lastFailure = null;
    } else if (failure != null) {
      _lastFailure = failure;
    }
    final next = primary
        ? AnimeProviderStatus.primary
        : AnimeProviderStatus.secondary;
    if (status.value != next) status.value = next;
  }
}

/// A transient provider failure (outage, network, rate limit, malformed
/// data) is worth retrying against the backup provider. Permanent client-side
/// failures (not found, invalid request, permission) are returned as-is.
bool shouldFallbackToBackupProvider(Failure failure) {
  return failure is TimeoutError ||
      failure is NetworkError ||
      failure is UnavailableError ||
      failure is RateLimitedError ||
      failure is UnknownError ||
      failure is MalformedDataError;
}