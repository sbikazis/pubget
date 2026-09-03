import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/home/models/home_models.dart';
import 'package:pubget/features/home/providers/home_provider.dart';
import 'package:pubget/features/home/repositories/home_repository.dart';
import 'package:pubget/features/social/models/public_profile.dart';

void main() {
  test('displayOrder surfaces content before empty discovery sections', () async {
    final provider = HomeProvider(repository: _OrderRepository());
    addTearDown(provider.dispose);
    provider.load('u1');
    for (final kind in provider.sectionOrder) {
      provider.ensureLoaded(kind);
    }
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(provider.section(HomeSectionKind.risingGroups).hasContent, isTrue);
    expect(provider.section(HomeSectionKind.promotedGroups).state, LoadingState.empty);
    expect(
      provider.displayOrder.indexOf(HomeSectionKind.risingGroups),
      lessThan(provider.displayOrder.indexOf(HomeSectionKind.promotedGroups)),
    );
    expect(provider.displayOrder.first, HomeSectionKind.risingGroups);
  });
}

final class _OrderRepository implements HomeRepository {
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
  }) async => Success(<Group>[_group('rising')]);

  @override
  Future<Result<DiscoverySearchResults>> search(String query) async =>
      const Success(DiscoverySearchResults());

  @override
  Future<Result<DiscoveryFeed>> getDiscoveryFeed({
    String? section,
    String? cursor,
    int limit = 8,
  }) async => const Success(DiscoveryFeed());
}

Group _group(String id) => Group(
  id: id,
  name: 'Rising',
  description: '',
  type: GroupType.public,
  animeId: null,
  founderId: 'u1',
  membersCount: 3,
  maxMembers: 100,
  joinPolicy: JoinPolicy.open,
  isSearchable: true,
  createdAt: DateTime(2026),
  chatBackgroundUrl: null,
  rules: '',
  activityScore: 12,
);
