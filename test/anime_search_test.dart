import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/anime/providers/anime_providers.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/home/models/home_models.dart';
import 'package:pubget/features/home/repositories/home_repository.dart';
import 'package:pubget/features/search/search_provider.dart';
import 'package:pubget/features/social/models/public_profile.dart';

import 'anime_test_support.dart';

void main() {
  test('debounce waits before searching', () async {
    final repository = FakeAnimeRepository();
    final list = AnimeListProvider(
      repository: repository,
      debounce: const Duration(milliseconds: 40),
    );
    addTearDown(list.dispose);

    list.searchChanged('fr');
    list.searchChanged('fri');
    list.searchChanged('frieren');
    expect(repository.searchCalls, 0);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(repository.searchCalls, 1);
    expect(list.items, isNotEmpty);
  });

  test('empty and short queries do not hit the repository', () async {
    final repository = FakeAnimeRepository();
    final list = AnimeListProvider(
      repository: repository,
      debounce: Duration.zero,
    );
    addTearDown(list.dispose);
    list.searchChanged('');
    list.searchChanged('a');
    await Future<void>.delayed(Duration.zero);
    expect(repository.searchCalls, 0);
  });

  test('valid query loads results', () async {
    final repository = FakeAnimeRepository();
    final list = AnimeListProvider(
      repository: repository,
      debounce: Duration.zero,
    );
    addTearDown(list.dispose);
    list.searchChanged('frieren');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(list.state, LoadingState.loaded);
    expect(list.items.single.title, 'Frieren');
  });

  test('search error and retry', () async {
    final repository = FakeAnimeRepository(failure: const UnavailableError());
    final list = AnimeListProvider(
      repository: repository,
      debounce: Duration.zero,
    );
    addTearDown(list.dispose);
    list.searchChanged('nana');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(list.state, LoadingState.error);
    repository.failure = null;
    await list.retrySearch();
    expect(list.state, LoadingState.loaded);
  });

  test('clearing query resets state', () async {
    final repository = FakeAnimeRepository();
    final list = AnimeListProvider(
      repository: repository,
      debounce: Duration.zero,
    );
    addTearDown(list.dispose);
    list.searchChanged('frieren');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    list.clearSearch();
    expect(list.query, isEmpty);
    expect(list.items, isEmpty);
    expect(list.state, LoadingState.initial);
  });

  test('duplicate in-flight search is ignored', () async {
    final repository = FakeAnimeRepository();
    final list = AnimeListProvider(
      repository: repository,
      debounce: Duration.zero,
    );
    addTearDown(list.dispose);
    list.searchChanged('frieren');
    list.searchChanged('frieren');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(repository.searchCalls, 1);
  });

  test('home discovery search is owned by SearchProvider', () async {
    final search = SearchProvider(
      homeRepository: _FakeHomeRepository(),
      animeRepository: FakeAnimeRepository(),
      debounce: Duration.zero,
    );
    addTearDown(search.dispose);
    search.searchChanged('fri');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(search.results.groups, isNotEmpty);
    expect(search.results.anime, isNotEmpty);
    expect(search.hits, isNotEmpty);
  });
}

final class _FakeHomeRepository implements HomeRepository {
  @override
  Future<Result<List<Group>>> getCommunityActivity({int limit = 10, Group? after}) async =>
      const Success(<Group>[]);

  @override
  Future<Result<List<PublicProfile>>> getRecommendedPeople({
    required String userId,
    int limit = 10,
    PublicProfile? after,
  }) async => const Success(<PublicProfile>[]);

  @override
  Future<Result<List<Group>>> getPromotedGroups({int limit = 10, Group? after}) async =>
      const Success(<Group>[]);

  @override
  Future<Result<List<Group>>> getRecommendedGroups({int limit = 10, Group? after}) async =>
      const Success(<Group>[]);

  @override
  Future<Result<List<Group>>> getRisingGroups({int limit = 10, Group? after}) async =>
      const Success(<Group>[]);

  @override
  Future<Result<DiscoverySearchResults>> search(String query) async => Success(
    DiscoverySearchResults(
      groups: <Group>[
        Group(
          id: 'g1',
          name: 'Frieren fans',
          description: '',
          type: GroupType.public,
          animeId: null,
          founderId: 'u1',
          membersCount: 1,
          maxMembers: 100,
          joinPolicy: JoinPolicy.open,
          isSearchable: true,
          createdAt: DateTime(2026),
          chatBackgroundUrl: null,
          rules: '',
          activityScore: 0,
        ),
      ],
    ),
  );

  @override
  Future<Result<DiscoveryFeed>> getDiscoveryFeed({
    String? section,
    String? cursor,
    int limit = 8,
  }) async => const Success(DiscoveryFeed(coldStart: true));
}
