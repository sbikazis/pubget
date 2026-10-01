import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/network/network_service.dart';

import 'package:pubget/core/theme/app_theme.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/anime/l10n/anime_copy.dart';
import 'package:pubget/features/anime/models/anime_list_models.dart';
import 'package:pubget/features/anime/providers/anime_library_provider.dart';
import 'package:pubget/features/anime/repositories/anime_library_repository.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/models/anime_rating_models.dart';
import 'package:pubget/features/anime/providers/anime_character_provider.dart';
import 'package:pubget/features/anime/providers/anime_hub_social_provider.dart';
import 'package:pubget/features/anime/providers/anime_providers.dart';
import 'package:pubget/features/anime/screens/anime_search_page.dart';
import 'package:pubget/features/anime/widgets/anime_hub_widgets.dart';
import 'package:pubget/features/anime/widgets/anime_ranked_cards.dart';
import 'package:pubget/features/anime/repositories/anime_hub_social_repository.dart';
import 'package:pubget/features/anime/screens/anime_browse_page.dart';
import 'package:pubget/features/anime/screens/anime_popular_characters_page.dart';
import 'package:pubget/features/anime/screens/anime_ratings_page.dart';
import 'package:pubget/features/anime/screens/anime_character_page.dart';
import 'package:pubget/features/anime/screens/anime_details_page.dart';
import 'package:pubget/features/anime/screens/anime_hub_page.dart';
import 'package:pubget/features/anime/widgets/anime_widgets.dart';
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

/// The scroller that actually holds the details tab content.
///
/// `find.byType(Scrollable).first` is the TabBarView's PageView, so scrolling
/// it moves nothing; the tab body is the Scrollable inside the details list.
Finder detailsTabScroller() => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

/// Serves the character favourite write path so the app bar heart can be
/// asserted without the whole library stack.
final class _FakeCharacterFavoriteRepository implements AnimeLibraryRepository {
  final List<String> favorites = <String>[];

  @override
  Future<Result<List<CharacterFavorite>>> getCharacterFavorites() async =>
      const Success(<CharacterFavorite>[]);

  @override
  Future<Result<List<AnimeCustomList>>> getCustomLists({
    String? userId,
  }) async => const Success(<AnimeCustomList>[]);

  @override
  Future<Result<AnimeListPage>> getList({
    AnimeListStatus? status,
    String? cursor,
    int limit = 50,
  }) async => const Success(AnimeListPage());

  @override
  Future<Result<CharacterFavorite>> setCharacterFavorite({
    required String characterId,
    required bool favorite,
    String name = '',
    String? imageUrl,
    int? rating,
  }) async {
    if (favorite) {
      favorites.add(characterId);
    } else {
      favorites.remove(characterId);
    }
    return Success<CharacterFavorite>(
      CharacterFavorite(
        characterId: characterId,
        name: name,
        imageUrl: imageUrl,
        rating: rating,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('character page favourites from the app bar and shows portraits', (
    tester,
  ) async {
    final libraryRepository = _FakeCharacterFavoriteRepository();
    final library = AnimeLibraryProvider(repository: libraryRepository)
      ..bindUser('user-1');
    addTearDown(library.dispose);
    final character = AnimeCharacterProvider(
      repository: FakeAnimeRepository(
        characters: <AnimeCharacter>[
          AnimeCharacter(
            id: '2816',
            name: 'Frieren',
            imageUrl: 'https://example.test/frieren.jpg',
            about:
                'Birthday: January 15\n'
                'Zodiac: Capricorn\n'
                // A colon-free paragraph, so it lands in the narrative section
                // and is long enough to need the show more toggle.
                '${'She spent a thousand years watching her companions fall. ' * 6}',
            voiceActors: <VoiceActor>[
              VoiceActor(
                id: 'v1',
                name: 'Atsumi Tanezaki',
                language: 'Japanese',
                imageUrl: 'https://example.test/va.jpg',
              ),
            ],
          ),
        ],
      ),
      social: _FakeCharacterSocialRepository(),
    );
    addTearDown(character.dispose);
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(),
        character: character,
        library: library,
        child: const AnimeCharacterPage(characterId: '2816'),
      ),
    );
    await tester.pumpAndSettle();

    // The heart lives in the app bar and is the only favourite affordance.
    expect(find.byKey(const Key('favorite-character')), findsOneWidget);
    await tester.tap(find.byKey(const Key('favorite-character')));
    await tester.pumpAndSettle();
    expect(libraryRepository.favorites, contains('2816'));
    expect(library.isCharacterFavorite('2816'), isTrue);

    // The voice actor portrait is used when the provider has one.
    expect(find.byType(AppImageLoader), findsWidgets);

    // The biographical fact labels are translated, not raw English. The facts
    // sit below the fold in the character list, so scroll them into view.
    final characterScroller = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('anime-expandable-toggle')),
      300,
      scrollable: characterScroller,
    );
    expect(find.text('Zodiac'), findsWidgets);
  });

  testWidgets('both ranking pages share one ranked anime card', (tester) async {
    for (final source in AnimeRankingSource.values) {
      await tester.pumpWidget(
        _harness(
          repository: FakeAnimeRepository(),
          social: AnimeHubSocialProvider(
            repository: _FakeRankingSocialRepository(),
          )..loadTopRated(),
          child: AnimeRatingsPage(source: source),
        ),
      );
      await tester.pumpAndSettle();
      // Regression: each page hand-rolled its own row, so the two rankings
      // disagreed on badge, score colour and caption.
      expect(find.byType(AnimeRankedCard), findsWidgets, reason: '$source');
    }
  });

  testWidgets('popular characters use the shared ranked character card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(),
        social: AnimeHubSocialProvider(
          repository: _FakeRankingSocialRepository(),
        )..loadPopularCharacters(),
        child: const AnimePopularCharactersPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnimeRankedCharacterCard), findsWidgets);
  });

  testWidgets('hub opens on latest updates and pages it newest first', (
    tester,
  ) async {
    final repository = FakeAnimeRepository()..gate = Completer<void>();
    await tester.pumpWidget(
      _harness(repository: repository, child: const AnimeHubPage()),
    );
    await tester.pump();
    expect(find.byType(PubgetSkeleton), findsWidgets);
    repository.gate!.complete();
    await tester.pumpAndSettle();

    // Latest Updates is the landing destination, not a curated strip.
    expect(find.byKey(const Key('hub-latest-grid')), findsOneWidget);
    expect(find.byKey(const Key('hub-this-season-grid')), findsNothing);
    expect(repository.latestCalls, 1);
    // Seasonal and popular stay reachable as their own destinations.
    expect(repository.thisSeasonCalls, 0);
    expect(repository.popularCalls, 0);
    expect(find.text('Frieren'), findsWidgets);
    expect(find.text('This season', skipOffstage: false), findsWidgets);
    expect(find.text('Most popular', skipOffstage: false), findsWidgets);
    expect(find.text('Top rated'), findsNothing);
    expect(find.text('Trending'), findsNothing);
    expect(find.text('Upcoming'), findsNothing);
  });

  testWidgets('hub destinations keep separate catalogs when switching tabs', (
    tester,
  ) async {
    final repository = FakeAnimeRepository();
    await tester.pumpWidget(
      _harness(repository: repository, child: const AnimeHubPage()),
    );
    await tester.pumpAndSettle();
    expect(repository.latestCalls, 1);

    await tester.tap(find.text('This season'));
    await tester.pumpAndSettle();
    expect(repository.thisSeasonCalls, 1);
    expect(repository.latestCalls, 1);
    expect(find.byKey(Key('hub-${AnimeHubDestination.thisSeason.name}-grid')),
        findsOneWidget);

    await tester.tap(find.text('Most popular'));
    await tester.pumpAndSettle();
    expect(repository.popularCalls, 1);
    expect(repository.latestCalls, 1);

    // Returning to a destination must not re-fetch it or lose its pages.
    await tester.tap(find.text(AnimeStrings.latestUpdates));
    await tester.pumpAndSettle();
    expect(repository.latestCalls, 1);
  });

  testWidgets('hub latest updates appends the next page', (tester) async {    // A short surface guarantees the grid overflows, so scrolling really pages.
    tester.view.physicalSize = const Size(360, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = FakeAnimeRepository(
      page: AnimePage(
        items: List<Anime>.generate(
          6,
          (index) => sampleAnime(id: 'a-$index', title: 'Title $index'),
        ),
        hasNextPage: true,
      ),
    );
    await tester.pumpWidget(
      _harness(repository: repository, child: const AnimeHubPage()),
    );
    await tester.pumpAndSettle();
    expect(repository.latestPages, <int>[1]);

    final landing = Provider.of<AnimeHubCatalogProvider>(
      tester.element(find.byType(AnimeHubPage)),
      listen: false,
    ).catalog(AnimeHubDestination.latest);
    expect(landing.items.length, 6);

    await tester.drag(find.byType(AnimePaginatedList), const Offset(0, -600));
    await tester.pumpAndSettle();

    // Newest-first ordering is preserved across the page boundary: the catalog
    // query pages forward and the next page is appended, never substituted.
    expect(repository.latestPages, containsAllInOrder(<int>[1, 2]));
    expect(landing.items.length, 12);
    expect(landing.items.first.id, 'a-0');
    expect(landing.items[6].id, 'a-0-p2');
    expect(landing.hasNextPage, isFalse);
  });

  testWidgets('arabic rtl hub lands on latest updates', (tester) async {
    final repository = FakeAnimeRepository();
    final arabic = AnimeCopy.forLocale(const Locale('ar'));
    await tester.pumpWidget(
      _harness(
        repository: repository,
        textDirection: TextDirection.rtl,
        child: const AnimeHubPage(),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    // Landing tab renders the Arabic label, and the seasonal/popular discovery
    // destinations stay reachable in Arabic too.
    expect(
      find.text(arabic.hubDestination(AnimeHubDestination.latest)),
      findsWidgets,
    );
    expect(
      find.text(arabic.catalog(AnimeCatalogKind.thisSeason)),
      findsWidgets,
    );
    expect(find.text(arabic.catalog(AnimeCatalogKind.popular)), findsWidgets);
    expect(repository.latestCalls, 1);
    expect(find.text('Latest Updates'), findsNothing);
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
    // The heart is the only favourite affordance on the page, so its filled
    // state and its tooltip are what carry the feedback.
    final heart = tester.widget<IconButton>(
      find.byKey(const Key('favorite-anime')),
    );
    expect(heart.tooltip, AnimeStrings.favorited);
    expect(
      find.descendant(
        of: find.byKey(const Key('favorite-anime')),
        matching: find.byIcon(Icons.favorite),
      ),
      findsOneWidget,
    );
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
    await tester.tap(find.text(AnimeStrings.tabCharactersCast));
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
    // The hub keeps exactly three tabs, so related content shares the details
    // tab and has to be scrolled to.
    await tester.scrollUntilVisible(
      find.text(AnimeStrings.relatedTitle),
      300,
      scrollable: detailsTabScroller(),
    );

    expect(find.text(AnimeStrings.relatedTitle), findsWidgets);
    expect(find.text('Frieren Season 2'), findsWidgets);
    expect(find.text('Sequel'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text(AnimeStrings.relatedFanWorksTitle),
      300,
      scrollable: detailsTabScroller(),
    );
    expect(find.text(AnimeStrings.relatedFanWorksTitle), findsOneWidget);
    expect(find.text('My Fan Art'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text(AnimeStrings.relatedGroupsTitle),
      300,
      scrollable: detailsTabScroller(),
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

  testWidgets('hub search opens a dedicated search screen', (tester) async {
    final repository = FakeAnimeRepository();
    await tester.pumpWidget(
      _harness(repository: repository, child: const AnimeHubPage()),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('anime-hub-search')), findsNothing);

    await tester.tap(find.byKey(const Key('hub-open-search')));
    await tester.pumpAndSettle();

    expect(find.byType(AnimeSearchPage), findsOneWidget);
    expect(find.byKey(const Key('anime-hub-search')), findsOneWidget);
    expect(find.text(AnimeStrings.openSearch), findsWidgets);
  });

  testWidgets('details page keeps exactly three tabs', (tester) async {
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(details: sampleAnime()),
        child: const AnimeDetailsPage(animeId: '52991'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Tab), findsNWidgets(3));
    final tabBar = find.byType(TabBar);
    final tabs = find.descendant(of: tabBar, matching: find.byType(Text));
    expect(
      tester.widgetList<Text>(tabs).map((widget) => widget.data).toList(),
      <String>[
        AnimeStrings.tabDetails,
        AnimeStrings.tabCharactersCast,
        AnimeStrings.tabStatistics,
      ],
    );
  });

  testWidgets('statistics tab charts the community scores', (tester) async {
    final socialRepository = _FakeStatsSocialRepository();
    final social = AnimeHubSocialProvider(repository: socialRepository);
    addTearDown(social.dispose);
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(details: sampleAnime()),
        social: social,
        child: const AnimeDetailsPage(animeId: '52991'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AnimeStrings.tabStatistics));
    await tester.pumpAndSettle();

    expect(find.text(AnimeStrings.scoreDistribution), findsOneWidget);
    expect(find.byType(AnimeVoteDistribution), findsOneWidget);
    // The donut shares the selected score with the bars it sits above.
    expect(find.byType(AnimeDonutChart), findsOneWidget);
    final statsScroller = find
        .descendant(
          of: find.byKey(const Key('anime-stats-tab')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text(AnimeStrings.criteriaBreakdown),
      300,
      scrollable: statsScroller,
    );
    expect(find.text(AnimeStrings.criteriaBreakdown), findsOneWidget);
  });

  testWidgets('statistics tab charts the server distribution, not the loaded reviews', (tester) async {
    final social = AnimeHubSocialProvider(repository: _FakeStatsSocialRepository());
    addTearDown(social.dispose);
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(details: sampleAnime()),
        social: social,
        child: const AnimeDetailsPage(animeId: '52991'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AnimeStrings.tabStatistics));
    await tester.pumpAndSettle();

    final bars = tester.widget<AnimeVoteDistribution>(
      find.byType(AnimeVoteDistribution),
    );
    // The server said 4/3/1 across 8/9/10. The fake returns two reviews that
    // would imply 1 and 1, so any value here proves the chart came from the
    // aggregate rather than from the page of reviews.
    expect(bars.counts, const <int>[0, 0, 0, 0, 0, 0, 0, 4, 3, 1]);
  });

  testWidgets('statistics tab shows the five-state breakdown from the server', (tester) async {
    final social = AnimeHubSocialProvider(repository: _FakeStatsSocialRepository());
    addTearDown(social.dispose);
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(details: sampleAnime()),
        social: social,
        child: const AnimeDetailsPage(animeId: '52991'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AnimeStrings.tabStatistics));
    await tester.pumpAndSettle();

    final statsScroller = find
        .descendant(
          of: find.byKey(const Key('anime-stats-tab')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('anime-stats-status-bars')),
      300,
      scrollable: statsScroller,
    );
    expect(find.byKey(const Key('anime-stats-status-bars')), findsOneWidget);
    for (final status in AnimeListStatus.tabs) {
      expect(
        find.byKey(Key('anime-status-bar-${status.wireValue}')),
        findsOneWidget,
        reason: '${status.wireValue} has no row',
      );
    }
    expect(find.text('50'), findsOneWidget);
  });

  testWidgets('statistics tab says so when the server has published no aggregates', (tester) async {
    // The pre-migration shape: counts exist, the distribution does not. The tab
    // must not fall back to counting the two reviews it loaded.
    final social = AnimeHubSocialProvider(
      repository: _FakeStatsSocialRepository(aggregates: false),
    );
    addTearDown(social.dispose);
    await tester.pumpWidget(
      _harness(
        repository: FakeAnimeRepository(details: sampleAnime()),
        social: social,
        child: const AnimeDetailsPage(animeId: '52991'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AnimeStrings.tabStatistics));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('anime-stats-unavailable')), findsOneWidget);
    expect(find.byType(AnimeVoteDistribution), findsNothing);
    expect(find.byType(AnimeDonutChart), findsNothing);
    expect(find.byKey(const Key('anime-stats-status-bars')), findsNothing);
    final copy = AnimeCopy.forLocale(const Locale('en'));
    expect(find.text(copy.statisticsUnavailable), findsOneWidget);
  });

  testWidgets(
    'statistics tab distinguishes an all-zero aggregate from an absent one',
    (tester) async {
      // A migrated title nobody has given a plottable score keeps real counts
      // and a real, empty distribution. That is different from a title the
      // migration has not reached, and the tab must not collapse the two: one
      // shows the chart, the other explains itself.
      final social = AnimeHubSocialProvider(
        repository: _FakeStatsSocialRepository(unplottableOnly: true),
      );
      addTearDown(social.dispose);
      await tester.pumpWidget(
        _harness(
          repository: FakeAnimeRepository(details: sampleAnime()),
          social: social,
          child: const AnimeDetailsPage(animeId: '52991'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AnimeStrings.tabStatistics));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('anime-stats-unavailable')), findsNothing);
      expect(find.byType(AnimeVoteDistribution), findsOneWidget);
      // The breakdown is still published, so it is still shown further down.
      await tester.dragUntilVisible(
        find.byKey(const Key('anime-stats-status-bars')),
        find.byType(ListView).last,
        const Offset(0, -120),
      );
      expect(find.byKey(const Key('anime-stats-status-bars')), findsOneWidget);
      expect(
        find.byKey(const Key('anime-status-bar-watching')),
        findsOneWidget,
      );
    },
  );
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
  AnimeLibraryProvider? library,
  HomeRepository? homeRepository,
  Locale locale = const Locale('en'),
}) {
  final network = NetworkService(probe: () async => true);
  final hub = AnimeHubProvider(repository: repository);
  final hubCatalogs = AnimeHubCatalogProvider(repository: repository);
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
  final recommendations = AnimeRecommendationProvider(
    social:
        social ??
        AnimeHubSocialProvider(repository: _FakeCharacterSocialRepository()),
    repository: repository,
    userId: 'user-1',
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NetworkService>.value(value: network),
      ChangeNotifierProvider<AnimeHubProvider>.value(value: hub),
      ChangeNotifierProvider<AnimeHubCatalogProvider>.value(value: hubCatalogs),
      ChangeNotifierProvider<AnimeListProvider>.value(value: list),
      ChangeNotifierProvider<AnimeDetailsProvider>.value(value: details),
      ChangeNotifierProvider<AnimeRecommendationProvider>.value(
        value: recommendations,
      ),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
      if (character != null)
        ChangeNotifierProvider<AnimeCharacterProvider>.value(value: character),
      if (social != null)
        ChangeNotifierProvider<AnimeHubSocialProvider>.value(value: social),
      if (library != null)
        ChangeNotifierProvider<AnimeLibraryProvider>.value(value: library),
      if (groups != null) Provider<GroupRepository>.value(value: groups),
      if (fanWorks != null) Provider<FanWorkRepository>.value(value: fanWorks),
      if (homeRepository != null)
        Provider<HomeRepository>.value(value: homeRepository),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      locale: locale,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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

/// Social data shaped for the statistics tab: two rated reviews so the
/// histogram and the criteria bars have something real to draw.
final class _FakeStatsSocialRepository implements AnimeHubSocialRepository {
  _FakeStatsSocialRepository({this.aggregates = true, this.unplottableOnly = false});

  /// When false the server has published counts but no aggregates, which is
  /// exactly what a title written before the migration looks like.
  final bool aggregates;

  /// A migrated title whose ratings all scored zero: every count is real, but
  /// no score rounds into 1-10, so the distribution is legitimately all zero.
  final bool unplottableOnly;

  @override
  Future<Result<AnimeCommunityStats?>> getAnimeStats(String animeId) async =>
      Success(
        AnimeCommunityStats(
          animeId: animeId,
          averageScore: 8.4,
          ratingCount: 8,
          listedCount: 120,
          // Deliberately not derivable from the two reviews this fake returns:
          // a client that inferred would show 8:1, 9:1 instead.
          scoreDistribution: aggregates
              ? (unplottableOnly
                    ? const AnimeScoreDistribution.empty()
                    : const AnimeScoreDistribution(<int>[
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        4,
                        3,
                        1,
                      ]))
              : null,
          statusCounts: aggregates
              ? const AnimeListStatusCounts(<AnimeListStatus, int>{
                  AnimeListStatus.wantToWatch: 50,
                  AnimeListStatus.watching: 30,
                  AnimeListStatus.completed: 25,
                  AnimeListStatus.watchLater: 10,
                  AnimeListStatus.notInterested: 5,
                })
              : null,
        ),
      );

  @override
  Future<Result<AnimeReview?>> getMyRating(String animeId) async =>
      Success<AnimeReview?>(null);

  @override
  Future<Result<List<AnimeReview>>> listReviews(
    String animeId, {
    int limit = 30,
  }) async => Success(<AnimeReview>[
    AnimeReview(
      animeId: animeId,
      userId: 'user-1',
      criteria: const AnimeCriteriaScores(
        story: 9,
        art: 8,
        characters: 9,
        action: 6,
        sound: 8,
        enjoyment: 9,
      ),
      overall: 9,
    ),
    AnimeReview(
      animeId: animeId,
      userId: 'user-2',
      criteria: const AnimeCriteriaScores(
        story: 7,
        art: 9,
        characters: 8,
        action: 7,
        sound: 6,
        enjoyment: 8,
      ),
      overall: 8,
    ),
  ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Feeds both ranking pages: the community top-rated list and the popular
/// characters list, so the shared ranked cards can be asserted on either one.
final class _FakeRankingSocialRepository implements AnimeHubSocialRepository {
  @override
  Future<Result<List<AnimeCommunityStats>>> listTopRated({
    int limit = 50,
  }) async => Success(<AnimeCommunityStats>[
    AnimeCommunityStats(
      animeId: '52991',
      title: 'Frieren',
      averageScore: 9.1,
      ratingCount: 42,
      listedCount: 300,
    ),
    AnimeCommunityStats(
      animeId: '51179',
      title: 'Steins Gate',
      averageScore: 8.4,
      ratingCount: 12,
      listedCount: 90,
    ),
  ]);

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
      characterId: 'frieren',
      name: 'Frieren',
      favoritesCount: 800,
    ),
  ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
