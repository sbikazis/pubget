import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/core/theme/app_theme.dart';
import 'package:pubget/features/anime/l10n/anime_copy.dart';
import 'package:pubget/features/anime/models/anime_list_models.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/providers/anime_library_provider.dart';
import 'package:pubget/features/anime/providers/anime_my_list_provider.dart';
import 'package:pubget/features/anime/repositories/anime_library_repository.dart';
import 'package:pubget/features/anime/screens/anime_library_page.dart';
import 'package:pubget/features/anime/widgets/anime_hub_widgets.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';

import 'anime_test_support.dart';
import 'authentication_test_support.dart';

void main() {
  test('the five personal states are the only tabs', () {
    expect(AnimeListStatus.tabs, <AnimeListStatus>[
      AnimeListStatus.wantToWatch,
      AnimeListStatus.watching,
      AnimeListStatus.completed,
      AnimeListStatus.watchLater,
      AnimeListStatus.notInterested,
    ]);
  });

  test('legacy wire values still resolve to a personal state', () {
    expect(
      AnimeListStatusCodec.tryParse('plan_to_watch'),
      AnimeListStatus.wantToWatch,
    );
    expect(AnimeListStatusCodec.tryParse('on_hold'), AnimeListStatus.watchLater);
    expect(
      AnimeListStatusCodec.tryParse('dropped'),
      AnimeListStatus.notInterested,
    );
    expect(AnimeListStatusCodec.legacyFavorite('favorites'), isTrue);
  });

  test('the five states have localized labels', () {
    final ar = AnimeCopy.forLocale(const Locale('ar'));
    for (final status in AnimeListStatus.tabs) {
      expect(ar.listStatusLabel(status), isNot(status.wireValue));
    }
    final en = AnimeCopy.forLocale(const Locale('en'));
    expect(en.listStatusLabel(AnimeListStatus.wantToWatch), 'Want to watch');
    expect(en.listStatusLabel(AnimeListStatus.notInterested), 'Not interested');
  });

  test('entries keep the edit time that drives the default sort', () {
    final entry = AnimeListEntry.fromMap(<String, dynamic>{
      'animeId': '1',
      'status': 'want_to_watch',
      'updatedAt': <String, dynamic>{'_seconds': 1700000000},
    });
    expect(entry.updatedAt, DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true));
    final iso = AnimeListEntry.fromMap(<String, dynamic>{
      'animeId': '2',
      'updatedAt': '2026-01-02T03:04:05Z',
    });
    expect(iso.updatedAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
  });

  test('recently updated sorts by edit time, not by id or add time', () async {
    final library = _library(
      entries: <AnimeListEntry>[
        AnimeListEntry(
          animeId: 'a',
          status: AnimeListStatus.wantToWatch,
          title: 'Alpha',
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        AnimeListEntry(
          animeId: 'z',
          status: AnimeListStatus.wantToWatch,
          title: 'Zeta',
          updatedAt: DateTime.utc(2026, 3, 1),
        ),
        AnimeListEntry(
          animeId: 'm',
          status: AnimeListStatus.wantToWatch,
          title: 'Mu',
          updatedAt: DateTime.utc(2026, 2, 1),
        ),
      ],
    );
    await library.load();
    final myList = AnimeMyListProvider(
      repository: FakeAnimeRepository(),
      entries: () => library.entries,
    );
    expect(
      myList.entriesFor(AnimeListStatus.wantToWatch).map((e) => e.title),
      <String>['Zeta', 'Mu', 'Alpha'],
    );
  });

  testWidgets('shows five tabs, and never an episode or watch control', (
    tester,
  ) async {
    final library = _library(
      entries: <AnimeListEntry>[
        AnimeListEntry(
          animeId: '1',
          status: AnimeListStatus.wantToWatch,
          title: 'Frieren',
          rating: 9,
          favorite: true,
        ),
      ],
    );
    await tester.pumpWidget(_harness(library, _myList(library)));
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(5));
    for (final status in AnimeListStatus.tabs) {
      expect(
        find.text(AnimeCopy.forLocale(const Locale('en')).listStatusLabel(status)),
        findsWidgets,
      );
    }
    expect(find.text('Episode'), findsNothing);
    expect(find.text('Episodes'), findsNothing);
    expect(find.text('Watch'), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);
  });

  testWidgets('cards carry the year, the personal state and the rating', (
    tester,
  ) async {
    final library = _library(
      entries: <AnimeListEntry>[
        AnimeListEntry(
          animeId: '1',
          status: AnimeListStatus.wantToWatch,
          title: 'Frieren',
          rating: 9,
        ),
      ],
    );
    final catalog = FakeAnimeRepository()
      ..summaries = <Anime>[sampleAnime(id: '1', year: 2023)];
    await tester.pumpWidget(
      _harness(library, _myList(library, catalog: catalog), catalog: catalog),
    );
    await tester.pumpAndSettle();

    expect(find.text('2023'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('Want to watch'), findsWidgets);
    expect(find.byType(AnimeHubPosterCard), findsOneWidget);
  });

  testWidgets('search narrows the current tab only', (tester) async {
    final library = _library(
      entries: <AnimeListEntry>[
        AnimeListEntry(
          animeId: '1',
          status: AnimeListStatus.wantToWatch,
          title: 'Frieren',
        ),
        AnimeListEntry(
          animeId: '2',
          status: AnimeListStatus.wantToWatch,
          title: 'Berserk',
        ),
        AnimeListEntry(
          animeId: '3',
          status: AnimeListStatus.completed,
          title: 'Frieren: Beyond Journey',
        ),
      ],
    );
    final catalog = FakeAnimeRepository()
      ..summaries = <Anime>[sampleAnime(id: '1', year: 2023)];
    await tester.pumpWidget(
      _harness(library, _myList(library, catalog: catalog), catalog: catalog),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnimeHubPosterCard), findsNWidgets(2));

    await tester.enterText(find.byKey(const Key('anime-my-list-search')), 'frier');
    await tester.pumpAndSettle();
    expect(find.byType(AnimeHubPosterCard), findsOneWidget);
  });

  testWidgets('network view swaps the grid for a list', (tester) async {
    final library = _library(
      entries: <AnimeListEntry>[
        AnimeListEntry(
          animeId: '1',
          status: AnimeListStatus.wantToWatch,
          title: 'Frieren',
        ),
      ],
    );
    await tester.pumpWidget(_harness(library, _myList(library)));
    await tester.pumpAndSettle();
    expect(find.byType(AnimeHubPosterCard), findsOneWidget);

    await tester.tap(find.byKey(const Key('anime-my-list-view-toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(AnimeHubPosterCard), findsNothing);
    expect(find.byType(AnimeHubNetworkTile), findsOneWidget);
  });

  testWidgets('sort sheet reorders the tab', (tester) async {
    final library = _library(
      entries: <AnimeListEntry>[
        AnimeListEntry(
          animeId: '1',
          status: AnimeListStatus.wantToWatch,
          title: 'Alpha',
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        AnimeListEntry(
          animeId: '2',
          status: AnimeListStatus.wantToWatch,
          title: 'Zeta',
          updatedAt: DateTime.utc(2026, 2, 1),
        ),
      ],
    );
    await tester.pumpWidget(_harness(library, _myList(library)));
    await tester.pumpAndSettle();
    expect(find.text('Zeta'), findsOneWidget);

    await tester.tap(find.byKey(const Key('anime-my-list-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('anime-sort-titleAsc')));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('long press changes the personal state', (tester) async {
    final repository = _FakeLibraryRepository(
      initial: <AnimeListEntry>[
        AnimeListEntry(
          animeId: '1',
          status: AnimeListStatus.wantToWatch,
          title: 'Frieren',
        ),
      ],
    );
    final provider = AnimeLibraryProvider(repository: repository)
      ..bindUser('user-1');
    final myList = AnimeMyListProvider(
      repository: FakeAnimeRepository(),
      entries: () => provider.entries,
    );
    await tester.pumpWidget(_harness(provider, myList));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(AnimeHubPosterCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('anime-entry-change-status')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        ValueKey<String>(
          'anime-status-${AnimeListStatus.completed.wireValue}',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.lastStatus, AnimeListStatus.completed);
    expect(provider.byStatus(AnimeListStatus.completed).length, 1);
  });

  testWidgets('long press can remove the title from the list', (tester) async {
    final repository = _FakeLibraryRepository(
      initial: <AnimeListEntry>[
        AnimeListEntry(
          animeId: '1',
          status: AnimeListStatus.wantToWatch,
          title: 'Frieren',
        ),
      ],
    );
    final provider = AnimeLibraryProvider(repository: repository)
      ..bindUser('user-1');
    final myList = AnimeMyListProvider(
      repository: FakeAnimeRepository(),
      entries: () => provider.entries,
    );
    await tester.pumpWidget(_harness(provider, myList));
    await tester.pumpAndSettle();
    expect(find.byType(AnimeHubPosterCard), findsOneWidget);

    await tester.longPress(find.byType(AnimeHubPosterCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('anime-entry-remove')));
    await tester.pumpAndSettle();

    expect(repository.removed, <String>['1']);
    expect(find.byType(AnimeHubPosterCard), findsNothing);
  });

  testWidgets('an empty tab explains itself and filters say when they hide all', (
    tester,
  ) async {
    final repository = _FakeLibraryRepository();
    final library = AnimeLibraryProvider(repository: repository)
      ..bindUser('user-1');
    final myList = AnimeMyListProvider(
      repository: FakeAnimeRepository(),
      entries: () => library.entries,
    );
    await tester.pumpWidget(_harness(library, myList));
    await tester.pumpAndSettle();
    expect(find.text(AnimeStrings.libraryEmpty), findsOneWidget);

    repository.seed(
      AnimeListEntry(
        animeId: '1',
        status: AnimeListStatus.wantToWatch,
        title: 'Frieren',
      ),
    );
    await library.load();
    await tester.pumpAndSettle();
    expect(find.byType(AnimeHubPosterCard), findsOneWidget);

    await tester.tap(
      find.byKey(
        ValueKey<String>(
          'anime-format-${AnimeListFormatFilter.movie.wireValue}',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AnimeStrings.nothingFound), findsOneWidget);
  });

  testWidgets('format chips are offered for every requested format', (
    tester,
  ) async {
    final library = _library(entries: const <AnimeListEntry>[]);
    await tester.pumpWidget(_harness(library, AnimeMyListProvider(
      repository: FakeAnimeRepository(),
      entries: () => library.entries,
    )));
    await tester.pumpAndSettle();
    for (final filter in AnimeListFormatFilter.values) {
      expect(
        find.byKey(ValueKey<String>('anime-format-${filter.wireValue}')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(
        ValueKey<String>('anime-format-${AnimeListFormatFilter.all.wireValue}'),
      ),
      findsOneWidget,
    );
  });
}

AnimeLibraryProvider _library({
  required List<AnimeListEntry> entries,
  _FakeLibraryRepository? repository,
}) => AnimeLibraryProvider(
  repository: repository ?? _FakeLibraryRepository(initial: entries),
)..bindUser('user-1');

AnimeMyListProvider _myList(
  AnimeLibraryProvider library, {
  FakeAnimeRepository? catalog,
}) => AnimeMyListProvider(
  repository: catalog ?? FakeAnimeRepository(),
  entries: () => library.entries,
);

Widget _harness(
  AnimeLibraryProvider library,
  AnimeMyListProvider myList, {
  FakeAnimeRepository? catalog,
}) {
  final auth = AuthProvider(
    repository: FakeAuthRepository(
      user: const AuthUser(id: 'user-1', email: 'fan@example.com'),
    ),
  )..initialize();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NetworkService>.value(
        value: NetworkService(probe: () async => true),
      ),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<AnimeLibraryProvider>.value(value: library),
      ChangeNotifierProvider<AnimeMyListProvider>.value(value: myList),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const AnimeLibraryPage(),
    ),
  );
}

final class _FakeLibraryRepository implements AnimeLibraryRepository {
  _FakeLibraryRepository({List<AnimeListEntry> initial = const <AnimeListEntry>[]}) {
    for (final entry in initial) {
      entries[entry.animeId] = entry;
    }
  }

  final Map<String, AnimeListEntry> entries = <String, AnimeListEntry>{};
  final List<String> removed = <String>[];
  AnimeListStatus? lastStatus;

  void seed(AnimeListEntry entry) => entries[entry.animeId] = entry;

  @override
  Future<Result<AnimeListPage>> getList({
    AnimeListStatus? status,
    String? cursor,
    int limit = 20,
  }) async => Success<AnimeListPage>(
    AnimeListPage(
      items: entries.values
          .where((e) => status == null || e.status == status)
          .toList(growable: false),
    ),
  );

  @override
  Future<Result<AnimeListEntry>> setEntry({
    required String animeId,
    required AnimeListStatus status,
    String title = '',
    int? rating,
    bool? favorite,
  }) async {
    lastStatus = status;
    final entry = AnimeListEntry(
      animeId: animeId,
      status: status,
      title: title,
      rating: rating,
      favorite: favorite ?? false,
      updatedAt: DateTime.utc(2026),
    );
    entries[animeId] = entry;
    return Success<AnimeListEntry>(entry);
  }

  @override
  Future<Result<void>> removeEntry(String animeId) async {
    removed.add(animeId);
    entries.remove(animeId);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<CharacterFavorite>>> getCharacterFavorites() async =>
      const Success<List<CharacterFavorite>>(<CharacterFavorite>[]);

  @override
  Future<Result<CharacterFavorite>> setCharacterFavorite({
    required String characterId,
    required bool favorite,
    String name = '',
    String? imageUrl,
    int? rating,
  }) async => Success<CharacterFavorite>(CharacterFavorite(characterId: characterId));

  @override
  Future<Result<List<AnimeCustomList>>> getCustomLists({String? userId}) async =>
      const Success<List<AnimeCustomList>>(<AnimeCustomList>[]);

  @override
  Future<Result<AnimeCustomListDetail>> getCustomList({
    required String listId,
    String? userId,
  }) async => Success<AnimeCustomListDetail>(
    AnimeCustomListDetail(list: AnimeCustomList(id: listId, name: 'List')),
  );

  @override
  Future<Result<AnimeCustomList>> createCustomList({
    required String name,
    String description = '',
    bool private = false,
    List<String> animeIds = const <String>[],
  }) async => Success<AnimeCustomList>(
    AnimeCustomList(id: 'l1', name: name, description: description),
  );

  @override
  Future<Result<void>> updateCustomList({
    required String listId,
    String? name,
    String? description,
    bool? private,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> deleteCustomList(String listId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> addToCustomList({
    required String listId,
    required String animeId,
    String title = '',
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> removeFromCustomList({
    required String listId,
    required String animeId,
  }) async => const Success<void>(null);

  @override
  Future<Result<List<CustomListMembership>>> getCustomListMembership(
    String animeId,
  ) async => const Success<List<CustomListMembership>>(
    <CustomListMembership>[],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
