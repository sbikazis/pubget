import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/models/anime_rating_models.dart';
import 'package:pubget/features/anime/repositories/anime_hub_social_repository.dart';
import 'package:pubget/features/anime/repositories/anime_repository.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/providers/roleplay_provider.dart';
import 'package:pubget/features/groups/repositories/roleplay_repository.dart';

void main() {
  test('animeRoleplay lists the real anime characters minus reserved', () async {
    final provider = RoleplayProvider(
      repository: _FakeRoleplayRepository(
        const RoleplayGroupContext(
          type: GroupType.animeRoleplay,
          animeId: '5',
          reservedKeys: <String>{'hero'},
        ),
      ),
      animeRepository: _FakeAnimeRepository(
        Success(<AnimeCharacter>[
          AnimeCharacter(id: 'hero', name: 'Hero'),
          AnimeCharacter(id: 'rival', name: 'Rival'),
          AnimeCharacter(id: 'mentor', name: 'Mentor'),
        ]),
      ),
    );

    await provider.load('g1');

    expect(provider.state, LoadingState.loaded);
    expect(
      provider.characters.map((item) => item.key),
      <String>['rival', 'mentor'],
    );
    expect(provider.characters.first.name, 'Rival');
  });

  test('openRoleplay lists popular characters minus reserved', () async {
    final provider = RoleplayProvider(
      repository: _FakeRoleplayRepository(
        const RoleplayGroupContext(
          type: GroupType.openRoleplay,
          reservedKeys: <String>{'k2'},
        ),
      ),
      socialRepository: _FakeAnimeHubSocialRepository(
        Success(<CharacterCommunityStats>[
          CharacterCommunityStats(characterId: 'k1', name: 'Alpha'),
          CharacterCommunityStats(characterId: 'k2', name: 'Beta'),
        ]),
      ),
    );

    await provider.load('g1');

    expect(provider.state, LoadingState.loaded);
    expect(
      provider.characters.map((item) => item.key),
      <String>['k1'],
    );
    expect(provider.characters.first.name, 'Alpha');
  });

  test('public groups expose no reserve-able characters', () async {
    final provider = RoleplayProvider(
      repository: _FakeRoleplayRepository(
        const RoleplayGroupContext(
          type: GroupType.public,
          reservedKeys: <String>{},
        ),
      ),
      animeRepository: _FakeAnimeRepository(
        Success(<AnimeCharacter>[AnimeCharacter(id: 'a', name: 'A')]),
      ),
      socialRepository: _FakeAnimeHubSocialRepository(
        Success(<CharacterCommunityStats>[
          CharacterCommunityStats(characterId: 'b', name: 'B'),
        ]),
      ),
    );

    await provider.load('g1');

    expect(provider.state, LoadingState.empty);
    expect(provider.characters, isEmpty);
  });

  test('a failed catalog source surfaces the error state', () async {
    final provider = RoleplayProvider(
      repository: _FakeRoleplayRepository(
        const RoleplayGroupContext(
          type: GroupType.animeRoleplay,
          animeId: '99',
          reservedKeys: <String>{},
        ),
      ),
      animeRepository: _FakeAnimeRepository(
        FailureResult<List<AnimeCharacter>>(NetworkError('catalog down')),
      ),
    );

    await provider.load('g1');

    expect(provider.state, LoadingState.offline);
    expect(provider.failure, isA<NetworkError>());
  });

  test('animeRoleplay without a linked anime yields the empty state', () async {
    final provider = RoleplayProvider(
      repository: _FakeRoleplayRepository(
        const RoleplayGroupContext(
          type: GroupType.animeRoleplay,
          reservedKeys: <String>{},
        ),
      ),
    );

    await provider.load('g1');

    expect(provider.state, LoadingState.empty);
    expect(provider.characters, isEmpty);
  });
}

final class _FakeRoleplayRepository implements RoleplayRepository {
  const _FakeRoleplayRepository(this.context);

  final RoleplayGroupContext context;

  @override
  Future<Result<RoleplayGroupContext>> roleplayContext(String groupId) async =>
      Success(context);

  @override
  Future<Result<void>> reserveCharacter({
    required String groupId,
    required String characterKey,
    required RoleplayCharacter character,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> releaseCharacter({
    required String groupId,
    required String characterKey,
  }) async => const Success<void>(null);
}

final class _FakeAnimeRepository implements AnimeRepository {
  const _FakeAnimeRepository(this.characters);

  final Result<List<AnimeCharacter>> characters;

  @override
  Future<Result<List<AnimeCharacter>>> getCharacters(String animeId) async =>
      characters;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeAnimeHubSocialRepository implements AnimeHubSocialRepository {
  const _FakeAnimeHubSocialRepository(this.popular);

  final Result<List<CharacterCommunityStats>> popular;

  @override
  Future<Result<List<CharacterCommunityStats>>> listPopularCharacters({
    int limit = 40,
  }) async => popular;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}