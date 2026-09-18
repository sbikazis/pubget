import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/repositories/anime_repository.dart';
import 'package:pubget/features/anime/repositories/provider_chain_anime_repository.dart';

import 'anime_test_support.dart';

void main() {
  final page = AnimePage(items: <Anime>[
    Anime(id: '1', title: 'A'),
  ]);

  test('uses the primary provider on success', () async {
    final primary = FakeAnimeRepository(page: page);
    final secondary = FakeAnimeRepository(page: AnimePage.empty);
    final chain = ProviderChainAnimeRepository(
      providers: <AnimeRepository>[primary, secondary],
    );
    final result = await chain.getPopular();
    expect(result, isA<Success<dynamic>>());
    expect(chain.status.value, AnimeProviderStatus.primary);
  });

  test('falls back to the secondary provider on a transient failure',
      () async {
    final primary = FakeAnimeRepository(
      failure: const TimeoutError(),
    );
    final secondary = FakeAnimeRepository(page: page);
    final chain = ProviderChainAnimeRepository(
      providers: <AnimeRepository>[primary, secondary],
    );
    final result = await chain.getTop();
    expect(result, isA<Success<dynamic>>());
    expect((result as Success).value.items.first.id, '1');
    expect(chain.status.value, AnimeProviderStatus.secondary);
    expect(chain.lastFailure, isA<TimeoutError>());
  });

  test('does not contact the secondary provider on a permanent failure',
      () async {
    final primary = FakeAnimeRepository(
      detailsFailure: const NotFoundError(),
    );
    final secondary = FakeAnimeRepository(details: Anime(id: '9', title: 'B'));
    final chain = ProviderChainAnimeRepository(
      providers: <AnimeRepository>[primary, secondary],
    );
    final result = await chain.getAnimeDetails('404-anime');
    expect(result, isA<FailureResult<dynamic>>());
    expect((result as FailureResult).failure, isA<NotFoundError>());
    expect(chain.status.value, AnimeProviderStatus.primary);
  });

  test('recovers to primary once it starts succeeding again', () async {
    var calls = 0;
    final primary = _FlakyRepository(
      () {
        calls += 1;
        return calls == 1
            ? const FailureResult<AnimePage>(UnavailableError())
            : Success(page);
      },
    );
    final secondary = FakeAnimeRepository(
      failure: const UnavailableError(),
    );
    final chain = ProviderChainAnimeRepository(
      providers: <AnimeRepository>[primary, secondary],
    );
    final first = await chain.getPopular();
    expect(first, isA<FailureResult<dynamic>>());
    expect(chain.status.value, AnimeProviderStatus.secondary);
    final second = await chain.getPopular();
    expect(second, isA<Success<dynamic>>());
    expect(chain.status.value, AnimeProviderStatus.primary);
  });
}

final class _FlakyRepository implements AnimeRepository {
  _FlakyRepository(this._handler);

  final Result<AnimePage> Function() _handler;

  @override
  Future<Result<AnimePage>> getPopular({int page = 1, int limit = 20}) =>
      Future.value(_handler());

  @override
  Never _missing() => throw UnimplementedError();

  @override
  Future<Result<AnimePage>> searchAnime(
    String query, {
    int page = 1,
    int limit = 20,
    AnimeSearchFilter? filter,
  }) =>
      _missing();

  @override
  Future<Result<Anime>> getAnimeDetails(String id) => _missing();

  @override
  Future<Result<AnimePage>> getTrending({int page = 1, int limit = 20}) =>
      _missing();

  @override
  Future<Result<AnimePage>> getTop({int page = 1, int limit = 20}) =>
      _missing();

  @override
  Future<Result<AnimePage>> getAiring({int page = 1, int limit = 20}) =>
      _missing();

  @override
  Future<Result<AnimePage>> getUpcoming({int page = 1, int limit = 20}) =>
      _missing();

  @override
  Future<Result<AnimePage>> getThisSeason({int page = 1, int limit = 20}) =>
      _missing();

  @override
  Future<Result<List<AnimeCharacter>>> getCharacters(String animeId) =>
      _missing();

  @override
  Future<Result<AnimeCharacter>> getCharacterDetails(String characterId) =>
      _missing();

  @override
  Future<Result<List<AnimeGenre>>> getGenres() => _missing();

  @override
  Future<Result<AnimePage>> getByGenre(
    String genreId, {
    int page = 1,
    int limit = 20,
  }) =>
      _missing();

  @override
  Future<Result<List<AnimeStudio>>> getStudios({int limit = 25}) => _missing();

  @override
  Future<Result<AnimePage>> getByStudio(
    String studioId, {
    int page = 1,
    int limit = 20,
  }) =>
      _missing();

  @override
  Future<Result<List<AnimeSeasonYear>>> getAvailableSeasons() => _missing();

  @override
  Future<Result<AnimePage>> getBySeason({
    required int year,
    required AnimeSeason season,
    int page = 1,
    int limit = 20,
  }) =>
      _missing();
}