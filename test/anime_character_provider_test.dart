import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/anime/models/anime_list_models.dart';
import 'package:pubget/features/anime/models/anime_rating_models.dart';
import 'package:pubget/features/anime/providers/anime_character_provider.dart';
import 'package:pubget/features/anime/repositories/anime_hub_social_repository.dart';

import 'anime_test_support.dart';

void main() {
  test('character provider loads profile, stats, and community rank', () async {
    final social = _FakeCharacterSocialRepository();
    final provider = AnimeCharacterProvider(
      repository: FakeAnimeRepository(),
      social: social,
    );
    addTearDown(provider.dispose);

    await provider.load('2816');
    expect(provider.state, LoadingState.loaded);
    expect(provider.character?.name, 'Frieren');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(provider.stats?.favoritesCount, 420);
    expect(provider.rank, 2);

    await provider.load('2816', refresh: true);
    expect(provider.state, LoadingState.loaded);
  });

  test('empty id becomes empty state', () async {
    final provider = AnimeCharacterProvider(repository: FakeAnimeRepository());
    addTearDown(provider.dispose);

    await provider.load('   ');
    expect(provider.state, LoadingState.empty);
    expect(provider.character, isNull);
  });

  test('not-found profile becomes empty state', () async {
    final repository = FakeAnimeRepository()
      ..characterDetailsFailure = const NotFoundError('missing');
    final provider = AnimeCharacterProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.load('999');
    expect(provider.state, LoadingState.empty);
    expect(provider.failure, isA<NotFoundError>());
  });

  test('network failure surfaces error and retry recovers', () async {
    final repository = FakeAnimeRepository()
      ..characterDetailsFailure = const NetworkError('offline');
    final provider = AnimeCharacterProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.load('2816');
    expect(provider.state, LoadingState.offline);

    repository.characterDetailsFailure = null;
    await provider.retry();
    expect(provider.state, LoadingState.loaded);
    expect(provider.character?.name, 'Frieren');
  });
}

final class _FakeCharacterSocialRepository implements AnimeHubSocialRepository {
  @override
  Future<Result<CharacterCommunityStats?>> getCharacterStats(
    String characterId,
  ) async => Success(
    CharacterCommunityStats(
      characterId: characterId,
      name: 'Frieren',
      favoritesCount: 420,
    ),
  );

  @override
  Future<Result<List<CharacterCommunityStats>>> listPopularCharacters({
    int limit = 40,
  }) async => const Success(<CharacterCommunityStats>[
    CharacterCommunityStats(
      characterId: 'erwin',
      name: 'Erwin Smith',
      favoritesCount: 900,
    ),
    CharacterCommunityStats(
      characterId: '2816',
      name: 'Frieren',
      favoritesCount: 420,
    ),
  ]);

  @override
  Future<Result<List<AnimeCustomList>>> listUserCustomAnimeLists(
    String userId,
  ) async => const Success(<AnimeCustomList>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
