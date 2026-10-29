import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/events/models/event_models.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/home/models/home_models.dart';
import 'package:pubget/features/home/repositories/home_repository.dart';
import 'package:pubget/features/reels/models/audio_models.dart';
import 'package:pubget/features/reels/repositories/audio_repository.dart';
import 'package:pubget/features/search/search_hit.dart';
import 'package:pubget/features/search/search_history.dart';
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
    expect(
      search.hits.map((hit) => hit.id),
      containsAll(<String>['g-frieren', '52991']),
    );
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

  test('an entity filter narrows the list without refetching', () async {
    final home = FakeDiscoveryRepository();
    final search = SearchProvider(
      homeRepository: home,
      animeRepository: FakeAnimeRepository(),
      debounce: Duration.zero,
    );
    addTearDown(search.dispose);

    search.searchChanged('frieren');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(search.availableFilters, contains(SearchHitType.group));
    final callsBefore = home.searchCalls;
    final all = search.hits.length;

    search.setFilter(SearchHitType.group);
    expect(search.hits, isNotEmpty);
    expect(search.hits.every((hit) => hit.type == SearchHitType.group), isTrue);
    // Filtering is a view concern: it must not cost another round-trip.
    expect(home.searchCalls, callsBefore);

    search.setFilter(null);
    expect(search.hits.length, all);
  });

  test('a hashtag query offers the tag feed as its first hit', () async {
    final search = SearchProvider(
      homeRepository: FakeDiscoveryRepository(),
      debounce: Duration.zero,
    );
    addTearDown(search.dispose);

    search.searchChanged('#OnePiece');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(search.hits.first.type, SearchHitType.hashtag);
    expect(search.hits.first.route, '/hashtag?tag=onepiece');
    expect(search.availableFilters, contains(SearchHitType.hashtag));
  });

  test(
    'ready audio is searchable; audio still extracting is not offered',
    () async {
      final audio = FakeAudioRepository(
        audios: <ReelAudio>[
          _audio('a1', 'Epic Theme', ReelAudioStatus.ready),
          _audio('a2', 'Epic Draft', ReelAudioStatus.extracting),
        ],
      );
      final search = SearchProvider(
        homeRepository: FakeDiscoveryRepository(),
        audioRepository: audio,
        debounce: Duration.zero,
      );
      addTearDown(search.dispose);

      search.searchChanged('epic');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      final audioHits = search.hits
          .where((hit) => hit.type == SearchHitType.audio)
          .toList();
      expect(audioHits.map((hit) => hit.id), <String>['a1']);
      expect(audioHits.single.route, '/audio/a1');
    },
  );

  test('committed searches are recorded, newest first', () async {
    final history = SearchHistory();
    final search = SearchProvider(
      homeRepository: FakeDiscoveryRepository(),
      history: history,
      debounce: Duration.zero,
    );
    addTearDown(search.dispose);

    search.recordQuery('Naruto');
    search.recordQuery('Bleach');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(history.entries, <String>['Bleach', 'Naruto']);
  });
}

final class FakeAudioRepository implements AudioRepository {
  FakeAudioRepository({this.audios = const <ReelAudio>[]});

  final List<ReelAudio> audios;

  @override
  Future<Result<List<ReelAudio>>> searchAudios({
    required String query,
    int limit = 15,
  }) async => Success(audios);

  @override
  Future<Result<String>> extractAudio({
    required String reelId,
    String? audioName,
    int startMs = 0,
    int durationMs = 15000,
  }) => throw UnimplementedError();

  @override
  Future<Result<ReelAudioPage>> listAudios({
    int limit = 20,
    String? afterId,
    String type = 'trending',
  }) => throw UnimplementedError();

  @override
  Future<Result<ReelAudio>> getAudio(String audioId) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> useAudio({
    required String audioId,
    required String reelId,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> removeAudio(String reelId) => throw UnimplementedError();
}

ReelAudio _audio(String id, String name, ReelAudioStatus status) => ReelAudio(
  audioId: id,
  creatorId: 'u1',
  originalReelId: 'r1',
  name: name,
  displayName: name,
  storagePath: 'audio/$id.m4a',
  durationMs: 15000,
  startMs: 0,
  usageCount: 0,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  status: status,
);

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
  Future<Result<Map<String, DiscoverySectionPage>>> getHomeSections({
    String? section,
    int limit = 8,
  }) async => const Success(<String, DiscoverySectionPage>{});

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
