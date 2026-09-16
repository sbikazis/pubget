import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/events/models/event_models.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/home/models/home_models.dart';
import 'package:pubget/features/home/repositories/home_repository.dart';
import 'package:pubget/features/search/search_provider.dart';
import 'package:pubget/features/social/models/public_profile.dart';

import 'anime_test_support.dart';

void main() {
  test('empty and short queries do not hit repositories', () async {
    final home = FakeDiscoveryRepository();
    final anime = FakeAnimeRepository();
    final search = SearchProvider(
      homeRepository: home,
      animeRepository: anime,
      debounce: Duration.zero,
    );
    addTearDown(search.dispose);

    search.searchChanged('');
    search.searchChanged('a');
    await Future<void>.delayed(Duration.zero);
    expect(home.searchCalls, 0);
    expect(anime.searchCalls, 0);
    expect(search.hits, isEmpty);
  });

  test('valid query loads mapped hits', () async {
    final home = FakeDiscoveryRepository();
    final search = SearchProvider(
      homeRepository: home,
      animeRepository: FakeAnimeRepository(),
      debounce: Duration.zero,
    );
    addTearDown(search.dispose);

    search.searchChanged('frieren');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(search.state, LoadingState.loaded);
    expect(search.hits.map((hit) => hit.id), containsAll(<String>['g-frieren', '52991']));
  });

  test('debounce waits before searching', () async {
    final home = FakeDiscoveryRepository();
    final search = SearchProvider(
      homeRepository: home,
      animeRepository: FakeAnimeRepository(),
      debounce: const Duration(milliseconds: 40),
    );
    addTearDown(search.dispose);

    search.searchChanged('fr');
    search.searchChanged('fri');
    search.searchChanged('frieren');
    expect(home.searchCalls, 0);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(home.searchCalls, 1);
  });

  test('empty results and retry after error', () async {
    final home = FakeDiscoveryRepository()..failure = const NetworkError();
    final search = SearchProvider(
      homeRepository: home,
      animeRepository: FakeAnimeRepository(failure: const NetworkError()),
      debounce: Duration.zero,
    );
    addTearDown(search.dispose);

    search.searchChanged('nana');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(search.state, LoadingState.offline);
    home.failure = null;
    await search.retry();
    expect(search.state, LoadingState.empty);
    expect(search.hits, isEmpty);
  });

  test('duplicate in-flight search is ignored', () async {
    final home = FakeDiscoveryRepository()
      ..delay = const Duration(milliseconds: 40);
    final search = SearchProvider(
      homeRepository: home,
      debounce: Duration.zero,
    );
    addTearDown(search.dispose);

    search.searchChanged('frieren');
    await Future<void>.delayed(Duration.zero);
    search.searchChanged('frieren');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(home.searchCalls, 1);
  });

  test('stale responses do not replace a newer query', () async {
    final home = FakeDiscoveryRepository()
      ..delay = const Duration(milliseconds: 30);
    final search = SearchProvider(
      homeRepository: home,
      debounce: Duration.zero,
    );
    addTearDown(search.dispose);

    search.searchChanged('aa');
    await Future<void>.delayed(Duration.zero);
    search.searchChanged('bb');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(home.queries.last, 'bb');
    expect(search.query.trim(), 'bb');
    expect(search.hits.map((hit) => hit.id), contains('g-bb'));
    expect(search.hits.map((hit) => hit.id), isNot(contains('g-aa')));
  });

  test('Arabic queries are searchable and hidden users are omitted', () async {
    final home = FakeDiscoveryRepository();
    final search = SearchProvider(
      homeRepository: home,
      debounce: Duration.zero,
    );
    addTearDown(search.dispose);
    search.bindHiddenUsers({'blocked-1'});
    search.searchChanged('ناروتو');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(home.queries.single, 'ناروتو');
    expect(search.hits.where((hit) => hit.type.name == 'user'), isEmpty);
  });

  test('account switch clears previous hits', () async {
    final search = SearchProvider(
      homeRepository: FakeDiscoveryRepository(),
      debounce: Duration.zero,
    );
    addTearDown(search.dispose);
    search.bindUser('a');
    search.searchChanged('frieren');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(search.hits, isNotEmpty);
    search.bindUser('b');
    expect(search.hits, isEmpty);
    expect(search.query, isEmpty);
  });
}

final class FakeDiscoveryRepository implements HomeRepository {
  Failure? failure;
  Duration delay = Duration.zero;
  int searchCalls = 0;
  final List<String> queries = <String>[];

  @override
  Future<Result<List<Group>>> getCommunityActivity({
    int limit = 10,
    Group? after,
  }) async => const Success(<Group>[]);

  @override
  Future<Result<List<PublicProfile>>> getRecommendedPeople({
    required String userId,
    int limit = 10,
    PublicProfile? after,
  }) async => const Success(<PublicProfile>[]);

  @override
  Future<Result<List<Group>>> getPromotedGroups({
    int limit = 10,
    Group? after,
  }) async => const Success(<Group>[]);

  @override
  Future<Result<List<Group>>> getRecommendedGroups({
    int limit = 10,
    Group? after,
  }) async => const Success(<Group>[]);

  @override
  Future<Result<List<Group>>> getRisingGroups({
    int limit = 10,
    Group? after,
  }) async => const Success(<Group>[]);

  @override
  Future<Result<DiscoverySearchResults>> search(String query) async {
    searchCalls++;
    queries.add(query);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failure != null) return FailureResult(failure!);
    if (query == 'nana' && failure == null && searchCalls > 0) {
      return const Success(DiscoverySearchResults());
    }
    return Success(
      DiscoverySearchResults(
        groups: <Group>[_group('g-$query', 'Fans $query')],
        people: const <PublicProfile>[
          PublicProfile(uid: 'blocked-1', username: 'hidden'),
        ],
        events: <PubgetEvent>[_event('e1', EventStatus.active)],
      ),
    );
  }

  @override
  Future<Result<DiscoveryFeed>> getDiscoveryFeed({
    String? section,
    String? cursor,
    int limit = 8,
  }) async => const Success(DiscoveryFeed(coldStart: true));
}

Group _group(String id, String name, {bool searchable = true}) => Group(
  id: id,
  name: name,
  description: '',
  type: GroupType.public,
  animeId: null,
  founderId: 'u1',
  membersCount: 1,
  maxMembers: 100,
  joinPolicy: JoinPolicy.open,
  isSearchable: searchable,
  createdAt: DateTime(2026),
  chatBackgroundUrl: null,
  rules: '',
  activityScore: 0,
);

PubgetEvent _event(String id, EventStatus status) => PubgetEvent(
  id: id,
  type: EventType.poll,
  creatorId: 'u1',
  groupId: 'g1',
  title: 'Poll',
  description: '',
  configuration: const EventConfiguration(question: 'Q'),
  status: status,
  startAt: DateTime(2026),
  endAt: DateTime(2026, 2),
  participantsCount: 0,
  responsesCount: 0,
  tally: const EventTally(),
  result: null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
