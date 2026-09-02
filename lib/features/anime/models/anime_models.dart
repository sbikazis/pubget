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
    AnimeCatalogKind.popular => 'Popular',
    AnimeCatalogKind.top => 'Top rated',
    AnimeCatalogKind.airing => 'Currently airing',
    AnimeCatalogKind.thisSeason => 'This season',
    AnimeCatalogKind.upcoming => 'Upcoming',
  };

  String get routeValue => name;
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
  });

  final String id;
  final String name;
  final String? language;
  final String? imageUrl;
}

final class AnimeCharacter {
  const AnimeCharacter({
    required this.id,
    required this.name,
    this.imageUrl,
    this.role,
    this.favorites,
    this.url,
    this.voiceActors = const <VoiceActor>[],
  });

  final String id;
  final String name;
  final String? imageUrl;
  final String? role;
  final int? favorites;
  final String? url;
  final List<VoiceActor> voiceActors;
}

final class Anime {
  const Anime({
    required this.id,
    required this.title,
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
    this.source,
    this.images = const AnimeImages(),
    this.trailerUrl,
    this.externalLinks = const <AnimeExternalLink>[],
    this.nextEpisodeLabel,
    this.airing,
    this.fromCache = false,
  });

  final String id;
  final String title;
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
  final String? source;
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

  Anime copyWith({bool? fromCache}) => Anime(
    id: id,
    title: title,
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
    source: source,
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
  static const searchHomeHint =
      'Search groups, people, events, anime, and Fan Works';
  static const nothingFound = 'Nothing found';
  static const nothingFoundMessage = 'Try another title or browse the catalog.';
  static const unableToLoad = 'Unable to load anime right now.';
  static const checkConnection =
      'Please check your connection and try again.';
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
}
