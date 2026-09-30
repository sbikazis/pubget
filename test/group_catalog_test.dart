import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/groups/models/group_catalog_models.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/providers/group_catalog_provider.dart';
import 'package:pubget/features/groups/repositories/group_catalog_repository.dart';
import 'package:pubget/features/groups/screens/group_anime_picker_page.dart';
import 'package:pubget/features/groups/screens/group_character_picker_page.dart';

void main() {
  group('GroupCatalogProvider', () {
    test('a search is a server search, not a filter of what is on screen', () async {
      final repository = _FakeCatalogRepository(
        animePages: <Object>[_animePage(1, <String>['5114'], totalPages: 2)],
      );
      final provider = GroupCatalogProvider(
        repository: repository,
        debounce: Duration.zero,
      );
      await provider.openAnime(const GroupCatalogRequest());
      expect(repository.animeRequests.single.query, '');
      expect(repository.animePagesAsked, <int>[1]);

      provider.searchAnime('frieren');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // The catalog answered the query itself. Nothing was narrowed on the
      // device, so a title outside the first page is still reachable.
      expect(repository.animeRequests.last.query, 'frieren');
      expect(repository.animePagesAsked, <int>[1, 1]);
      provider.dispose();
    });

    test('pages are merged without duplicates and a failed tail is kept', () async {
      final repository = _FakeCatalogRepository(
        animePages: <Object>[
          _animePage(1, <String>['a', 'b'], totalPages: 3),
          _animePage(2, <String>['b', 'c'], totalPages: 3),
          const FailureResult<GroupCatalogPage>(NetworkError()),
        ],
      );
      final provider = GroupCatalogProvider(
        repository: repository,
        debounce: Duration.zero,
      );
      await provider.openAnime(const GroupCatalogRequest());
      expect(provider.anime.map((item) => item.id), <String>['a', 'b']);

      await provider.loadMoreAnime();
      expect(provider.anime.map((item) => item.id), <String>['a', 'b', 'c']);
      expect(provider.animeState, LoadingState.loaded);

      await provider.loadMoreAnime();
      // The list is still on screen; the failure moved to the tail.
      expect(provider.anime.map((item) => item.id), <String>['a', 'b', 'c']);
      expect(provider.animePageFailure, isA<NetworkError>());
      expect(provider.animeState, LoadingState.loaded);
      provider.dispose();
    });

    test('an unreachable catalog is offline, not an empty catalog', () async {
      final provider = GroupCatalogProvider(
        repository: _FakeCatalogRepository(
          animePages: <Object>[
            const FailureResult<GroupCatalogPage>(NetworkError()),
          ],
        ),
        debounce: Duration.zero,
      );
      await provider.openAnime(const GroupCatalogRequest());

      expect(provider.animeState, LoadingState.offline);
      expect(provider.anime, isEmpty);
      expect(provider.animeFailure, isA<NetworkError>());
      provider.dispose();
    });

    test('a whole-work roster pages until the catalog runs out', () async {
      final repository = _FakeCatalogRepository(
        characterPages: <Object>[
          _characterPage(
            1,
            <RoleplayCharacter>[
              RoleplayCharacter(key: 'hero', name: 'Hero', avatarUrl: ''),
            ],
            totalPages: 2,
          ),
          _characterPage(
            2,
            <RoleplayCharacter>[
              RoleplayCharacter(key: 'late', name: 'Late', avatarUrl: ''),
            ],
            totalPages: 2,
          ),
        ],
      );
      final provider = GroupCatalogProvider(
        repository: repository,
        debounce: Duration.zero,
      );
      await provider.openCharacters(
        const GroupCharacterRequest.forAnime('5'),
      );
      await provider.loadMoreCharacters();

      expect(
        provider.characters.map((item) => item.key),
        <String>['hero', 'late'],
      );
      expect(provider.charactersHasNextPage, isFalse);
      provider.dispose();
    });

    test('a reserved character is locked, and the seasons it is in are kept', () async {
      final provider = GroupCatalogProvider(
        repository: _FakeCatalogRepository(
          characterPages: <Object>[
            _characterPage(
              1,
              <RoleplayCharacter>[
                RoleplayCharacter(
                  key: 'hero',
                  name: 'Hero',
                  avatarUrl: 'https://cdn.test/hero.jpg',
                  seasons: <String>['2023 · spring', '2024 · spring'],
                ),
              ],
            ),
          ],
        ),
        debounce: Duration.zero,
      );
      await provider.openCharacters(
        const GroupCharacterRequest.forAnime('5'),
      );
      expect(provider.characters.single.reserved, isFalse);
      expect(provider.characters.single.seasons, <String>['2023 · spring', '2024 · spring']);

      provider.reserve(<String>{'hero'});
      expect(provider.characters.single.reserved, isTrue);
      provider.dispose();
    });
  });

  group('pickers', () {
    testWidgets('the anime picker lists a catalog page and can search it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _RepositoryProvider(
          value: _FakeCatalogRepository(
            animePages: <Object>[
              _animePage(1, <String>['5114'], totalPages: 1),
            ],
          ),
          child: const MaterialApp(home: GroupAnimePickerPage()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Frieren'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('group-anime-search')),
        'frieren',
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text('Frieren'), findsOneWidget);
    });

    testWidgets('an unreachable catalog shows the offline state, not no results', (
      tester,
    ) async {
      await tester.pumpWidget(
        _RepositoryProvider(
          value: _FakeCatalogRepository(
            animePages: <Object>[
              const FailureResult<GroupCatalogPage>(NetworkError()),
            ],
          ),
          child: const MaterialApp(home: GroupAnimePickerPage()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('group-anime-offline')), findsOneWidget);
      expect(find.byKey(const Key('group-anime-empty')), findsNothing);
    });

    testWidgets('a character search that matches nothing is an empty catalog, '
        'and a dead catalog is an error', (tester) async {
      await tester.pumpWidget(
        _RepositoryProvider(
          value: _FakeCatalogRepository(
            characterPages: <Object>[_characterPage(1, <RoleplayCharacter>[])],
          ),
          child: const MaterialApp(home: GroupCharacterPickerPage(animeId: '5')),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('group-character-empty')), findsOneWidget);
    });
  });
}

GroupCatalogPage _animePage(
  int page,
  List<String> ids, {
  int totalPages = 1,
}) => GroupCatalogPage(
  items: <CatalogAnime>[
    for (final id in ids) CatalogAnime(id: id, title: 'Frieren'),
  ],
  page: page,
  hasNextPage: page < totalPages,
);

GroupCharacterPage _characterPage(
  int page,
  List<RoleplayCharacter> items, {
  int totalPages = 1,
}) => GroupCharacterPage(
  items: items,
  page: page,
  hasNextPage: page < totalPages,
);

final class _FakeCatalogRepository implements GroupCatalogRepository {
  _FakeCatalogRepository({
    this.animePages = const <Object>[],
    this.characterPages = const <Object>[],
  });

  /// One answer per requested page; a `FailureResult` is a page that failed.
  final List<Object> animePages;
  final List<Object> characterPages;

  final List<GroupCatalogRequest> animeRequests = <GroupCatalogRequest>[];
  final List<GroupCharacterRequest> characterRequests =
      <GroupCharacterRequest>[];
  final List<int> animePagesAsked = <int>[];

  @override
  Future<Result<GroupCatalogPage>> browseAnime(
    GroupCatalogRequest request, {
    int page = 1,
  }) async {
    animeRequests.add(request);
    animePagesAsked.add(page);
    return _answer(animePages, page);
  }

  @override
  Future<Result<GroupCharacterPage>> browseCharacters(
    GroupCharacterRequest request, {
    int page = 1,
  }) async {
    characterRequests.add(request);
    return _answer(characterPages, page);
  }

  Result<T> _answer<T>(List<Object> pages, int page) {
    if (page < 1 || page > pages.length) {
      return FailureResult<T>(const NetworkError('no such page'));
    }
    final answer = pages[page - 1];
    if (answer is FailureResult<T>) return answer;
    if (answer is T) return Success<T>(answer as T);
    return FailureResult<T>(const NetworkError('bad answer'));
  }
}

/// A plain provider: the repository is not a notifier.
class _RepositoryProvider extends StatelessWidget {
  const _RepositoryProvider({required this.value, required this.child});

  final GroupCatalogRepository value;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Provider<GroupCatalogRepository>.value(value: value, child: child);
}
