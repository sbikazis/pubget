import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/core/theme/app_theme.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/anime/models/anime_list_models.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/models/anime_rating_models.dart';
import 'package:pubget/features/anime/providers/anime_character_provider.dart';
import 'package:pubget/features/anime/providers/anime_hub_social_provider.dart';
import 'package:pubget/features/anime/providers/anime_providers.dart';
import 'package:pubget/features/anime/repositories/anime_hub_social_repository.dart';
import 'package:pubget/features/anime/screens/anime_browse_page.dart';
import 'package:pubget/features/anime/screens/anime_character_page.dart';
import 'package:pubget/features/anime/screens/anime_details_page.dart';
import 'package:pubget/features/anime/screens/anime_hub_page.dart';
import 'package:pubget/features/fan_works/models/fan_work_models.dart';
import 'package:pubget/features/fan_works/repositories/fan_work_repository.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';
import 'package:pubget/features/home/models/home_models.dart';
import 'package:pubget/features/home/repositories/home_repository.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/authentication/providers/onboarding_provider.dart';
import 'package:pubget/features/social/models/public_profile.dart';

import 'anime_test_support.dart';
import 'authentication_test_support.dart';
import 'social_test_support.dart';

void main() {
  testWidgets('hub shows loading then trending titles', (tester) async {
    final repository = FakeAnimeRepository()..gate = Completer<void>();
    await tester.pumpWidget(
      _harness(repository: repository, child: const AnimeHubPage()),
    );
    await tester.pump();
    expect(find.byType(PubgetSkeleton), findsWidgets);
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Frieren'), findsWidgets);
    expect(find.text('Top rated'), findsNothing);
    expect(find.text('Trending'), findsNothing);
    expect(find.text('Upcoming'), findsNothing);
    expect(find.text('This season', skipOffstage: false), findsWidgets);
    expect(find.text('Most popular', skipOffstage: false), findsWidgets);
  });

  testWidgets('hub empty state', (tester) async {
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(
          page: const AnimePage(items: <Anime>[]),
          genres: const <AnimeGenre>[],
          seasons: const <AnimeSeasonYear>[],
        ),
        child: const AnimeHubPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AnimeStrings.emptyCatalog), findsWidgets);
  });

  testWidgets('hub error state has retry', (tester) async {
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(failure: const UnavailableError()),
        child: const AnimeHubPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AnimeStrings.unableToLoad), findsWidgets);
    expect(find.text(AnimeStrings.retry), findsWidgets);
  });

  testWidgets('search empty results', (tester) async {
    final repository = FakeAnimeRepository(
      page: const AnimePage(items: <Anime>[]),
    );
    await tester.pumpWidget(
      _harness(repository: repository, child: const AnimeHubPage()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hub-open-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text(AnimeStrings.nothingFound), findsWidgets);
  });

  testWidgets('hub search field stays mounted while typing a name', (
    tester,
  ) async {
    final repository = FakeAnimeRepository();
    await tester.pumpWidget(
      _harness(repository: repository, child: const AnimeHubPage()),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-type-tv')), findsNothing);
    await tester.tap(find.byKey(const Key('hub-search-cta')));
    await tester.pumpAndSettle();
    final search = find.byKey(const Key('anime-hub-search'));
    final element = tester.element(search);
    await tester.enterText(find.byType(TextField), 'frieren');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.element(search), same(element));
    await tester.pumpAndSettle();
    expect(repository.searchCalls, greaterThan(0));
    expect(find.text('Frieren'), findsWidgets);
  });

  testWidgets('hub search shows results from across Pubget', (tester) async {
    final repository = FakeAnimeRepository();
    await tester.pumpWidget(
      _harness(
        repository: repository,
        child: const AnimeHubPage(),
        homeRepository: _FakeHomeRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hub-search-cta')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'frieren');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text(AnimeStrings.aggregatedResults), findsOneWidget);
    expect(find.text('Frieren fans'), findsOneWidget);
    expect(find.text(AnimeStrings.entityGroup), findsOneWidget);
  });

  testWidgets('hub type and season chips search without a name', (
    tester,
  ) async {
    final repository = FakeAnimeRepository();
    await tester.pumpWidget(
      _harness(repository: repository, child: const AnimeHubPage()),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-season-fall')), findsNothing);
    await tester.tap(find.byKey(const Key('hub-open-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter-type-tv')));
    await tester.pumpAndSettle();
    expect(repository.searchCalls, greaterThan(0));
    expect(repository.lastFilter?.type, AnimeTypeFilter.tv);
    expect(find.text('Frieren'), findsWidgets);

    await tester.tap(find.byKey(const Key('filter-season-fall')));
    await tester.pumpAndSettle();
    expect(repository.lastFilter?.season, AnimeSeason.fall);
    expect(repository.lastFilter?.year, isNotNull);
    expect(find.text('Frieren'), findsWidgets);
  });

  testWidgets('details success, character failure does not hide anime', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(
          charactersFailure: const NetworkError(),
        ),
        child: const AnimeDetailsPage(animeId: '52991'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Frieren'), findsWidgets);
    expect(find.text(AnimeStrings.rateAnime), findsWidgets);
  });

  testWidgets('favorite toggle highlights immediately and persists ids', (
    tester,
  ) async {
    final profiles = FakeProfileRepository();
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(),
        profiles: profiles,
        child: const AnimeDetailsPage(animeId: '52991'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('favorite-anime')));
    await tester.pump();
    expect(find.text(AnimeStrings.favorited), findsWidgets);
    await tester.pumpAndSettle();
    expect(profiles.lastUpdate?.favoriteAnimeIds, contains('52991'));
  });

  testWidgets('character sheet opens immediately then fills in Jikan details', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = FakeAnimeRepository(
      characters: const <AnimeCharacter>[
        AnimeCharacter(
          id: '10',
          name: 'Frieren',
          role: 'Main',
          imageUrl: 'https://example.test/char.jpg',
        ),
      ],
    )..characterDetailsGate = gate;
    await tester.pumpWidget(
      _harness(
        repository: repository,
        child: const AnimeDetailsPage(animeId: '52991'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('character-10')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('character-10')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('character-sheet')), findsOneWidget);
    expect(find.byKey(const Key('character-sheet-name')), findsOneWidget);
    expect(find.text('An elf mage.'), findsNothing);
    expect(repository.characterDetailsCalls, 1);
    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('An elf mage.'), findsWidgets);
    expect(find.text('フリーレン'), findsWidgets);
    expect(find.text(AnimeStrings.characterAbout), findsWidgets);
    expect(find.text(AnimeStrings.characterAnime), findsWidgets);
    expect(find.textContaining(AnimeStrings.malFavorites), findsWidgets);
  });

  testWidgets('details missing anime', (tester) async {
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(),
        child: const AnimeDetailsPage(animeId: 'missing'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AnimeStrings.detailsMissing), findsWidgets);
  });

  testWidgets('genre browse shows list', (tester) async {
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(),
        child: const AnimeBrowsePage(genreId: '1', genreName: 'Action'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Action'), findsWidgets);
    expect(find.text('Frieren'), findsWidgets);
  });

  testWidgets('season browse shows list', (tester) async {
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(),
        child: const AnimeBrowsePage(year: 2026, season: AnimeSeason.winter),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Winter 2026'), findsWidgets);
  });

  testWidgets('light and dark themes render hub cards', (tester) async {
    for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        _harness(
          repository: FakeAnimeRepository(),
          theme: theme,
          child: AnimeHubPage(key: UniqueKey()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Frieren'), findsWidgets);
    }
  });

  testWidgets('rtl hub still shows titles', (tester) async {
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(),
        textDirection: TextDirection.rtl,
        child: const AnimeHubPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Frieren'), findsWidgets);
  });

  testWidgets('details shows related works, fan works, and linked groups', (
    tester,
  ) async {
    final anime = sampleAnime(
      relations: const <AnimeRelated>[
        AnimeRelated(
          id: '59978',
          title: 'Frieren Season 2',
          relation: 'Sequel',
          type: 'anime',
        ),
        AnimeRelated(
          id: '126996',
          title: 'Sousou no Frieren',
          relation: 'Adaptation',
          type: 'manga',
        ),
      ],
    );
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(details: anime),
        groups: _FakeAnimeGroupRepository(<Group>[_group()]),
        fanWorks: _FakeFeedFanWorkRepository(<FanWork>[_fanWork()]),
        child: const AnimeDetailsPage(animeId: '52991'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AnimeStrings.relatedTitle), findsOneWidget);
    expect(find.text('Frieren Season 2'), findsWidgets);
    expect(find.text('Sequel'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text(AnimeStrings.relatedFanWorksTitle),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(AnimeStrings.relatedFanWorksTitle), findsOneWidget);
    expect(find.text('My Fan Art'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text(AnimeStrings.relatedGroupsTitle),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(AnimeStrings.relatedGroupsTitle), findsOneWidget);
    expect(find.text('Anime Club'), findsWidgets);
  });

  testWidgets('character page shows profile and community discussion', (
    tester,
  ) async {
    final repository = FakeAnimeRepository();
    final socialRepository = _FakeCharacterSocialRepository();
    final character = AnimeCharacterProvider(
      repository: repository,
      social: socialRepository,
    );
    final social = AnimeHubSocialProvider(repository: socialRepository);
    addTearDown(character.dispose);
    addTearDown(social.dispose);
    await tester.pumpWidget(
      _harness(
        repository: repository,
        character: character,
        social: social,
        child: const AnimeCharacterPage(characterId: '2816'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Frieren'), findsWidgets);
    expect(find.byKey(const Key('character-rating')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('character-discussion-input')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('character-discussion-input')), findsOneWidget);
    expect(find.byKey(const Key('character-discussion-post')), findsOneWidget);
    expect(find.text('Best commander.'), findsOneWidget);
  });
}

final class _FakeCharacterSocialRepository implements AnimeHubSocialRepository {
  @override
  Future<Result<CharacterCommunityStats?>> getCharacterStats(
    String characterId,
  ) async => Success(
    CharacterCommunityStats(
      characterId: characterId,
      name: 'Frieren',
      favoritesCount: 420,
    ),
  );

  @override
  Future<Result<List<CharacterCommunityStats>>> listPopularCharacters({
    int limit = 40,
  }) async => const Success(<CharacterCommunityStats>[
    CharacterCommunityStats(
      characterId: 'erwin',
      name: 'Erwin Smith',
      favoritesCount: 900,
    ),
    CharacterCommunityStats(
      characterId: '2816',
      name: 'Frieren',
      favoritesCount: 420,
    ),
  ]);

  @override
  Future<Result<List<CharacterDiscussion>>> listCharacterDiscussions(
    String characterId, {
    int limit = 30,
  }) async => const Success(<CharacterDiscussion>[
    CharacterDiscussion(
      id: 'post-1',
      characterId: '2816',
      userId: 'alice',
      username: 'Alice',
      text: 'Best commander.',
    ),
  ]);

  @override
  Future<Result<List<AnimeCustomList>>> listUserCustomAnimeLists(
    String userId,
  ) async => const Success(<AnimeCustomList>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Group _group() => Group(
  id: 'g1',
  name: 'Anime Club',
  description: '',
  type: GroupType.public,
  animeId: '52991',
  founderId: 'founder',
  membersCount: 3,
  maxMembers: 100,
  joinPolicy: JoinPolicy.open,
  isSearchable: true,
  createdAt: DateTime(2026),
  chatBackgroundUrl: null,
  rules: '',
  activityScore: 0,
);

FanWork _fanWork() => FanWork(
  id: 'w1',
  creatorId: 'alice',
  type: FanWorkType.drawing,
  title: 'My Fan Art',
  description: '',
  content: const FanWorkContent(),
  status: FanWorkStatus.published,
  moderationStatus: FanWorkModerationStatus.approved,
  visibility: FanWorkVisibility.public,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
);

final class _FakeAnimeGroupRepository
    implements GroupRepository, AnimeLinkedGroupRepository {
  _FakeAnimeGroupRepository(this.groups);

  final List<Group> groups;

  @override
  Future<Result<List<Group>>> listGroupsByAnime(
    String animeId, {
    int limit = 20,
  }) async => Success<List<Group>>(groups);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeFeedFanWorkRepository implements FanWorkRepository {
  _FakeFeedFanWorkRepository(this.works);

  final List<FanWork> works;

  @override
  Future<Result<FanWorkListPage>> getPublicFeed({
    FanWorkType? type,
    String? animeId,
    FanWork? after,
    int limit = 20,
  }) async =>
      Success<FanWorkListPage>(FanWorkListPage(items: works, hasMore: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness({
  required FakeAnimeRepository repository,
  required Widget child,
  ThemeData? theme,
  TextDirection textDirection = TextDirection.ltr,
  FakeProfileRepository? profiles,
  GroupRepository? groups,
  FanWorkRepository? fanWorks,
  AnimeCharacterProvider? character,
  AnimeHubSocialProvider? social,
  HomeRepository? homeRepository,
}) {
  final network = NetworkService(probe: () async => true);
  final hub = AnimeHubProvider(repository: repository);
  final list = AnimeListProvider(
    repository: repository,
    debounce: Duration.zero,
  );
  final details = AnimeDetailsProvider(
    repository: repository,
    profiles: profiles,
  );
  final auth = AuthProvider(
    repository: FakeAuthRepository(
      user: const AuthUser(id: 'user-1', email: 'fan@example.com'),
    ),
  )..initialize();
  final onboarding = OnboardingProvider(repository: FakeUserRepository());
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NetworkService>.value(value: network),
      ChangeNotifierProvider<AnimeHubProvider>.value(value: hub),
      ChangeNotifierProvider<AnimeListProvider>.value(value: list),
      ChangeNotifierProvider<AnimeDetailsProvider>.value(value: details),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
      if (character != null)
        ChangeNotifierProvider<AnimeCharacterProvider>.value(value: character),
      if (social != null)
        ChangeNotifierProvider<AnimeHubSocialProvider>.value(value: social),
      if (groups != null) Provider<GroupRepository>.value(value: groups),
      if (fanWorks != null) Provider<FanWorkRepository>.value(value: fanWorks),
      if (homeRepository != null)
        Provider<HomeRepository>.value(value: homeRepository),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Directionality(textDirection: textDirection, child: child),
    ),
  );
}

final class _FakeHomeRepository implements HomeRepository {
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
  Future<Result<DiscoverySearchResults>> search(String query) async =>
      Success(
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
