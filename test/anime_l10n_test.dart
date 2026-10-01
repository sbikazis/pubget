import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/l10n/app_strings.dart';
import 'package:pubget/features/anime/l10n/anime_copy.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/models/anime_rating_models.dart';
import 'package:pubget/features/anime/widgets/anime_hub_drawer.dart';
import 'package:pubget/features/anime/widgets/anime_widgets.dart';

void main() {
  test('maps catalog terms to Arabic and keeps original titles', () {
    final copy = AnimeCopy.forLocale(const Locale('ar'));
    expect(copy.status('Finished Airing'), 'مكتمل');
    expect(copy.typeLabel('TV'), 'تلفزيون');
    expect(copy.genre('Action'), 'أكشن');
    expect(copy.season(AnimeSeason.fall), 'خريف');
    expect(copy.voiceLanguage('Japanese'), 'اليابانية / Japanese');
    expect(copy.nothingFound, 'لا يوجد أنمي');
    expect(copy.ui('Frieren'), 'Frieren');
  });

  test('latest updates title resolves in both locales', () {
    // Regression: the provider emitted a hand-typed 'Latest Updates' that no
    // map entry matched, so the page title stayed English in Arabic.
    final ar = AnimeCopy.forLocale(const Locale('ar'));
    final en = AnimeCopy.forLocale(const Locale('en'));
    expect(ar.pageTitle(AnimeStrings.latestUpdates), 'آخر التحديثات');
    expect(en.pageTitle(AnimeStrings.latestUpdates), AnimeStrings.latestUpdates);
  });

  test('hub drawer rows are all localized', () {
    // Regression guard: the hub drawer is the only way into most Anime
    // screens, so a row whose label stays English under Arabic silently
    // strands an Arabic-speaking user on an untranslated screen.
    final arStrings = AppStrings.forLocale(const Locale('ar'));
    final enStrings = AppStrings.forLocale(const Locale('en'));
    final ar = AnimeCopy.forLocale(const Locale('ar'));
    final en = AnimeCopy.forLocale(const Locale('en'));
    expect(AnimeHubDestinations.values, isNotEmpty);
    for (final destination in AnimeHubDestinations.values) {
      final arabic = destination.label(arStrings, ar);
      expect(arabic, isNotEmpty, reason: '${destination.id} has no label');
      expect(
        arabic,
        isNot(equals(destination.label(enStrings, en))),
        reason: '${destination.id} falls back to English in Arabic',
      );
    }
  });

  test('hardcoded English empty states and dialogs are localized', () {
    // Regression: these three were literal strings inside the widget tree, so
    // they stayed English in Arabic even though the maps had no key for them.
    final ar = AnimeCopy.forLocale(const Locale('ar'));
    final en = AnimeCopy.forLocale(const Locale('en'));

    expect(en.noFavoriteAnime, 'No favorite anime yet');
    expect(en.areYouSure, 'Are you sure?');
    expect(en.makePublic, 'Make public');

    expect(ar.noFavoriteAnime, isNot(equals(en.noFavoriteAnime)));
    expect(ar.areYouSure, isNot(equals(en.areYouSure)));
    expect(ar.makePublic, isNot(equals(en.makePublic)));
  });

  test('English locale keeps Jikan term spelling', () {
    final copy = AnimeCopy.forLocale(const Locale('en'));
    expect(copy.status('Finished Airing'), 'Finished Airing');
    expect(copy.typeLabel('TV'), 'TV');
    expect(copy.genre('Action'), 'Action');
    expect(copy.voiceLanguage('Japanese'), 'Japanese');
    expect(copy.nothingFound, AnimeStrings.nothingFound);
  });

  testWidgets('score badge stacks A over M when the app has ratings', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimeScoreBadge(
            malScore: 7.2,
            community: AnimeCommunityStats(
              animeId: '1',
              averageScore: 8.8,
              ratingCount: 3,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('score-badge-app')), findsOneWidget);
    expect(find.byKey(const Key('score-badge-mal')), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('8.8'), findsOneWidget);
    expect(find.text('7.2'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('score-badge-app'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('score-badge-mal'))).dy),
    );
  });

  test('English copy still matches every AnimeStrings literal', () {
    _assertEnglishContract(AnimeCopy.forLocale(const Locale('en')));
  });

  testWidgets('score badge shows only M when N is 0', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimeScoreBadge(malScore: 7.2),
        ),
      ),
    );
    expect(find.byKey(const Key('score-badge-app')), findsNothing);
    expect(find.byKey(const Key('score-badge-mal')), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('A'), findsNothing);
  });

  test('the statistics unavailable state is explained in both locales', () {
    // The tab must be able to say "not counted yet" rather than drawing a
    // partial chart, so the explanation itself cannot be an English leftover.
    final ar = AnimeCopy.forLocale(const Locale('ar'));
    final en = AnimeCopy.forLocale(const Locale('en'));
    for (final copy in <AnimeCopy>[ar, en]) {
      expect(copy.statisticsUnavailable, isNotEmpty);
      expect(copy.statisticsUnavailableMessage, isNotEmpty);
      expect(copy.listBreakdown, isNotEmpty);
    }
    expect(
      ar.statisticsUnavailable,
      isNot(equals(en.statisticsUnavailable)),
    );
    expect(ar.listBreakdown, isNot(equals(en.listBreakdown)));
  });

  test('hub destination tabs are localized in both directions', () {
    final ar = AnimeCopy.forLocale(const Locale('ar'));
    final en = AnimeCopy.forLocale(const Locale('en'));
    // Every hub destination carries a tab, so none may fall back to English.
    for (final destination in AnimeHubDestination.values) {
      final arabic = ar.hubDestination(destination);
      final english = en.hubDestination(destination);
      expect(arabic, isNotEmpty, reason: '${destination.name} has no label');
      expect(english, isNotEmpty, reason: '${destination.name} has no label');
      expect(
        arabic,
        isNot(equals(english)),
        reason: '${destination.name} stayed English under Arabic',
      );
    }
    // Seasonal and popular reuse the catalog copy, so a title is never spelled
    // two different ways between the hub tab and the browse page.
    expect(
      ar.hubDestination(AnimeHubDestination.thisSeason),
      ar.catalog(AnimeCatalogKind.thisSeason),
    );
    expect(
      ar.hubDestination(AnimeHubDestination.popular),
      ar.catalog(AnimeCatalogKind.popular),
    );
    // The landing destination must be the first tab, so a member lands on it.
    expect(AnimeHubDestination.values.first, AnimeHubDestination.latest);
    expect(
      en.hubDestination(AnimeHubDestination.latest),
      AnimeStrings.latestUpdates,
    );
  });
}

/// Every legacy English literal in `AnimeStrings` must still resolve to
/// itself: the localization work may add Arabic copy, never reword English.
void _assertEnglishContract(AnimeCopy copy) {
  const renamedBySpec = <String>{
    'My anime lists',
    'Info',
  };
  const literals = <String>[
      AnimeStrings.addToList,
      AnimeStrings.ageAdult,
      AnimeStrings.ageAllAges,
      AnimeStrings.ageTeens,
      AnimeStrings.aggregatedResults,
      AnimeStrings.cachedBanner,
      AnimeStrings.characterAbout,
      AnimeStrings.characterAnime,
      AnimeStrings.characterDiscussionEmpty,
      AnimeStrings.characterDiscussionHint,
      AnimeStrings.characterDiscussions,
      AnimeStrings.characterFacts,
      AnimeStrings.characterMalId,
      AnimeStrings.characterManga,
      AnimeStrings.characterNicknames,
      AnimeStrings.characterNotFound,
      AnimeStrings.characterRank,
      AnimeStrings.characterReels,
      AnimeStrings.characterRole,
      AnimeStrings.characterVoices,
      AnimeStrings.characterYourRating,
      AnimeStrings.charactersTitle,
      AnimeStrings.checkConnection,
      AnimeStrings.closeSearch,
      AnimeStrings.communityScore,
      AnimeStrings.communityStats,
      AnimeStrings.copied,
      AnimeStrings.createList,
      AnimeStrings.customList,
      AnimeStrings.customListDescription,
      AnimeStrings.customListName,
      AnimeStrings.customListTab,
      AnimeStrings.customLists,
      AnimeStrings.customListsEmpty,
      AnimeStrings.customListsEmptyMessage,
      AnimeStrings.customListsTitle,
      AnimeStrings.delete,
      AnimeStrings.deleteList,
      AnimeStrings.detailsMissing,
      AnimeStrings.editList,
      AnimeStrings.editRating,
      AnimeStrings.emptyCatalog,
      AnimeStrings.endOfList,
      AnimeStrings.entityAnime,
      AnimeStrings.entityCharacter,
      AnimeStrings.entityEvent,
      AnimeStrings.entityFanWork,
      AnimeStrings.entityGroup,
      AnimeStrings.entityPerson,
      AnimeStrings.entityReel,
      AnimeStrings.favorite,
      AnimeStrings.favoriteAnimeTab,
      AnimeStrings.favoriteCharacter,
      AnimeStrings.favoriteCharactersTab,
      AnimeStrings.favoriteLimit,
      AnimeStrings.favorited,
      AnimeStrings.filterAgeRating,
      AnimeStrings.filterGenre,
      AnimeStrings.filterSeason,
      AnimeStrings.filterSort,
      AnimeStrings.filterStatus,
      AnimeStrings.filterStudio,
      AnimeStrings.filterType,
      AnimeStrings.genresTitle,
      AnimeStrings.hubTitle,
      AnimeStrings.libraryEmpty,
      AnimeStrings.libraryEmptyMessage,
      AnimeStrings.links,
      AnimeStrings.listNameRequired,
      AnimeStrings.listStatus,
      AnimeStrings.listsTab,
      AnimeStrings.loadingProfile,
      AnimeStrings.malFavorites,
      AnimeStrings.malScore,
      AnimeStrings.mostListed,
      AnimeStrings.myAnimeTitle,
      AnimeStrings.myLibrary,
      AnimeStrings.newCustomList,
      AnimeStrings.noEventsFound,
      AnimeStrings.noRatingsYet,
      AnimeStrings.noReelsFound,
      AnimeStrings.nothingFound,
      AnimeStrings.nothingFoundMessage,
      AnimeStrings.offlineCached,
      AnimeStrings.openSearch,
      AnimeStrings.popularCharactersTitle,
      AnimeStrings.popularSubtitle,
      AnimeStrings.post,
      AnimeStrings.privateList,
      AnimeStrings.privateListHint,
      AnimeStrings.pubgetFavorites,
      AnimeStrings.rateAnime,
      AnimeStrings.ratingsTab,
      AnimeStrings.ratingsTitle,
      AnimeStrings.recommendedForYou,
      AnimeStrings.relatedEvents,
      AnimeStrings.relatedFanWorksTitle,
      AnimeStrings.relatedGroupsTitle,
      AnimeStrings.relatedReels,
      AnimeStrings.relatedTitle,
      AnimeStrings.removeFromList,
      AnimeStrings.reportLabel,
      AnimeStrings.reportReview,
      AnimeStrings.retry,
      AnimeStrings.reviewHint,
      AnimeStrings.reviewsTitle,
      AnimeStrings.searchFiltersHint,
      AnimeStrings.searchHint,
      AnimeStrings.searchHomeHint,
      AnimeStrings.seasonalCharacters,
      AnimeStrings.seasonsTitle,
      AnimeStrings.seeAll,
      AnimeStrings.share,
      AnimeStrings.sortFavorites,
      AnimeStrings.sortMembers,
      AnimeStrings.sortNewest,
      AnimeStrings.sortTitle,
      AnimeStrings.statusAiring,
      AnimeStrings.statusFinished,
      AnimeStrings.statusUpcoming,
      AnimeStrings.submitRating,
      AnimeStrings.synopsisTitle,
      AnimeStrings.tabCharacters,
      AnimeStrings.tabRelated,
      AnimeStrings.theirAnimeTitle,
      AnimeStrings.thisSeasonSubtitle,
      AnimeStrings.trailer,
      AnimeStrings.unableToLoad,
      AnimeStrings.writeReview,
  ];
  for (final literal in literals) {
    if (renamedBySpec.contains(literal)) continue;
    expect(
      copy.ui(literal),
      literal,
      reason: 'English copy for "\$literal" drifted from AnimeStrings',
    );
  }
}
