import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/home/models/home_models.dart';
import 'package:pubget/features/home/providers/home_provider.dart';
import 'package:pubget/features/home/repositories/home_repository.dart';
import 'package:pubget/features/social/models/public_profile.dart';

/// Covers the ranked Home sections (anime of the week, popular characters,
/// rising creators, friends' activity, freshest content).
///
/// The behaviour these tests exist to protect is honesty: a section with no
/// real signal must read as empty, a failure must not be reported as content,
/// and content the user can already act on must survive a failed refresh.
void main() {
  DiscoveryItem item(String id, {String type = 'anime', String? reason}) =>
      DiscoveryItem(id: id, type: type, targetId: id, reason: reason);

  test('every ranked section loads from a single callable response', () async {
    final repository = _RankedSectionsRepository(
      pages: <String, DiscoverySectionPage>{
        HomeSectionKeys.animeOfTheWeek: DiscoverySectionPage(
          items: <DiscoveryItem>[item('anime-1')],
        ),
        HomeSectionKeys.popularCharacters: DiscoverySectionPage(
          items: <DiscoveryItem>[
            item('char-1', type: 'character', reason: 'community'),
          ],
        ),
        HomeSectionKeys.risingCreators: DiscoverySectionPage(
          items: <DiscoveryItem>[
            item('creator-1', type: 'creator', reason: 'rising'),
          ],
        ),
      },
    );
    final provider = HomeProvider(repository: repository);
    addTearDown(provider.dispose);

    await _loadAndSettle(provider, repository);

    expect(repository.getHomeSectionsCalls, 1);
    expect(
      provider.section(HomeSectionKind.animeOfTheWeek).state,
      LoadingState.loaded,
    );
    expect(
      provider.section(HomeSectionKind.animeOfTheWeek).items.single.id,
      'anime-1',
    );
    expect(
      provider.section(HomeSectionKind.popularCharacters).items.single.reason,
      'community',
    );
    expect(
      provider.section(HomeSectionKind.risingCreators).items.single.id,
      'creator-1',
    );
  });

  test('a section the server returned nothing for reads as empty, not error', () async {
    final repository = _RankedSectionsRepository();
    final provider = HomeProvider(repository: repository);
    addTearDown(provider.dispose);

    await _loadAndSettle(provider, repository);

    for (final kind in <HomeSectionKind>[
      HomeSectionKind.animeOfTheWeek,
      HomeSectionKind.popularCharacters,
      HomeSectionKind.risingCreators,
      HomeSectionKind.friendsActivity,
      HomeSectionKind.freshestContent,
    ]) {
      final state = provider.section(kind);
      expect(state.state, LoadingState.empty, reason: kind.name);
      expect(state.items, isEmpty, reason: kind.name);
      expect(state.failure, isNull, reason: kind.name);
    }
  });

  test('a failed load reports an error without inventing content', () async {
    final repository = _RankedSectionsRepository(fail: true);
    final provider = HomeProvider(repository: repository);
    addTearDown(provider.dispose);

    await _loadAndSettle(provider, repository);

    final state = provider.section(HomeSectionKind.animeOfTheWeek);
    expect(state.state, LoadingState.error);
    expect(state.items, isEmpty);
    expect(state.failure, isNotNull);
  });

  test('a failed refresh keeps content that was already loaded', () async {
    final repository = _RankedSectionsRepository(
      pages: <String, DiscoverySectionPage>{
        HomeSectionKeys.animeOfTheWeek: DiscoverySectionPage(
          items: <DiscoveryItem>[item('anime-1')],
        ),
      },
    );
    final provider = HomeProvider(repository: repository);
    addTearDown(provider.dispose);

    await _loadAndSettle(provider, repository);
    expect(
      provider.section(HomeSectionKind.animeOfTheWeek).items.single.id,
      'anime-1',
    );

    repository.fail = true;
    await provider.refresh();

    final state = provider.section(HomeSectionKind.animeOfTheWeek);
    expect(state.state, LoadingState.offline);
    expect(
      state.items.single.id,
      'anime-1',
      reason: 'a refresh failure must not blank content the user can see',
    );
  });

  test('ranked sections request the shared page size', () async {
    final repository = _RankedSectionsRepository();
    final provider = HomeProvider(repository: repository);
    addTearDown(provider.dispose);

    await _loadAndSettle(provider, repository);

    expect(repository.lastLimit, 8);
    expect(
      repository.lastSection,
      isNull,
      reason: 'one call serves every ranked section',
    );
  });

  test('a refresh reloads the ranked sections together', () async {
    final repository = _RankedSectionsRepository(
      pages: <String, DiscoverySectionPage>{
        HomeSectionKeys.animeOfTheWeek: DiscoverySectionPage(
          items: <DiscoveryItem>[item('anime-1')],
        ),
      },
    );
    final provider = HomeProvider(repository: repository);
    addTearDown(provider.dispose);

    await _loadAndSettle(provider, repository);
    final afterLoad = repository.getHomeSectionsCalls;

    await provider.refresh();

    expect(
      repository.getHomeSectionsCalls,
      greaterThan(afterLoad),
      reason: 'a pull to refresh must reload the ranked sections too',
    );
  });

  test('a refresh keeps loaded rows visible while it reloads', () async {
    final repository = _RankedSectionsRepository(
      pages: <String, DiscoverySectionPage>{
        HomeSectionKeys.animeOfTheWeek: DiscoverySectionPage(
          items: <DiscoveryItem>[item('anime-1')],
        ),
      },
    );
    final provider = HomeProvider(repository: repository);
    addTearDown(provider.dispose);

    await _loadAndSettle(provider, repository);

    final refreshing = provider.refresh();
    final state = provider.section(HomeSectionKind.animeOfTheWeek);
    expect(state.state, LoadingState.refreshing);
    expect(
      state.items.single.id,
      'anime-1',
      reason: 'a refresh must not blank rows the user is already reading',
    );

    await refreshing;
    expect(
      provider.section(HomeSectionKind.animeOfTheWeek).state,
      LoadingState.loaded,
    );
  });

  test('every visit draws a new section rotation seed', () async {
    final provider = HomeProvider(repository: _RankedSectionsRepository());
    addTearDown(provider.dispose);

    final first = provider.rotationSeed;
    provider.load('alice');
    expect(provider.rotationSeed, isNot(first));

    final second = provider.rotationSeed;
    provider.load('alice');
    expect(provider.rotationSeed, isNot(second));
  });
}

/// Loads Home and waits for the ranked-sections call the provider fires on its
/// own, so tests observe the real load path rather than a second retry.
Future<void> _loadAndSettle(
  HomeProvider provider,
  _RankedSectionsRepository repository,
) async {
  provider.load('alice');
  await repository.firstCall.future;
  // Let the provider apply the result and notify.
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _RankedSectionsRepository implements HomeRepository {
  _RankedSectionsRepository({
    this.pages = const <String, DiscoverySectionPage>{},
    this.fail = false,
  });

  final Map<String, DiscoverySectionPage> pages;
  bool fail;

  int getHomeSectionsCalls = 0;
  int? lastLimit;
  String? lastSection;

  /// Completes once the first ranked-sections call has been answered, so a test
  /// can await the load that [HomeProvider.load] starts fire-and-forget.
  final Completer<void> firstCall = Completer<void>();

  @override
  Future<Result<Map<String, DiscoverySectionPage>>> getHomeSections({
    String? section,
    int limit = 8,
  }) async {
    getHomeSectionsCalls += 1;
    lastLimit = limit;
    lastSection = section;
    if (!firstCall.isCompleted) firstCall.complete();
    if (fail) return const FailureResult(NetworkError());
    return Success(pages);
  }

  @override
  Future<Result<DiscoveryFeed>> getDiscoveryFeed({
    String? section,
    String? cursor,
    int limit = 8,
  }) async => const Success(DiscoveryFeed());

  @override
  Future<Result<List<Group>>> getPromotedGroups({
    int limit = 10,
    Group? after,
  }) async => const Success(<Group>[]);

  @override
  Future<Result<List<Group>>> getRisingGroups({
    int limit = 10,
    Group? after,
  }) async => const Success(<Group>[]);

  @override
  Future<Result<List<Group>>> getRecommendedGroups({
    int limit = 10,
    Group? after,
  }) async => const Success(<Group>[]);

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
  Future<Result<DiscoverySearchResults>> search(String query) async =>
      const Success(DiscoverySearchResults());
}