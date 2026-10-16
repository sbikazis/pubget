import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/anime/data/anime_cache_codec.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/providers/anime_providers.dart';
import 'package:pubget/features/anime/repositories/anime_repository.dart';
import 'package:pubget/features/anime/repositories/firestore_cached_anime_repository.dart';
import 'package:pubget/features/anime/screens/anime_browse_page.dart';

/// A minimal anime fixture. Kept local (rather than importing the shared
/// `anime_test_support.dart`) so this regression suite compiles and runs
/// independently of the broader test-support scaffolding.
Anime _sampleAnime({String id = '52991', String title = 'Frieren'}) => Anime(
  id: id,
  title: title,
  alternativeTitles: const <String>["Frieren: Beyond Journey's End"],
  type: 'TV',
  status: 'Finished Airing',
  score: 9.3,
  year: 2023,
  season: AnimeSeason.fall,
  images: const AnimeImages(thumbnailUrl: 'https://example.test/thumb.jpg'),
  relations: const <AnimeRelated>[],
);

AnimePage _page(List<Anime> items) =>
    AnimePage(items: items, page: 1, hasNextPage: false);

enum _Mode { ok, empty, failure, throws }

/// Stands in for the repository stack behind Latest Updates. The `throws` mode
/// reproduces the field bug: a mapper or cache tier raises instead of returning
/// a [Result]. Before the fix that escaped the provider's `_load`, leaving the
/// skeleton up forever and making every retry a no-op.
class _StubAnimeRepository implements AnimeRepository {
  _StubAnimeRepository({this.mode = _Mode.ok});

  _Mode mode;
  int latestCalls = 0;
  int trendingCalls = 0;
  int detailsCalls = 0;
  int charactersCalls = 0;

  @override
  Future<Result<AnimePage>> getLatest({int page = 1, int limit = 20}) async {
    latestCalls++;
    switch (mode) {
      case _Mode.ok:
        return Success<AnimePage>(_page(<Anime>[_sampleAnime()]));
      case _Mode.empty:
        return Success<AnimePage>(_page(const <Anime>[]));
      case _Mode.failure:
        return FailureResult<AnimePage>(const UnavailableError('down'));
      case _Mode.throws:
        throw const MalformedDataError('boom');
    }
  }

  @override
  Future<Result<AnimePage>> getTrending({int page = 1, int limit = 20}) async {
    trendingCalls++;
    throw const MalformedDataError('boom');
  }

  @override
  Future<Result<Anime>> getAnimeDetails(String id) async {
    detailsCalls++;
    throw const MalformedDataError('boom');
  }

  @override
  Future<Result<List<AnimeCharacter>>> getCharacters(String animeId) async {
    charactersCalls++;
    throw const MalformedDataError('boom');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Widget _wrap(AnimeListProvider list, Widget child) =>
    ChangeNotifierProvider<AnimeListProvider>.value(
      value: list,
      child: MaterialApp(home: child),
    );

void main() {
  group('AnimeListProvider latest updates', () {
    test('successful first request reaches the loaded state', () async {
      final list = AnimeListProvider(
        repository: _StubAnimeRepository(),
        debounce: Duration.zero,
      );
      addTearDown(list.dispose);

      await list.openLatest();

      expect(list.state, LoadingState.loaded);
      expect(list.items, isNotEmpty);
      expect(list.failure, isNull);
    });

    test('an empty first page is a real empty state, not a failure', () async {
      final list = AnimeListProvider(
        repository: _StubAnimeRepository(mode: _Mode.empty),
        debounce: Duration.zero,
      );
      addTearDown(list.dispose);

      await list.openLatest();

      expect(list.state, LoadingState.empty);
      expect(list.items, isEmpty);
      expect(list.failure, isNull);
    });

    test('a failure result reaches a terminal error state', () async {
      final list = AnimeListProvider(
        repository: _StubAnimeRepository(mode: _Mode.failure),
        debounce: Duration.zero,
      );
      addTearDown(list.dispose);

      await list.openLatest();

      expect(list.state, LoadingState.error);
      expect(list.failure, isNotNull);
    });

    test(
      'a thrown exception surfaces as an error, never stuck loading',
      () async {
        final repository = _StubAnimeRepository(mode: _Mode.throws);
        final list = AnimeListProvider(
          repository: repository,
          debounce: Duration.zero,
        );
        addTearDown(list.dispose);

        await list.openLatest();

        expect(list.state, LoadingState.error);
        expect(list.failure, isNotNull);
      },
    );

    test('retry after a thrown exception re-issues the request', () async {
      final repository = _StubAnimeRepository(mode: _Mode.throws);
      final list = AnimeListProvider(
        repository: repository,
        debounce: Duration.zero,
      );
      addTearDown(list.dispose);

      await list.openLatest();
      final before = repository.latestCalls;
      await list.retry();

      expect(repository.latestCalls, greaterThan(before));
      expect(list.state, LoadingState.error);
    });

    test('retry recovers once the repository starts succeeding', () async {
      final repository = _StubAnimeRepository(mode: _Mode.throws);
      final list = AnimeListProvider(
        repository: repository,
        debounce: Duration.zero,
      );
      addTearDown(list.dispose);

      await list.openLatest();
      expect(list.state, LoadingState.error);

      repository.mode = _Mode.ok;
      await list.retry();

      expect(list.state, LoadingState.loaded);
      expect(list.items, isNotEmpty);
    });

    test('a timeout is classified as the offline state, not error', () async {
      final list = AnimeListProvider(
        repository: _TimeoutRepository(),
        debounce: Duration.zero,
      );
      addTearDown(list.dispose);

      await list.openLatest();

      expect(list.state, LoadingState.offline);
    });
  });

  group('AnimeBrowsePage (Latest Updates)', () {
    testWidgets('renders the grid and clears the skeleton on success', (
      tester,
    ) async {
      final list = AnimeListProvider(
        repository: _StubAnimeRepository(),
        debounce: Duration.zero,
      );
      addTearDown(list.dispose);

      await tester.pumpWidget(_wrap(list, const AnimeBrowsePage(latest: true)));
      await tester.pumpAndSettle();

      expect(find.byType(PubgetSkeleton), findsNothing);
      expect(find.text('Frieren'), findsWidgets);
    });

    testWidgets('a throwing repository shows the error state, not a skeleton', (
      tester,
    ) async {
      final list = AnimeListProvider(
        repository: _StubAnimeRepository(mode: _Mode.throws),
        debounce: Duration.zero,
      );
      addTearDown(list.dispose);

      await tester.pumpWidget(_wrap(list, const AnimeBrowsePage(latest: true)));
      await tester.pumpAndSettle();

      // The regression: the skeleton used to stay up forever.
      expect(find.byType(PubgetSkeleton), findsNothing);
      expect(find.byType(PubgetErrorState), findsOneWidget);
    });

    testWidgets('an empty first page shows the empty state', (tester) async {
      final list = AnimeListProvider(
        repository: _StubAnimeRepository(mode: _Mode.empty),
        debounce: Duration.zero,
      );
      addTearDown(list.dispose);

      await tester.pumpWidget(_wrap(list, const AnimeBrowsePage(latest: true)));
      await tester.pumpAndSettle();

      expect(find.byType(PubgetEmptyState), findsOneWidget);
      expect(find.byType(PubgetSkeleton), findsNothing);
    });
  });

  group('sibling providers never hang on a thrown exception', () {
    test('AnimeHubProvider lands on an error state, not loading', () async {
      final hub = AnimeHubProvider(
        repository: _StubAnimeRepository(mode: _Mode.throws),
      );
      addTearDown(hub.dispose);

      await hub.load();

      expect(hub.state, isNot(LoadingState.loading));
      expect(hub.state, LoadingState.error);
      expect(
        AnimeCatalogKind.hubHome.map(hub.section),
        everyElement(
          isA<AnimeSectionSnapshot>().having(
            (s) => s.state,
            'state',
            isNot(LoadingState.loading),
          ),
        ),
      );
    });

    test('AnimeDetailsProvider lands on an error state, not loading', () async {
      final details = AnimeDetailsProvider(
        repository: _StubAnimeRepository(mode: _Mode.throws),
      );
      addTearDown(details.dispose);

      await details.load('52991');

      expect(details.state, LoadingState.error);
    });
  });

  group('durable cache decode guard', () {
    test('a stale payload decodes to null instead of throwing', () {
      // Written under an older schema: item id is an int, not a String.
      final stale = <String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{'id': 5, 'title': 'Frieren'},
        ],
        'page': 1,
        'hasNextPage': false,
      };

      expect(
        tryDecodeDurableCache<AnimePage>(stale, AnimeCacheCodec.pageFromMap),
        isNull,
      );
    });

    test('a valid payload still decodes', () {
      final payload = AnimeCacheCodec.pageToMap(_page(<Anime>[_sampleAnime()]));

      final decoded = tryDecodeDurableCache<AnimePage>(
        payload,
        AnimeCacheCodec.pageFromMap,
      );

      expect(decoded, isNotNull);
      expect(decoded!.items.single.id, '52991');
    });
  });
}

/// Always-times-out repository so the timeout classification can be asserted.
class _TimeoutRepository extends _StubAnimeRepository {
  _TimeoutRepository();

  @override
  Future<Result<AnimePage>> getLatest({int page = 1, int limit = 20}) async {
    latestCalls++;
    throw TimeoutException('timeout');
  }
}
