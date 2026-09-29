import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/groups/models/group_catalog_models.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/providers/roleplay_provider.dart';
import 'package:pubget/features/groups/repositories/group_catalog_repository.dart';
import 'package:pubget/features/groups/repositories/roleplay_repository.dart';

void main() {
  test('animeRoleplay lists the whole work cast minus reserved', () async {
    final provider = RoleplayProvider(
      repository: _FakeRoleplayRepository(
        const RoleplayGroupContext(
          type: GroupType.animeRoleplay,
          animeId: '5',
          reservedKeys: <String>{'hero'},
        ),
      ),
      catalogRepository: _FakeGroupCatalogRepository(
        scoped: <Object>[
          _page(1, <RoleplayCharacter>[
            RoleplayCharacter(key: 'hero', name: 'Hero', avatarUrl: ''),
            RoleplayCharacter(key: 'rival', name: 'Rival', avatarUrl: ''),
          ]),
        ],
      ),
    );

    await provider.load('g1');

    expect(provider.state, LoadingState.loaded);
    expect(
      provider.characters.map((item) => item.key),
      <String>['rival'],
    );
    expect(provider.characters.first.name, 'Rival');
  });

  test('a later season of the same work is part of the roster', () async {
    final provider = RoleplayProvider(
      repository: _FakeRoleplayRepository(
        const RoleplayGroupContext(
          type: GroupType.animeRoleplay,
          animeId: '5',
          reservedKeys: <String>{},
        ),
      ),
      catalogRepository: _FakeGroupCatalogRepository(
        scoped: <Object>[
          _page(
            1,
            <RoleplayCharacter>[
              RoleplayCharacter(key: 'hero', name: 'Hero', avatarUrl: ''),
            ],
            totalPages: 2,
          ),
          _page(
            2,
            <RoleplayCharacter>[
              RoleplayCharacter(
                key: 'newcomer',
                name: 'Newcomer',
                avatarUrl: '',
              ),
            ],
            totalPages: 2,
          ),
        ],
      ),
    );

    await provider.load('g1');

    // The cast of a work is not one season's cast: the tray keeps paging until
    // the catalog says there is no next page.
    expect(
      provider.characters.map((item) => item.key),
      <String>['hero', 'newcomer'],
    );
  });

  test('openRoleplay lists the character catalog, not a social table', () async {
    final provider = RoleplayProvider(
      repository: _FakeRoleplayRepository(
        const RoleplayGroupContext(
          type: GroupType.openRoleplay,
          reservedKeys: <String>{'k2'},
        ),
      ),
      catalogRepository: _FakeGroupCatalogRepository(
        open: <Object>[
          _page(1, <RoleplayCharacter>[
            RoleplayCharacter(key: 'k1', name: 'Alpha', avatarUrl: ''),
            RoleplayCharacter(key: 'k2', name: 'Beta', avatarUrl: ''),
          ]),
        ],
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
      catalogRepository: _FakeGroupCatalogRepository(
        scoped: <Object>[
          _page(1, <RoleplayCharacter>[
            RoleplayCharacter(key: 'a', name: 'A', avatarUrl: ''),
          ]),
        ],
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
      catalogRepository: _FakeGroupCatalogRepository(
        scoped: <Object>[const FailureResult<GroupCharacterPage>(NetworkError())],
      ),
    );

    await provider.load('g1');

    expect(provider.state, LoadingState.offline);
    expect(provider.failure, isA<NetworkError>());
  });

  test('a failed tail page keeps the roster that already arrived', () async {
    final provider = RoleplayProvider(
      repository: _FakeRoleplayRepository(
        const RoleplayGroupContext(
          type: GroupType.animeRoleplay,
          animeId: '5',
          reservedKeys: <String>{},
        ),
      ),
      catalogRepository: _FakeGroupCatalogRepository(
        scoped: <Object>[
          _page(
            1,
            <RoleplayCharacter>[
              RoleplayCharacter(key: 'hero', name: 'Hero', avatarUrl: ''),
            ],
            totalPages: 2,
          ),
          const FailureResult<GroupCharacterPage>(NetworkError()),
        ],
      ),
    );

    await provider.load('g1');

    expect(provider.state, LoadingState.loaded);
    expect(
      provider.characters.map((item) => item.key),
      <String>['hero'],
    );
  });

  test('animeRoleplay without a linked anime yields the empty state', () async {
    final provider = RoleplayProvider(
      repository: _FakeRoleplayRepository(
        const RoleplayGroupContext(
          type: GroupType.animeRoleplay,
          reservedKeys: <String>{},
        ),
      ),
      catalogRepository: const UnavailableGroupCatalogRepository(),
    );

    await provider.load('g1');

    expect(provider.state, LoadingState.empty);
    expect(provider.characters, isEmpty);
  });
}

/// A page of the catalog. The caller says how many pages the catalog holds, so
/// the last page reports that there is nothing after it.
GroupCharacterPage _page(
  int page,
  List<RoleplayCharacter> items, {
  int totalPages = 1,
}) => GroupCharacterPage(
  items: items,
  page: page,
  hasNextPage: page < totalPages,
);

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

/// Serves one scope per page, so a test can say what page 1 and page 2 of the
/// catalog answered without touching a network.
final class _FakeGroupCatalogRepository implements GroupCatalogRepository {
  _FakeGroupCatalogRepository({
    this.scoped = const <Object>[],
    this.open = const <Object>[],
  });

  /// Answers for a group bound to an anime.
  final List<Object> scoped;

  /// Answers for a group that is not bound to one anime.
  final List<Object> open;

  final List<GroupCharacterRequest> requests = <GroupCharacterRequest>[];

  @override
  Future<Result<GroupCharacterPage>> browseCharacters(
    GroupCharacterRequest request, {
    int page = 1,
  }) async {
    requests.add(request);
    final source = request.open ? open : scoped;
    if (page < 1 || page > source.length) {
      return const FailureResult<GroupCharacterPage>(NetworkError());
    }
    final answer = source[page - 1];
    if (answer case FailureResult<GroupCharacterPage> failure) {
      return failure;
    }
    if (answer is GroupCharacterPage) return Success(answer);
    return const FailureResult<GroupCharacterPage>(NetworkError());
  }

  @override
  Future<Result<GroupCatalogPage>> browseAnime(
    GroupCatalogRequest request, {
    int page = 1,
  }) async => const FailureResult<GroupCatalogPage>(NetworkError());
}
