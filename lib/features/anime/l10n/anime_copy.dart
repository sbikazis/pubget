import 'package:flutter/widgets.dart';

import '../../../core/l10n/anime_mapping.dart';
import '../models/anime_list_models.dart';
import '../models/anime_models.dart';
import '../models/anime_rating_models.dart';

/// Feature-scoped view over [AppTranslationMapping].
///
/// Every Anime Hub string resolves through [AppTranslationMapping]; this class
/// only adapts feature enums to the mapping's string keys so widgets keep a
/// typed, readable API. Original titles, MAL ids and Jikan narrative stay in
/// the source language.
final class AnimeCopy {
  const AnimeCopy(this._t);

  final AppTranslationMapping _t;

  static AnimeCopy of(BuildContext context) =>
      AnimeCopy(AppTranslationMapping.of(context));

  static AnimeCopy forLocale(Locale? locale) =>
      AnimeCopy(AppTranslationMapping.forLocale(locale));

  AppTranslationMapping get mapping => _t;

  // ---------------------------------------------------------------------------
  // Hub chrome
  // ---------------------------------------------------------------------------

  String get hubTitle => _t.hubTitle;
  String get latestUpdates => _t.latestUpdates;
  String get seeAll => _t.seeAll;
  String get searchHint => _t.searchHint;
  String get openSearch => _t.openSearch;
  String get closeSearch => _t.closeSearch;
  String get nothingFound => _t.nothingFound;
  String get nothingFoundMessage => _t.nothingFoundMessage;
  String get unableToLoad => _t.unableToLoad;
  String get checkConnection => _t.checkConnection;
  String get retry => _t.retry;
  String get cachedBanner => _t.cachedBanner;
  String get offlineCached => _t.offlineCached;
  String get genresTitle => _t.genresTitle;
  String get seasonsTitle => _t.seasonsTitle;
  String get charactersTitle => _t.charactersTitle;
  String get synopsisTitle => _t.synopsisTitle;
  String get detailsSection => _t.detailsSection;
  String get detailsMissing => _t.detailsMissing;
  String get emptyCatalog => _t.emptyCatalog;
  String get emptyLibrary => _t.emptyLibrary;
  String get charactersEmpty => _t.charactersEmpty;
  String get endOfList => _t.endOfList;
  String get favorite => _t.favorite;
  String get favorited => _t.favorited;
  String get addFavorite => _t.addFavorite;
  String get removeFavorite => _t.removeFavorite;
  String get trailer => _t.trailer;
  String get links => _t.links;
  String get copied => _t.copied;
  String get share => _t.share;
  String get shareAnime => _t.shareAnime;
  String get favoriteLimit => _t.favoriteLimit;
  String get sensitiveContent => _t.sensitiveContent;
  String get sensitiveContentBody => _t.sensitiveContentBody;
  String get reportLabel => _t.reportLabel;
  String get reportTitle => _t.reportTitle;
  String get recommendations => _t.recommendations;
  String get downloads => _t.downloads;
  String get showMore => _t.showMore;
  String get showLess => _t.showLess;
  String get rankLabel => _t.rankLabel;
  String get popularityLabel => _t.popularityLabel;
  String get membersLabel => _t.membersLabel;
  String get broadcastLabel => _t.broadcastLabel;
  String get episodesLabel => _t.episodesLabel;
  String get statusLabel => _t.statusLabel;
  String get seasonLabel => _t.seasonLabel;
  String get ageRatingLabel => _t.ageRatingLabel;
  String get genreLabel => _t.genreLabel;
  String get sourceLabel => _t.sourceLabel;
  String get durationLabel => _t.durationLabel;
  String get airedLabel => _t.airedLabel;
  String get studiosLabel => _t.studiosLabel;
  String get producersLabel => _t.producersLabel;
  String get appliedFilters => _t.applyFilters;

  String get factType => _t.factType;
  String get factEpisodes => _t.factEpisodes;
  String get factDuration => _t.factDuration;
  String get factAired => _t.factAired;
  String get factStudios => _t.factStudios;
  String get factSource => _t.factSource;
  String get factBroadcast => _t.factBroadcast;

  String get englishName => _t.englishName;
  String get arabicName => _t.arabicName;
  String get age => _t.age;
  String get birthday => _t.birthday;
  String get height => _t.height;
  String get weight => _t.weight;
  String get bloodType => _t.bloodType;
  String get hairColor => _t.hairColor;
  String get eyeColor => _t.eyeColor;
  String get gender => _t.gender;
  String get species => _t.species;
  String get affiliation => _t.affiliation;
  String get occupation => _t.occupation;

  // ---------------------------------------------------------------------------
  // Tabs
  // ---------------------------------------------------------------------------

  String get tabInfo => _t.tabDetails;
  String get tabCharactersCast => _t.tabCharactersCast;
  String get tabDetails => _t.tabDetails;
  String get tabStatistics => _t.tabStatistics;
  String get tabCharacters => _t.tabCharacters;
  String get tabRelated => _t.tabRelated;
  String get scoreDistribution => _t.scoreDistribution;
  String get criteriaBreakdown => _t.criteriaBreakdown;
  String get criteriaStory => _t.criteriaStory;
  String get criteriaArt => _t.criteriaArt;
  String get criteriaCharacters => _t.criteriaCharacters;
  String get criteriaAction => _t.criteriaAction;
  String get criteriaSound => _t.criteriaSound;
  String get criteriaEnjoyment => _t.criteriaEnjoyment;
  String get inMyList => _t.inMyList;
  String get tabLibrary => _t.tabLibrary;
  String get tabRatings => _t.tabRatings;
  String get tabLists => _t.tabLists;
  String get tabCustomList => _t.tabCustomList;
  String get customListTab => _t.tabCustomList;
  String get tabFavorites => _t.tabFavorites;
  String get tabPopular => _t.tabPopular;
  String get favoriteCharactersTab => _t.favoriteCharactersTab;
  String get favoriteAnimeTab => _t.favoriteAnimeTab;
  String get listsTab => _t.listsTab;
  String get ratingsTab => _t.ratingsTab;
  String get reportReview => _t.reportReview;

  // ---------------------------------------------------------------------------
  // Ratings and statistics
  // ---------------------------------------------------------------------------

  String get rateAnime => _t.rateAnime;
  String get editRating => _t.editRating;
  String get communityScore => _t.communityScore;
  String get malScore => _t.malScore;
  String get ratingsTitle => _t.ratingsTitle;
  String get votesTitle => _t.votesTitle;
  String get communityStats => _t.communityStats;
  String get statusDistribution => _t.statusDistribution;
  String get ratingCountLabel => _t.ratingCountLabel;
  String get listedCountLabel => _t.listedCountLabel;
  String get noRatingsYet => _t.noRatingsYet;
  String get noStatsYet => _t.noStatsYet;
  String get overallScoreLabel => _t.overallScoreLabel;
  String get scoreSourceApp => _t.scoreSourceApp;
  String get scoreSourceMal => _t.scoreSourceMal;
  String overallScore(String value) => _t.overallScore(value);
  String criterion(AnimeRatingCriterion value) => _t.criterion(value.id);
  String get ratingAppBadge => 'A';
  String get ratingMalBadge => 'M';

  // ---------------------------------------------------------------------------
  // My list
  // ---------------------------------------------------------------------------

  String get libraryTitle => _t.libraryTitle;
  String get libraryEmpty => _t.libraryEmpty;
  String get libraryEmptyMessage => _t.libraryEmptyMessage;
  String get listStatus => _t.listStatus;
  String get removeFromList => _t.removeFromList;
  String get changeStatus => _t.changeStatus;
  String get addToList => _t.addToList;
  String get searchInList => _t.searchInList;
  String get viewGrid => _t.viewGrid;
  String get viewNetwork => _t.viewNetwork;
  String get sortBy => _t.sortBy;
  String get sortRecentlyUpdated => _t.sortRecentlyUpdated;
  String get sortTitleAsc => _t.sortTitleAsc;
  String get sortTitleDesc => _t.sortTitleDesc;
  String get sortRatingDesc => _t.sortRatingDesc;
  String get sortRatingAsc => _t.sortRatingAsc;
  String get sortPopularityDesc => _t.sortPopularityDesc;
  String get sortYearDesc => _t.sortYearDesc;
  String get sortYearAsc => _t.sortYearAsc;
  String get formatFilter => _t.formatFilter;
  String get formatAll => _t.formatAll;
  String get signInToSaveList => _t.signInToSaveList;
  String get statusWantToWatch => _t.statusWantToWatch;
  String get statusWatching => _t.statusWatching;
  String get statusCompleted => _t.statusCompleted;
  String get statusWatchLater => _t.statusWatchLater;
  String get statusNotInterested => _t.statusNotInterested;
  String get removedFromList => _t.removedFromList;
  String get statusUpdated => _t.statusUpdated;

  // ---------------------------------------------------------------------------
  // Characters
  // ---------------------------------------------------------------------------

  String get popularCharactersTitle => _t.popularCharactersTitle;
  String get favoriteCharactersTitle => _t.favoriteCharactersTitle;
  String get characterAbout => _t.characterAbout;
  String get characterNicknames => _t.characterNicknames;
  String get characterAnime => _t.characterAnime;
  String get characterManga => _t.characterManga;
  String get characterVoices => _t.characterVoices;
  String get characterFacts => _t.characterFacts;
  String get characterMalId => _t.characterMalId;
  String get characterRole => _t.characterRole;
  String get characterRank => _t.characterRank;
  String get characterYourRating => _t.characterYourRating;
  String get characterReels => _t.characterReels;
  String get characterDiscussions => _t.characterDiscussions;
  String get characterDiscussionHint => _t.characterDiscussionHint;
  String get characterDiscussionEmpty => _t.characterDiscussionEmpty;
  String get characterNotFound => _t.characterNotFound;
  String get characterFavorites => _t.characterFavorites;
  String get characterOptional => _t.characterOptional;
  String get noFavoriteCharacters => _t.noFavoriteCharacters;
  String get noFavoriteCharactersMessage => _t.noFavoriteCharactersMessage;
  String get noCharactersFound => _t.noCharactersFound;
  String get searchCharacters => _t.searchCharacters;
  String get viewAllCharacters => _t.viewAllCharacters;
  String get favoriteCharacter => _t.favoriteCharacter;
  String get roleplay => _t.roleplay;
  String get reels => _t.reels;
  String get post => _t.post;
  String get delete => _t.delete;
  String get removedFromFavorites => _t.removedFromFavorites;
  String get loadingProfile => _t.loadingProfile;
  String get malFavorites => _t.malFavorites;
  String get pubgetFavorites => _t.pubgetFavorites;

  // ---------------------------------------------------------------------------
  // Rankings, sections, search, custom lists
  // ---------------------------------------------------------------------------

  String get malRankingTitle => _t.malRankingTitle;
  String get communityRankingTitle => _t.communityRankingTitle;
  String get myAnimeTitle => _t.myAnimeTitle;
  String get theirAnimeTitle => _t.theirAnimeTitle;
  String get reviewsTitle => _t.reviewsTitle;
  String get relatedTitle => _t.relatedTitle;
  String get relatedReels => _t.relatedReels;
  String get relatedEvents => _t.relatedEvents;
  String get noReelsFound => _t.noReelsFound;
  String get noEventsFound => _t.noEventsFound;
  String get relatedFanWorksTitle => _t.relatedFanWorksTitle;
  String get relatedGroupsTitle => _t.relatedGroupsTitle;
  String get writeReview => _t.writeReview;
  String get reviewHint => _t.reviewHint;
  String get submitRating => _t.submitRating;
  String get thisSeasonSubtitle => _t.thisSeasonSubtitle;
  String get popularSubtitle => _t.popularSubtitle;
  String get mostListed => _t.mostListed;
  String get seasonalCharacters => _t.seasonalCharacters;
  String get aggregatedResults => _t.aggregatedResults;
  String get entityGroup => _t.entityGroup;
  String get entityPerson => _t.entityPerson;
  String get entityEvent => _t.entityEvent;
  String get entityAnime => _t.entityAnime;
  String get entityFanWork => _t.entityFanWork;
  String get entityCharacter => _t.entityCharacter;
  String get entityReel => _t.entityReel;

  String get searchHomeHint => _t.searchHomeHint;
  String get searchFiltersHint => _t.searchFiltersHint;
  String get filterGenre => _t.filterGenre;
  String get filterStudio => _t.filterStudio;
  String get filterStatus => _t.filterStatus;
  String get filterAgeRating => _t.filterAgeRating;
  String get filterType => _t.filterType;
  String get filterSeason => _t.filterSeason;
  String get filterSort => _t.filterSort;
  String get filterAll => _t.filterAll;
  String get applyFilters => _t.applyFilters;
  String get resetFilters => _t.resetFilters;
  String get filters => _t.filters;
  String get resultsCount => _t.resultsCount;
  String get sortMembers => _t.sortMembers;
  String get sortTitle => _t.sortTitle;
  String get sortNewest => _t.sortNewest;
  String get sortFavorites => _t.sortFavorites;
  String get sortHighestRated => _t.sortHighestRated;
  String get sortLowestRated => _t.sortLowestRated;

  String get myLibrary => _t.myLibrary;
  String get customLists => _t.customLists;
  String get customListsTitle => _t.customListsTitle;
  String get recommendedForYou => _t.recommendedForYou;
  String get newCustomList => _t.newCustomList;
  String get customListName => _t.customListName;
  String get customListDescription => _t.customListDescription;
  String get privateList => _t.privateList;
  String get privateListHint => _t.privateListHint;
  String get customListsEmpty => _t.customListsEmpty;
  String get customListsEmptyMessage => _t.customListsEmptyMessage;
  String get createList => _t.createList;
  String get customList => _t.customList;
  String get listNameRequired => _t.listNameRequired;
  String get editList => _t.editList;
  String get deleteList => _t.deleteList;

  // ---------------------------------------------------------------------------
  // Catalog lookups
  // ---------------------------------------------------------------------------

  String genre(String? raw) => _t.genre(raw);
  String status(String? raw) => _t.status(raw);
  String get statusAiring => _t.statusAiring;
  String get statusFinished => _t.statusFinished;
  String get statusUpcoming => _t.statusUpcoming;
  String get ageAllAges => _t.ageAllAges;
  String get ageTeens => _t.ageTeens;
  String get ageAdult => _t.ageAdult;
  String source(String? raw) => _t.source(raw);
  String season(AnimeSeason value) => _t.season(value.label);
  String seasonTitle(AnimeSeason value, int year) => '${season(value)} $year';
  String typeLabel(String? raw) => _t.format(raw);
  String typeFilter(AnimeTypeFilter value) => typeLabel(value.wireValue);
  String ageRating(String? raw) => _t.ageRating(raw);
  String ageFilter(AnimeAgeFilter value) => switch (value) {
    AnimeAgeFilter.allAges => _t.ageAllAges,
    AnimeAgeFilter.teens => _t.ageTeens,
    AnimeAgeFilter.adult => _t.ageAdult,
  };
  String statusFilter(AnimeAiringFilter value) => switch (value) {
    AnimeAiringFilter.airing => _t.statusAiring,
    AnimeAiringFilter.finished => _t.statusFinished,
    AnimeAiringFilter.upcoming => _t.statusUpcoming,
  };
  String role(String? raw) => _t.role(raw);
  String relation(String? raw) => _t.relation(raw);
  String voiceLanguage(String? raw) => _t.voiceLanguage(raw);
  String characterAttribute(String? raw) => _t.characterAttribute(raw);
  String factLabel(String raw) => _t.characterAttribute(raw);

  String listStatusLabel(AnimeListStatus status) =>
      _t.personalState(status.wireValue);

  String catalog(AnimeCatalogKind kind) => switch (kind) {
    AnimeCatalogKind.trending => _t.pick('Trending', 'الرائج'),
    AnimeCatalogKind.popular => _t.pick('Most popular', 'الأكثر شعبية'),
    AnimeCatalogKind.top => _t.pick('Top rated', 'الأعلى تقييماً'),
    AnimeCatalogKind.airing => _t.statusAiring,
    AnimeCatalogKind.thisSeason => _t.pick('This season', 'هذا الموسم'),
    AnimeCatalogKind.upcoming => _t.statusUpcoming,
  };

  String customListItemCount(int count) => _t.customListItemCount(count);
  String listedCount(int count) => _t.listedCount(count);
  String characterFavoritesCount(int count) =>
      _t.characterFavoritesCount(count);
  String ratingsCount(int count) => _t.ratingsCount(count);
  String votesCount(int count) => _t.votesCount(count);
  String episodeCount(int count) => _t.episodeCount(count);

  /// Bridges the legacy English literals kept in `AnimeStrings` so older
  /// call-sites keep resolving to the same localized copy.
  String ui(String english) => switch (english) {
    AnimeStrings.hubTitle => hubTitle,
    AnimeStrings.seeAll => seeAll,
    AnimeStrings.searchHint => searchHint,
    AnimeStrings.openSearch => openSearch,
    AnimeStrings.closeSearch => closeSearch,
    AnimeStrings.nothingFound => nothingFound,
    AnimeStrings.nothingFoundMessage => nothingFoundMessage,
    AnimeStrings.unableToLoad => unableToLoad,
    AnimeStrings.checkConnection => checkConnection,
    AnimeStrings.retry => retry,
    AnimeStrings.cachedBanner => cachedBanner,
    AnimeStrings.offlineCached => offlineCached,
    AnimeStrings.genresTitle => genresTitle,
    AnimeStrings.seasonsTitle => seasonsTitle,
    AnimeStrings.charactersTitle => charactersTitle,
    AnimeStrings.synopsisTitle => synopsisTitle,
    AnimeStrings.detailsMissing => detailsMissing,
    AnimeStrings.emptyCatalog => emptyCatalog,
    AnimeStrings.endOfList => endOfList,
    AnimeStrings.favorite => favorite,
    AnimeStrings.favorited => favorited,
    AnimeStrings.trailer => trailer,
    AnimeStrings.links => links,
    AnimeStrings.copied => copied,
    AnimeStrings.share => share,
    AnimeStrings.favoriteLimit => favoriteLimit,
    AnimeStrings.libraryTitle => libraryTitle,
    AnimeStrings.libraryEmpty => libraryEmpty,
    AnimeStrings.libraryEmptyMessage => libraryEmptyMessage,
    AnimeStrings.listStatus => listStatus,
    AnimeStrings.removeFromList => removeFromList,
    AnimeStrings.rateAnime => rateAnime,
    AnimeStrings.editRating => editRating,
    AnimeStrings.communityScore => communityScore,
    AnimeStrings.malScore => malScore,
    AnimeStrings.ratingsTitle => ratingsTitle,
    AnimeStrings.popularCharactersTitle => popularCharactersTitle,
    AnimeStrings.communityStats => communityStats,
    AnimeStrings.mostListed => mostListed,
    AnimeStrings.seasonalCharacters => seasonalCharacters,
    AnimeStrings.myAnimeTitle => myAnimeTitle,
    AnimeStrings.theirAnimeTitle => theirAnimeTitle,
    AnimeStrings.reviewsTitle => reviewsTitle,
    AnimeStrings.relatedTitle => relatedTitle,
    AnimeStrings.relatedFanWorksTitle => relatedFanWorksTitle,
    AnimeStrings.relatedGroupsTitle => relatedGroupsTitle,
    AnimeStrings.writeReview => writeReview,
    AnimeStrings.reviewHint => reviewHint,
    AnimeStrings.submitRating => submitRating,
    AnimeStrings.favoriteCharacter => favoriteCharacter,
    AnimeStrings.filterGenre => filterGenre,
    AnimeStrings.filterStudio => filterStudio,
    AnimeStrings.filterStatus => filterStatus,
    AnimeStrings.filterAgeRating => filterAgeRating,
    AnimeStrings.aggregatedResults => aggregatedResults,
    AnimeStrings.entityGroup => entityGroup,
    AnimeStrings.filterType => filterType,
    AnimeStrings.filterSeason => filterSeason,
    AnimeStrings.filterSort => filterSort,
    AnimeStrings.sortMembers => sortMembers,
    AnimeStrings.sortTitle => sortTitle,
    AnimeStrings.sortNewest => sortNewest,
    AnimeStrings.sortFavorites => sortFavorites,
    AnimeStrings.searchFiltersHint => searchFiltersHint,
    AnimeStrings.noRatingsYet => noRatingsYet,
    AnimeStrings.characterAbout => characterAbout,
    AnimeStrings.characterNicknames => characterNicknames,
    AnimeStrings.characterAnime => characterAnime,
    AnimeStrings.characterManga => characterManga,
    AnimeStrings.characterVoices => characterVoices,
    AnimeStrings.characterFacts => characterFacts,
    AnimeStrings.characterMalId => characterMalId,
    AnimeStrings.characterRole => characterRole,
    AnimeStrings.loadingProfile => loadingProfile,
    AnimeStrings.malFavorites => malFavorites,
    AnimeStrings.pubgetFavorites => pubgetFavorites,
    AnimeStrings.characterRank => characterRank,
    AnimeStrings.characterYourRating => characterYourRating,
    AnimeStrings.characterReels => characterReels,
    AnimeStrings.characterDiscussions => characterDiscussions,
    AnimeStrings.characterDiscussionHint => characterDiscussionHint,
    AnimeStrings.characterDiscussionEmpty => characterDiscussionEmpty,
    AnimeStrings.characterNotFound => characterNotFound,
    AnimeStrings.post => post,
    AnimeStrings.delete => delete,
    AnimeStrings.thisSeasonSubtitle => thisSeasonSubtitle,
    AnimeStrings.popularSubtitle => popularSubtitle,
    AnimeStrings.searchHomeHint => searchHomeHint,
    AnimeStrings.customLists => customLists,
    AnimeStrings.customListTab => tabCustomList,
    AnimeStrings.newCustomList => newCustomList,
    AnimeStrings.customListName => customListName,
    AnimeStrings.customListDescription => customListDescription,
    AnimeStrings.privateList => privateList,
    AnimeStrings.privateListHint => privateListHint,
    AnimeStrings.customListsEmpty => customListsEmpty,
    AnimeStrings.customListsEmptyMessage => customListsEmptyMessage,
    AnimeStrings.createList => createList,
    AnimeStrings.customList => customList,
    AnimeStrings.addToList => addToList,
    AnimeStrings.listNameRequired => listNameRequired,
    AnimeStrings.editList => editList,
    AnimeStrings.deleteList => deleteList,
    AnimeStrings.statusAiring => statusAiring,
    AnimeStrings.statusFinished => statusFinished,
    AnimeStrings.statusUpcoming => statusUpcoming,
    AnimeStrings.ageAllAges => ageAllAges,
    AnimeStrings.ageTeens => ageTeens,
    AnimeStrings.ageAdult => ageAdult,
    'Details' => detailsSection,
    _ => catalogPhrase(english),
  };

  String catalogPhrase(String english) => switch (english) {
    'Trending' => catalog(AnimeCatalogKind.trending),
    'Most popular' => catalog(AnimeCatalogKind.popular),
    'Top rated' => catalog(AnimeCatalogKind.top),
    'Currently airing' => catalog(AnimeCatalogKind.airing),
    'This season' => catalog(AnimeCatalogKind.thisSeason),
    'Upcoming' => catalog(AnimeCatalogKind.upcoming),
    _ => typeStatusOrSelf(english),
  };

  String pageTitle(String english) {
    final seasonYear = RegExp(
      r'^(Winter|Spring|Summer|Fall) (\d{4})$',
    ).firstMatch(english.trim());
    if (seasonYear != null) {
      final parsed = AnimeSeason.tryParse(seasonYear.group(1));
      if (parsed != null) {
        return seasonTitle(parsed, int.parse(seasonYear.group(2)!));
      }
    }
    return ui(english);
  }

  /// Tries format, airing status, season, then genre before giving up and
  /// echoing the original API term back.
  String typeStatusOrSelf(String english) {
    final typed = typeLabel(english);
    if (typed != english && typed.isNotEmpty) return typed;
    final stated = status(english);
    if (stated != english && stated.isNotEmpty) return stated;
    final seasonal = _t.season(english);
    if (seasonal != english && seasonal.isNotEmpty) return seasonal;
    final genred = genre(english);
    if (genred != english && genred.isNotEmpty) return genred;
    return english;
  }

  String subtitle(Anime anime) {
    final parts = <String>[
      if (anime.type != null && anime.type!.isNotEmpty) typeLabel(anime.type),
      if (anime.year != null) '${anime.year}',
      if (anime.season != null) season(anime.season!),
    ];
    return parts.join(' · ');
  }

  String meta(Anime anime) {
    final parts = <String>[
      if (anime.type != null && anime.type!.isNotEmpty) typeLabel(anime.type),
      if (anime.status != null && anime.status!.isNotEmpty)
        status(anime.status),
      if (anime.year != null) '${anime.year}',
      if (anime.season != null) season(anime.season!),
    ];
    return parts.join(' · ');
  }
}
