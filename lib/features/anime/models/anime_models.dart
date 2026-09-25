enum AnimeSeason {
  winter,
  spring,
  summer,
  fall;

  String get label => switch (this) {
    AnimeSeason.winter => 'Winter',
    AnimeSeason.spring => 'Spring',
    AnimeSeason.summer => 'Summer',
    AnimeSeason.fall => 'Fall',
  };

  String get apiValue => name;

  static AnimeSeason? tryParse(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'winter' => AnimeSeason.winter,
      'spring' => AnimeSeason.spring,
      'summer' => AnimeSeason.summer,
      'fall' || 'autumn' => AnimeSeason.fall,
      _ => null,
    };
  }

  static AnimeSeason fromDate(DateTime date) {
    return switch (date.month) {
      1 || 2 || 3 => AnimeSeason.winter,
      4 || 5 || 6 => AnimeSeason.spring,
      7 || 8 || 9 => AnimeSeason.summer,
      _ => AnimeSeason.fall,
    };
  }
}

enum AnimeTagKind { genre, theme, demographic, explicit, other }

enum AnimeCatalogKind {
  trending,
  popular,
  top,
  airing,
  thisSeason,
  upcoming;

  String get label => switch (this) {
    AnimeCatalogKind.trending => 'Trending',
    AnimeCatalogKind.popular => 'Most popular',
    AnimeCatalogKind.top => 'Top rated',
    AnimeCatalogKind.airing => 'Currently airing',
    AnimeCatalogKind.thisSeason => 'This season',
    AnimeCatalogKind.upcoming => 'Upcoming',
  };

  String get routeValue => name;

  /// Hub home is exactly this season and most popular.
  static const hubHome = <AnimeCatalogKind>[
    AnimeCatalogKind.thisSeason,
    AnimeCatalogKind.popular,
  ];
}

enum AnimeSearchSort { members, title, newest, favorites }

enum AnimeTypeFilter { tv, movie, ova, special, ona }

enum AnimeAiringFilter { airing, finished, upcoming }

enum AnimeAgeFilter { allAges, teens, adult }

final class AnimeSearchFilter {
  const AnimeSearchFilter({
    this.text = '',
    this.genreId,
    this.studioId,
    this.type,
    this.season,
    this.year,
    this.airing,
    this.ageRating,
    this.sort = AnimeSearchSort.members,
  });

  final String text;
  final String? genreId;
  final String? studioId;
  final AnimeTypeFilter? type;
  final AnimeSeason? season;
  final int? year;
  final AnimeAiringFilter? airing;
  final AnimeAgeFilter? ageRating;
  final AnimeSearchSort sort;

  bool get hasQuery => text.trim().isNotEmpty;
  bool get hasNonTextConstraints =>
      (genreId != null && genreId!.isNotEmpty) ||
      (studioId != null && studioId!.isNotEmpty) ||
      type != null ||
      (season != null && year != null) ||
      airing != null ||
      ageRating != null;
  bool get hasConstraints => hasQuery || hasNonTextConstraints;

  bool matchesCatalog(Anime anime) {
    if (type != null) {
      final animeType = anime.type?.trim().toLowerCase();
      if (animeType != null &&
          animeType.isNotEmpty &&
          animeType != type!.name) {
        return false;
      }
    }
    final genre = genreId?.trim();
    if (genre != null && genre.isNotEmpty && anime.genres.isNotEmpty) {
      if (!anime.genres.any((item) => item.id == genre)) return false;
    }
    if (season != null && anime.season != null && anime.season != season) {
      return false;
    }
    if (year != null && anime.year != null && anime.year != year) {
      return false;
    }
    final statusFilter = airing;
    if (statusFilter != null) {
      final status = anime.status?.toLowerCase() ?? '';
      final matching = switch (statusFilter) {
        AnimeAiringFilter.airing =>
          anime.airing == true || status.contains('currently'),
        AnimeAiringFilter.finished =>
          (anime.airing == false && status.isNotEmpty) ||
            status.contains('finished'),
        AnimeAiringFilter.upcoming => status.contains('not yet'),
      };
      if (!matching) return false;
    }
    final age = ageRating;
    if (age != null) {
      if (anime.ageRating != age) return false;
    }
    return true;
  }

  AnimePage constrain(AnimePage page) {
    final items = page.items.where(matchesCatalog).toList(growable: false);
    if (items.length == page.items.length) return page;
    return page.copyWith(items: items);
  }

  AnimeSearchFilter copyWith({
    String? text,
    String? genreId,
    bool clearGenre = false,
    String? studioId,
    bool clearStudio = false,
    AnimeTypeFilter? type,
    bool clearType = false,
    AnimeSeason? season,
    bool clearSeason = false,
    int? year,
    bool clearYear = false,
    AnimeAiringFilter? airing,
    bool clearAiring = false,
    AnimeAgeFilter? ageRating,
    bool clearAgeRating = false,
    AnimeSearchSort? sort,
  }) => AnimeSearchFilter(
    text: text ?? this.text,
    genreId: clearGenre ? null : genreId ?? this.genreId,
    studioId: clearStudio ? null : studioId ?? this.studioId,
    type: clearType ? null : type ?? this.type,
    season: clearSeason ? null : season ?? this.season,
    year: clearYear ? null : year ?? this.year,
    airing: clearAiring ? null : airing ?? this.airing,
    ageRating: clearAgeRating ? null : ageRating ?? this.ageRating,
    sort: sort ?? this.sort,
  );
}

final class AnimeImages {
  const AnimeImages({this.thumbnailUrl, this.largeUrl});

  final String? thumbnailUrl;
  final String? largeUrl;

  String? get displayUrl => thumbnailUrl ?? largeUrl;
}

final class AnimeExternalLink {
  const AnimeExternalLink({required this.label, required this.url});

  final String label;
  final String url;
}

final class AnimeGenre {
  const AnimeGenre({
    required this.id,
    required this.name,
    this.kind = AnimeTagKind.genre,
    this.count,
  });

  final String id;
  final String name;
  final AnimeTagKind kind;
  final int? count;

  bool get isBrowsable =>
      kind == AnimeTagKind.genre ||
      kind == AnimeTagKind.theme ||
      kind == AnimeTagKind.demographic;
}

final class AnimeStudio {
  const AnimeStudio({required this.id, required this.name, this.count});

  final String id;
  final String name;
  final int? count;
}

final class AnimeRelated {
  const AnimeRelated({
    required this.id,
    required this.title,
    required this.relation,
    this.type,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String relation;
  final String? type;
  final String? imageUrl;
}

final class AnimeSeasonYear {
  const AnimeSeasonYear({required this.year, required this.seasons});

  final int year;
  final List<AnimeSeason> seasons;
}

final class VoiceActor {
  const VoiceActor({
    required this.id,
    required this.name,
    this.language,
    this.imageUrl,
    this.animeTitle,
  });

  final String id;
  final String name;
  final String? language;
  final String? imageUrl;
  final String? animeTitle;
}

final class CharacterAppearance {
  const CharacterAppearance({
    required this.id,
    required this.title,
    this.role,
    this.imageUrl,
    this.url,
  });

  final String id;
  final String title;
  final String? role;
  final String? imageUrl;
  final String? url;
}

final class AnimeCharacter {
  const AnimeCharacter({
    required this.id,
    required this.name,
    this.imageUrl,
    this.role,
    this.favorites,
    this.url,
    this.about,
    this.nameKanji,
    this.nicknames = const <String>[],
    this.voiceActors = const <VoiceActor>[],
    this.animeography = const <CharacterAppearance>[],
    this.mangaography = const <CharacterAppearance>[],
  });

  final String id;
  final String name;
  final String? imageUrl;
  final String? role;
  final int? favorites;
  final String? url;
  final String? about;
  final String? nameKanji;
  final List<String> nicknames;
  final List<VoiceActor> voiceActors;
  final List<CharacterAppearance> animeography;
  final List<CharacterAppearance> mangaography;

  AnimeCharacter copyWith({
    String? name,
    String? about,
    String? nameKanji,
    List<String>? nicknames,
    String? imageUrl,
    String? role,
    int? favorites,
    String? url,
    List<VoiceActor>? voiceActors,
    List<CharacterAppearance>? animeography,
    List<CharacterAppearance>? mangaography,
  }) => AnimeCharacter(
    id: id,
    name: name ?? this.name,
    imageUrl: imageUrl ?? this.imageUrl,
    role: role ?? this.role,
    favorites: favorites ?? this.favorites,
    url: url ?? this.url,
    about: about ?? this.about,
    nameKanji: nameKanji ?? this.nameKanji,
    nicknames: nicknames ?? this.nicknames,
    voiceActors: voiceActors ?? this.voiceActors,
    animeography: animeography ?? this.animeography,
    mangaography: mangaography ?? this.mangaography,
  );

  AnimeCharacter mergeDetails(AnimeCharacter details) {
    return copyWith(
      name: details.name,
      about: details.about ?? about,
      nameKanji: details.nameKanji ?? nameKanji,
      nicknames: details.nicknames.isNotEmpty ? details.nicknames : nicknames,
      imageUrl: details.imageUrl ?? imageUrl,
      favorites: details.favorites ?? favorites,
      url: details.url ?? url,
      voiceActors: details.voiceActors.isNotEmpty
          ? details.voiceActors
          : voiceActors,
      animeography: details.animeography.isNotEmpty
          ? details.animeography
          : animeography,
      mangaography: details.mangaography.isNotEmpty
          ? details.mangaography
          : mangaography,
    );
  }

  bool get hasFullProfile =>
      (about != null && about!.trim().isNotEmpty) ||
      nameKanji != null ||
      nicknames.isNotEmpty ||
      animeography.isNotEmpty ||
      mangaography.isNotEmpty;
}

final class CharacterAboutSections {
  const CharacterAboutSections({required this.facts, required this.narrative});

  final List<({String label, String value})> facts;
  final String narrative;

  static CharacterAboutSections parse(String? about) {
    final text = about?.trim() ?? '';
    if (text.isEmpty) {
      return const CharacterAboutSections(
        facts: <({String label, String value})>[],
        narrative: '',
      );
    }
    final facts = <({String label, String value})>[];
    final narrative = <String>[];
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        if (narrative.isNotEmpty && narrative.last.isNotEmpty) {
          narrative.add('');
        }
        continue;
      }
      final separator = line.indexOf(':');
      if (separator > 0 && separator < 40 && separator < line.length - 1) {
        final label = line.substring(0, separator).trim();
        final value = line.substring(separator + 1).trim();
        if (label.isNotEmpty &&
            value.isNotEmpty &&
            !label.contains('http') &&
            label.length <= 40) {
          facts.add((label: label, value: value));
          continue;
        }
      }
      final labeled = RegExp(
        r'^(Age|Birthday|Birth ?date|Height|Weight|Blood type|Hair color|Eye color|Gender|Species|Affiliation|Occupation|Arabic(?: name)?|الاسم(?: العربي)?)\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (labeled != null) {
        facts.add((label: labeled.group(1)!, value: labeled.group(2)!.trim()));
        continue;
      }
      narrative.add(line);
    }
    return CharacterAboutSections(
      facts: List<({String label, String value})>.unmodifiable(facts),
      narrative: narrative.join('\n').trim(),
    );
  }

  String? valueFor(Set<String> labels) {
    final wanted = labels.map((item) => item.toLowerCase()).toSet();
    for (final fact in facts) {
      if (wanted.contains(fact.label.toLowerCase().trim())) {
        return fact.value;
      }
    }
    return null;
  }

  String? get age => valueFor(const {'age'});
  String? get birthday =>
      valueFor(const {'birthday', 'birth date', 'birthdate'});
  String? get height => valueFor(const {'height'});
  String? get weight => valueFor(const {'weight'});
  String? get arabicName =>
      valueFor(const {'arabic', 'arabic name', 'الاسم', 'الاسم العربي'});
}

final class Anime {
  const Anime({
    required this.id,
    required this.title,
    this.titleArabic,
    this.alternativeTitles = const <String>[],
    this.synopsis,
    this.type,
    this.status,
    this.score,
    this.rank,
    this.popularity,
    this.episodes,
    this.duration,
    this.startDate,
    this.endDate,
    this.season,
    this.year,
    this.genres = const <AnimeGenre>[],
    this.studios = const <String>[],
    this.producers = const <String>[],
    this.relations = const <AnimeRelated>[],
    this.source,
    this.rating,
    this.images = const AnimeImages(),
    this.trailerUrl,
    this.externalLinks = const <AnimeExternalLink>[],
    this.nextEpisodeLabel,
    this.airing,
    this.fromCache = false,
  });

  final String id;
  final String title;
  final String? titleArabic;
  final List<String> alternativeTitles;
  final String? synopsis;
  final String? type;
  final String? status;
  final double? score;
  final int? rank;
  final int? popularity;
  final int? episodes;
  final String? duration;
  final DateTime? startDate;
  final DateTime? endDate;
  final AnimeSeason? season;
  final int? year;
  final List<AnimeGenre> genres;
  final List<String> studios;
  final List<String> producers;
  final List<AnimeRelated> relations;
  final String? source;
  final String? rating;
  final AnimeImages images;
  final String? trailerUrl;
  final List<AnimeExternalLink> externalLinks;
  final String? nextEpisodeLabel;
  final bool? airing;
  final bool fromCache;

  String get subtitle {
    final parts = <String>[
      if (type != null && type!.isNotEmpty) type!,
      if (year != null) '$year',
      if (season != null) season!.label,
    ];
    return parts.join(' · ');
  }

  AnimeAgeFilter get ageRating {
    final raw = rating?.toLowerCase() ?? '';
    if (raw.isEmpty) return AnimeAgeFilter.allAges;
    if (raw.startsWith('g -') || raw.startsWith('pg - children')) {
      return AnimeAgeFilter.allAges;
    }
    if (raw.startsWith('pg-13')) {
      return AnimeAgeFilter.teens;
    }
    if (raw.startsWith('r -') || raw.startsWith('r+') || raw.startsWith('rx')) {
      return AnimeAgeFilter.adult;
    }
    // Default for unrecognized ratings (PG, etc.)
    return AnimeAgeFilter.allAges;
  }

  Anime copyWith({
    bool? fromCache,
    String? titleArabic,
  }) => Anime(
    id: id,
    title: title,
    titleArabic: titleArabic ?? this.titleArabic,
    alternativeTitles: alternativeTitles,
    synopsis: synopsis,
    type: type,
    status: status,
    score: score,
    rank: rank,
    popularity: popularity,
    episodes: episodes,
    duration: duration,
    startDate: startDate,
    endDate: endDate,
    season: season,
    year: year,
    genres: genres,
    studios: studios,
    producers: producers,
    relations: relations,
    source: source,
    rating: rating,
    images: images,
    trailerUrl: trailerUrl,
    externalLinks: externalLinks,
    nextEpisodeLabel: nextEpisodeLabel,
    airing: airing,
    fromCache: fromCache ?? this.fromCache,
  );
}

final class AnimePage {
  const AnimePage({
    required this.items,
    this.page = 1,
    this.hasNextPage = false,
    this.fromCache = false,
  });

  final List<Anime> items;
  final int page;
  final bool hasNextPage;
  final bool fromCache;

  static const empty = AnimePage(items: <Anime>[]);

  AnimePage copyWith({
    List<Anime>? items,
    int? page,
    bool? hasNextPage,
    bool? fromCache,
  }) => AnimePage(
    items: items ?? this.items,
    page: page ?? this.page,
    hasNextPage: hasNextPage ?? this.hasNextPage,
    fromCache: fromCache ?? this.fromCache,
  );
}

abstract final class AnimeStrings {
  static const hubTitle = 'Anime Hub';
  static const seeAll = 'See all';
  static const searchHint = 'Search anime';
  static const openSearch = 'Search';
  static const closeSearch = 'Close search';
  static const ratingAppBadge = 'A';
  static const ratingMalBadge = 'M';
  static const searchHomeHint =
      'Search groups, people, events, anime, and Fan Works';
  static const nothingFound = 'No Anime Found';
  static const nothingFoundMessage = 'Try another title or browse the catalog.';
  static const unableToLoad = 'Unable to load anime right now.';
  static const checkConnection = 'Please check your connection and try again.';
  static const retry = 'Retry';
  static const cachedBanner = 'Showing cached data';
  static const offlineCached = 'You are offline. Showing cached data.';
  static const genresTitle = 'Browse by genre';
  static const seasonsTitle = 'Browse by season';
  static const charactersTitle = 'Characters';
  static const synopsisTitle = 'Synopsis';
  static const detailsMissing = 'This anime could not be found.';
  static const emptyCatalog = 'Nothing in this list yet.';
  static const endOfList = 'You have reached the end.';
  static const favorite = 'Favorite';
  static const favorited = 'In favorites';
  static const trailer = 'Trailer';
  static const links = 'External links';
  static const copied = 'Link copied';
  static const share = 'Share anime';
  static const favoriteLimit = 'You can save up to 50 favorite anime.';
  static const libraryTitle = 'My anime lists';
  static const libraryEmpty = 'No titles in this list yet';
  static const libraryEmptyMessage =
      'Add anime from a details page. Lists are saved on the server.';
  static const listStatus = 'Your list';
  static const removeFromList = 'Remove from list';
  static const rateAnime = 'Rate this anime';
  static const editRating = 'Edit rating';
  static const communityScore = 'Pubget score';
  static const malScore = 'MAL';
  static const ratingsTitle = 'Ratings';
  static const popularCharactersTitle = 'Popular characters';
  static const communityStats = 'Community stats';
  static const mostListed = 'Most listed in user lists';
  static const seasonalCharacters = 'Characters of the season';
  static const myAnimeTitle = 'My Anime';
  static const theirAnimeTitle = 'Anime';
  static const reviewsTitle = 'Reviews';
  static const relatedTitle = 'Related';
  static const relatedFanWorksTitle = 'Related Fan Works';
  static const relatedGroupsTitle = 'Related groups';
  static const writeReview = 'Write a review';
  static const reviewHint = 'Share what you thought (optional)';
  static const submitRating = 'Save rating';
  static const favoriteCharacter = 'Favorite character';
  static const filterGenre = 'Genre';
  static const filterStudio = 'Studio';
  static const filterStatus = 'Status';
  static const filterAgeRating = 'Age rating';
  static const statusAiring = 'Airing';
  static const statusFinished = 'Finished';
  static const statusUpcoming = 'Upcoming';
  static const ageAllAges = 'All ages';
  static const ageTeens = 'Teens 13+';
  static const ageAdult = '17+';
  static const aggregatedResults = 'More results across Pubget';
  static const entityGroup = 'Group';
  static const entityPerson = 'Person';
  static const entityEvent = 'Event';
  static const entityAnime = 'Anime';
  static const entityFanWork = 'Fan Work';
  static const entityCharacter = 'Character';
  static const entityReel = 'Reel';
  static const tabInfo = 'Info';
  static const tabCharacters = 'Characters';
  static const tabRelated = 'Related';
  static const favoriteCharactersTab = 'Favorite characters';
  static const favoriteAnimeTab = 'Favorite anime';
  static const listsTab = 'Lists';
  static const ratingsTab = 'Ratings';
  static const reportLabel = 'Report';
  static const reportReview = 'Report review';
  static const relatedReels = 'Related reels';
  static const relatedEvents = 'Related events';
  static const noReelsFound = 'No reels found';
  static const noEventsFound = 'No events found';
  static const myLibrary = 'My library';
  static const customListsTitle = 'Custom lists';
  static const recommendedForYou = 'Recommended for you';
  static const filterType = 'Type';
  static const filterSeason = 'Season';
  static const filterSort = 'Sort';
  static const sortMembers = 'Popularity';
  static const sortTitle = 'Title';
  static const sortNewest = 'Newest';
  static const sortFavorites = 'Most favorited';
  static const searchFiltersHint =
      'Search by name, or filter by season and genre.';
  static const noRatingsYet = 'Be the first to rate this anime on Pubget.';
  static const characterAbout = 'About';
  static const characterNicknames = 'Nicknames';
  static const characterAnime = 'Anime appearances';
  static const characterManga = 'Manga appearances';
  static const characterVoices = 'Voice actors';
  static const characterFacts = 'Profile facts';
  static const characterMalId = 'MAL ID';
  static const characterRole = 'Role';
  static const loadingProfile = 'Loading full profile…';
  static const malFavorites = 'MAL favorites';
  static const pubgetFavorites = 'Pubget favorites';
  static const thisSeasonSubtitle =
      'Airing this cour — posters, scores, and studios.';
  static const popularSubtitle = 'The titles everyone is watching and saving.';
  static const characterRank = 'Community rank';
  static const characterYourRating = 'Your rating';
  static const characterReels = 'Related reels';
  static const characterDiscussions = 'Community discussion';
  static const characterDiscussionHint =
      'Share your thoughts about this character';
  static const characterDiscussionEmpty =
      'No discussion yet. Start the conversation.';
  static const characterNotFound = 'This character could not be found.';
  static const post = 'Post';
  static const delete = 'Delete';
  static const customLists = 'Custom lists';
  static const customListTab = 'Custom';
  static const newCustomList = 'New list';
  static const customListName = 'List name';
  static const customListDescription = 'Description (optional)';
  static const privateList = 'Private';
  static const privateListHint = 'Only you can see this list';
  static const customListsEmpty = 'No custom lists yet';
  static const customListsEmptyMessage =
      'Create your own themed lists to organize anime your way.';
  static const createList = 'Create list';
  static const customList = 'Custom list';
  static const addToList = 'Add to list';
  static const listNameRequired = 'A list name is required.';
  static const editList = 'Edit list';
  static const deleteList = 'Delete list';
}
