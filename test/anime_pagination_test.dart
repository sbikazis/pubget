import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/providers/anime_providers.dart';

import 'anime_test_support.dart';

void main() {
  test('loads first page then appends the next page', () async {
    final repository = FakeAnimeRepository(
      page: AnimePage(
        items: <Anime>[sampleAnime()],
        page: 1,
        hasNextPage: true,
      ),
    );
    final list = AnimeListProvider(repository: repository, debounce: Duration.zero);
    addTearDown(list.dispose);

    await list.openCatalog(AnimeCatalogKind.top);
    expect(list.items, hasLength(1));
    expect(list.hasNextPage, isTrue);

    await list.loadMore();
    expect(list.items, hasLength(2));
    expect(list.items.map((item) => item.id).toSet(), hasLength(2));
    expect(repository.requestedPages, <int>[1, 2]);
  });

  test('duplicate loadMore does not request the same page twice', () async {
    final repository = FakeAnimeRepository(
      page: const AnimePage(items: <Anime>[], page: 1, hasNextPage: true),
    );
    repository.page = AnimePage(
      items: <Anime>[sampleAnime()],
      page: 1,
      hasNextPage: true,
    );
    final list = AnimeListProvider(repository: repository);
    addTearDown(list.dispose);
    await list.openCatalog(AnimeCatalogKind.popular);
    await Future.wait([list.loadMore(), list.loadMore()]);
    expect(repository.requestedPages.where((page) => page == 2), hasLength(1));
  });

  test('failed next page keeps previous items', () async {
    final repository = FakeAnimeRepository(
      page: AnimePage(
        items: <Anime>[sampleAnime()],
        page: 1,
        hasNextPage: true,
      ),
      nextPageFailure: const NetworkError(),
    );
    final list = AnimeListProvider(repository: repository);
    addTearDown(list.dispose);
    await list.openCatalog(AnimeCatalogKind.airing);
    await list.loadMore();
    expect(list.items, hasLength(1));
    expect(list.pageFailure, isA<NetworkError>());
    expect(list.state, LoadingState.loaded);
  });

  test('retry next page succeeds after a failure', () async {
    final repository = FakeAnimeRepository(
      page: AnimePage(
        items: <Anime>[sampleAnime()],
        page: 1,
        hasNextPage: true,
      ),
      nextPageFailure: const UnavailableError(),
    );
    final list = AnimeListProvider(repository: repository);
    addTearDown(list.dispose);
    await list.openCatalog(AnimeCatalogKind.trending);
    await list.loadMore();
    expect(list.pageFailure, isNotNull);
    repository.nextPageFailure = null;
    await list.retryLoadMore();
    expect(list.items, hasLength(2));
    expect(list.pageFailure, isNull);
  });

  test('empty page becomes empty state', () async {
    final repository = FakeAnimeRepository(
      page: const AnimePage(items: <Anime>[]),
    );
    final list = AnimeListProvider(repository: repository);
    addTearDown(list.dispose);
    await list.openCatalog(AnimeCatalogKind.upcoming);
    expect(list.state, LoadingState.empty);
  });

  test('last page sets hasNextPage false', () async {
    final repository = FakeAnimeRepository(
      page: AnimePage(
        items: <Anime>[sampleAnime()],
        page: 1,
        hasNextPage: false,
      ),
    );
    final list = AnimeListProvider(repository: repository);
    addTearDown(list.dispose);
    await list.openCatalog(AnimeCatalogKind.thisSeason);
    expect(list.hasNextPage, isFalse);
    await list.loadMore();
    expect(repository.requestedPages, <int>[1]);
  });
}
