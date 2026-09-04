import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/home/models/home_models.dart';
import 'package:pubget/features/home/providers/home_provider.dart';
import 'package:pubget/features/home/repositories/home_repository.dart';
import 'package:pubget/features/social/models/public_profile.dart';

void main() {
  test('discovery section failure is an error, not an empty success', () async {
    final provider = HomeProvider(repository: _FailingDiscoveryRepository());
    addTearDown(provider.dispose);
    provider.load('alice');
    provider.ensureLoaded(HomeSectionKind.risingGroups);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(provider.section(HomeSectionKind.risingGroups).state, LoadingState.error);
    expect(provider.section(HomeSectionKind.risingGroups).hasContent, isFalse);
    expect(provider.section(HomeSectionKind.risingGroups).failure, isA<NetworkError>());
  });

  test('a failed discovery refresh keeps prior items instead of faking an empty feed', () async {
    final repository = _FlakyDiscoveryRepository();
    final provider = HomeProvider(repository: repository);
    addTearDown(provider.dispose);
    provider.load('alice');
    provider.ensureLoaded(HomeSectionKind.risingGroups);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(provider.section(HomeSectionKind.risingGroups).hasContent, isTrue);
    expect(provider.feed.section('recommendedEdits').items, isNotEmpty);

    repository.fail = true;
    await provider.refresh();
    expect(provider.section(HomeSectionKind.risingGroups).state, LoadingState.offline);
    expect(provider.section(HomeSectionKind.risingGroups).groups.single.id, 'rising-1');
    expect(provider.feed.section('recommendedEdits').items.single.targetId, 'edit-1');
  });
}

Group _group(String id) => Group(
  id: id,
  name: 'Rising',
  description: '',
  type: GroupType.public,
  animeId: null,
  founderId: 'groupowner',
  membersCount: 3,
  maxMembers: 100,
  joinPolicy: JoinPolicy.open,
  isSearchable: true,
  createdAt: DateTime(2026),
  chatBackgroundUrl: null,
  rules: '',
  activityScore: 12,
  risingScore: 40,
);

final class _FailingDiscoveryRepository implements HomeRepository {
  @override
  Future<Result<List<Group>>> getCommunityActivity({
    int limit = 10,
    Group? after,
  }) async => const FailureResult(NetworkError());

  @override
  Future<Result<List<PublicProfile>>> getRecommendedPeople({
    required String userId,
    int limit = 10,
    PublicProfile? after,
  }) async => const FailureResult(NetworkError());

  @override
  Future<Result<List<Group>>> getPromotedGroups({
    int limit = 10,
    Group? after,
  }) async => const FailureResult(NetworkError());

  @override
  Future<Result<List<Group>>> getRecommendedGroups({
    int limit = 10,
    Group? after,
  }) async => const FailureResult(NetworkError());

  @override
  Future<Result<List<Group>>> getRisingGroups({
    int limit = 10,
    Group? after,
  }) async => const FailureResult(NetworkError());

  @override
  Future<Result<DiscoverySearchResults>> search(String query) async =>
      const FailureResult(NetworkError());

  @override
  Future<Result<DiscoveryFeed>> getDiscoveryFeed({
    String? section,
    String? cursor,
    int limit = 8,
  }) async => const FailureResult(NetworkError());
}

final class _FlakyDiscoveryRepository implements HomeRepository {
  bool fail = false;

  Result<T> _result<T>(T value) =>
      fail ? FailureResult<T>(const NetworkError()) : Success<T>(value);

  @override
  Future<Result<List<Group>>> getCommunityActivity({
    int limit = 10,
    Group? after,
  }) async => _result(const <Group>[]);

  @override
  Future<Result<List<PublicProfile>>> getRecommendedPeople({
    required String userId,
    int limit = 10,
    PublicProfile? after,
  }) async => _result(const <PublicProfile>[]);

  @override
  Future<Result<List<Group>>> getPromotedGroups({
    int limit = 10,
    Group? after,
  }) async => _result(const <Group>[]);

  @override
  Future<Result<List<Group>>> getRecommendedGroups({
    int limit = 10,
    Group? after,
  }) async => _result(const <Group>[]);

  @override
  Future<Result<List<Group>>> getRisingGroups({
    int limit = 10,
    Group? after,
  }) async => _result(<Group>[_group('rising-1')]);

  @override
  Future<Result<DiscoverySearchResults>> search(String query) async =>
      _result(const DiscoverySearchResults());

  @override
  Future<Result<DiscoveryFeed>> getDiscoveryFeed({
    String? section,
    String? cursor,
    int limit = 8,
  }) async => _result(
    const DiscoveryFeed(
      sections: <String, DiscoverySectionPage>{
        'recommendedEdits': DiscoverySectionPage(
          items: <DiscoveryItem>[
            DiscoveryItem(id: 'edit:edit-1', type: 'edit', targetId: 'edit-1'),
          ],
        ),
      },
    ),
  );
}
