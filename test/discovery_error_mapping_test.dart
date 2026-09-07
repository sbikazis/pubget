import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/home/models/home_models.dart';
import 'package:pubget/features/home/providers/home_provider.dart';
import 'package:pubget/features/home/repositories/discovery_errors.dart';
import 'package:pubget/features/home/repositories/home_repository.dart';
import 'package:pubget/features/social/models/public_profile.dart';

void main() {
  test('permission-denied is not a fake entitlement error', () {
    final failure = discoveryFailureFromCode('permission-denied');
    expect(failure, isA<UnknownError>());
    expect(failure.message, isNot(contains('this account')));
    expect(failure.message, 'Discovery could not load.');
  });

  test('unauthenticated discovery asks the user to sign in', () {
    expect(
      discoveryFailureFromCode('unauthenticated'),
      isA<PermissionError>(),
    );
    expect(
      discoveryFailureFromCode('unauthenticated').message,
      contains('Sign in'),
    );
  });

  test('rankedOrFallback uses Firestore data when the callable fails', () async {
    final result = await rankedOrFallback(
      ranked: Future<Result<List<PublicProfile>>>.value(
        const FailureResult(
          PermissionError('Discovery is not available for this account.'),
        ),
      ),
      fallback: () async => const Success(<PublicProfile>[
        PublicProfile(uid: 'noon', username: 'noon'),
      ]),
    );
    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, hasLength(1));
    expect(result.valueOrNull!.single.username, 'noon');
  });

  test('Home loads people when ranking fails but fallback content exists', () async {
    final provider = HomeProvider(repository: _CallableDownFirestoreUpRepository());
    addTearDown(provider.dispose);
    provider.load('alice');
    provider.ensureLoaded(HomeSectionKind.recommendedPeople);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      provider.section(HomeSectionKind.recommendedPeople).state,
      LoadingState.loaded,
    );
    expect(
      provider.section(HomeSectionKind.recommendedPeople).people.single.username,
      'noon',
    );
    expect(
      provider.section(HomeSectionKind.promotedGroups).groups.single.id,
      'promo-1',
    );
  });
}

Group _group(String id) => Group(
  id: id,
  name: 'Live',
  description: '',
  type: GroupType.public,
  animeId: null,
  founderId: 'owner',
  membersCount: 4,
  maxMembers: 100,
  joinPolicy: JoinPolicy.open,
  isSearchable: true,
  createdAt: DateTime(2026),
  chatBackgroundUrl: null,
  rules: '',
  activityScore: 8,
);

/// Same state as production: callable ranking denied, Firestore lists still have content.
final class _CallableDownFirestoreUpRepository implements HomeRepository {
  @override
  Future<Result<List<Group>>> getCommunityActivity({
    int limit = 10,
    Group? after,
  }) async => Success(<Group>[_group('active-1')]);

  @override
  Future<Result<List<PublicProfile>>> getRecommendedPeople({
    required String userId,
    int limit = 10,
    PublicProfile? after,
  }) async => rankedOrFallback(
    ranked: Future<Result<List<PublicProfile>>>.value(
      const FailureResult(UnknownError('Discovery could not load.')),
    ),
    fallback: () async => const Success(<PublicProfile>[
      PublicProfile(uid: 'noon', username: 'noon'),
    ]),
  );

  @override
  Future<Result<List<Group>>> getPromotedGroups({
    int limit = 10,
    Group? after,
  }) async => Success(<Group>[_group('promo-1')]);

  @override
  Future<Result<List<Group>>> getRecommendedGroups({
    int limit = 10,
    Group? after,
  }) async => rankedOrFallback(
    ranked: Future<Result<List<Group>>>.value(
      const FailureResult(UnknownError('Discovery could not load.')),
    ),
    fallback: () async => Success(<Group>[_group('rec-1')]),
  );

  @override
  Future<Result<List<Group>>> getRisingGroups({
    int limit = 10,
    Group? after,
  }) async => Success(<Group>[_group('rising-1')]);

  @override
  Future<Result<DiscoverySearchResults>> search(String query) async =>
      const Success(DiscoverySearchResults());

  @override
  Future<Result<DiscoveryFeed>> getDiscoveryFeed({
    String? section,
    String? cursor,
    int limit = 8,
  }) async => const FailureResult(UnknownError('Discovery could not load.'));
}
