import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../data/anilist_mapper.dart';
import '../data/anime_http_client.dart';
import '../models/anime_models.dart';
import 'anime_repository.dart';

/// Fetches the anime catalog from AniList's public GraphQL endpoint. It is the
/// alternative provider: the hub keeps working when the primary provider
/// (Jikan/MyAnimeList) is unreachable. Ids are AniList ids, except that
/// numeric (Mal) ids are resolved through the companion `idMal` field so the
/// local Firestore cache and community favorites keep working across either
/// provider.
final class AniListAnimeRepository implements AnimeRepository {
  AniListAnimeRepository({required AnimeHttpClient http, Uri? baseUri})
    : _http = http,
      _baseUri = baseUri ?? Uri.parse('https://graphql.anilist.co');

  static const String mediaFields = '''
id
title { romaji english native userPreferred }
description
format
status
episodes
duration
startDate { year month day }
endDate { year month day }
season
averageScore
popularity
favourites
coverImage { extraLarge large medium }
bannerImage
genres
studios { nodes { id name isAnimationStudio } }
relations { edges { relationType node { id type format title { romaji english } coverImage { large medium } } } }
source
nextAiringEpisode { episode timeUntilAiring }
trailer { id site }
externalLinks { site url }
isAdult''';

  final AnimeHttpClient _http;
  final Uri _baseUri;

  @override
  Future<Result<AnimePage>> searchAnime(
    String query, {
    int page = 1,
    int limit = 20,
    AnimeSearchFilter? filter,
  }) async {
    final resolved = (filter ?? const AnimeSearchFilter()).copyWith(
      text: query,
    );
    if (!resolved.hasConstraints) {
      return const Success(AnimePage.empty);
    }
    final text = resolved.text.trim();
    if (text.isEmpty && resolved.year != null && resolved.season != null) {
      return _page(
        extra: <String, Object?>{
          'season': resolved.season!.name.toUpperCase(),
          'seasonYear': resolved.year,
        },
        page: page,
        limit: limit,
        sort: _sort(resolved.sort),
      );
    }
    return _page(
      extra: _searchFilters(resolved),
      template: <String, Object?>{if (text.isNotEmpty) 'search': text},
      page: page,
      limit: limit,
      sort: text.isNotEmpty ? 'SEARCH_MATCH' : _sort(resolved.sort),
    );
  }

  @override
  Future<Result<Anime>> getAnimeDetails(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      return const FailureResult(ValidationError('Anime id is required.'));
    }
    return _object(normalized);
  }

  @override
  Future<Result<AnimePage>> getTrending({int page = 1, int limit = 20}) =>
      _page(
        extra: const <String, Object?>{},
        page: page,
        limit: limit,
        sort: 'TRENDING_DESC',
      );

  @override
  Future<Result<AnimePage>> getPopular({int page = 1, int limit = 20}) => _page(
    extra: const <String, Object?>{},
    page: page,
    limit: limit,
    sort: 'POPULARITY_DESC',
  );

  @override
  Future<Result<AnimePage>> getTop({int page = 1, int limit = 20}) => _page(
    extra: const <String, Object?>{},
    page: page,
    limit: limit,
    sort: 'SCORE_DESC',
  );

  @override
  Future<Result<AnimePage>> getAiring({int page = 1, int limit = 20}) => _page(
    extra: const <String, Object?>{'status': 'RELEASING'},
    page: page,
    limit: limit,
    sort: 'POPULARITY_DESC',
  );

  @override
  Future<Result<AnimePage>> getUpcoming({int page = 1, int limit = 20}) =>
      _page(
        extra: const <String, Object?>{'status': 'NOT_YET_RELEASED'},
        page: page,
        limit: limit,
        sort: 'POPULARITY_DESC',
      );

  @override
  Future<Result<AnimePage>> getThisSeason({int page = 1, int limit = 20}) {
    final now = DateTime.now();
    return _page(
      extra: <String, Object?>{
        'status': 'RELEASING',
        'season': AnimeSeason.fromDate(now).name.toUpperCase(),
        'seasonYear': now.year,
      },
      page: page,
      limit: limit,
      sort: 'POPULARITY_DESC',
    );
  }

  @override
  Future<Result<List<Anime>>> getAnimeSummaries(
    List<String> ids, {
    int chunkSize = 100,
  }) async {
    final cleaned = <int>{
      for (final id in ids)
        if (int.tryParse(id.trim()) case final int value) value,
    };
    if (cleaned.isEmpty) return const Success(<Anime>[]);
    final collected = <Anime>[];
    var firstFailure = <Failure>[];
    final idsList = cleaned.toList();
    final size = chunkSize.clamp(1, 50);
    for (var index = 0; index < idsList.length; index += size) {
      final chunk = idsList.sublist(
        index,
        (index + size).clamp(0, idsList.length),
      );
      final query =
          '''
query Summaries(\$_ids: [Int]) {
  Page(perPage: ${chunk.length}) {
    media(id_in: \$_ids, type: ANIME) {
      id
      idMal
      title { romaji english native }
      format
      status
      season
      seasonYear
      averageScore
      popularity
      episodes
      genres
      coverImage { extraLarge large medium }
      bannerImage
      trailer { site id }
    }
  }
}''';
      final result = await _graphQl(query, <String, dynamic>{'ids': chunk});
      result.fold(
        onSuccess: (json) {
          try {
            final media = _map(_map(json['data'])?['Page'])?['media'];
            collected.addAll(
              mapAniListAnimeList(media as List<Object?>? ?? const <Object?>[]),
            );
          } on Object catch (error) {
            firstFailure.add(NetworkError('$error'));
          }
        },
        onFailure: (failure) => firstFailure.add(failure),
      );
    }
    if (collected.isEmpty && firstFailure.isNotEmpty) {
      return FailureResult<List<Anime>>(firstFailure.first);
    }
    return Success<List<Anime>>(List<Anime>.unmodifiable(collected));
  }

  @override
  Future<Result<List<AnimeCharacter>>> getCharacters(String animeId) async {
    final normalized = animeId.trim();
    if (normalized.isEmpty) {
      return const FailureResult(ValidationError('Anime id is required.'));
    }
    final query = '''
query Characters(\$_id: Int, \$_idMal: Int) {
  Media(id: \$_id, idMal: \$_idMal) {
    characters(page: 1, perPage: 40, sort: [FAVOURITES_DESC]) {
      nodes {
        id
        name { full native }
        image { large medium }
        role
        description
        favourites
        voiceActors(sort: [RELEVANCE]) {
          nodes { id name { full } language image { medium } }
        }
      }
    }
  }
}''';
    final payload = await _graphQl(query, _idVariables(normalized));
    return payload.fold(
      onSuccess: (json) {
        try {
          final characters = mapAniListCharacters(
            _nodesOf(_map(_map(json['data'])?['Media'])?['characters']),
          );
          return Success<List<AnimeCharacter>>(
            List<AnimeCharacter>.unmodifiable(characters),
          );
        } on Object catch (error) {
          return animeHttpFailure<List<AnimeCharacter>>(error);
        }
      },
      onFailure: FailureResult<List<AnimeCharacter>>.new,
    );
  }

  @override
  Future<Result<AnimeCharacter>> getCharacterDetails(String characterId) async {
    final normalized = characterId.trim();
    if (normalized.isEmpty) {
      return const FailureResult(ValidationError('Character id is required.'));
    }
    final query = '''
query Character(\$_id: Int, \$_idMal: Int) {
  Character(id: \$_id, idMal: \$_idMal) {
    id
    name { full native }
    image { large medium }
    description
    favourites
    media(page: 1, perPage: 25, sort: [POPULARITY_DESC]) {
      nodes {
        id
        type
        title { romaji english userPreferred }
        coverImage { large medium }
      }
    }
  }
}''';
    final payload = await _graphQl(query, _idVariables(normalized));
    return payload.fold(
      onSuccess: (json) {
        try {
          final map = _map(_map(json['data'])?['Character']);
          final item = map == null ? null : mapAniListCharacter(map);
          if (item == null) {
            return const FailureResult(
              NotFoundError('This character could not be found.'),
            );
          }
          return Success<AnimeCharacter>(item);
        } on Object catch (error) {
          return animeHttpFailure<AnimeCharacter>(error);
        }
      },
      onFailure: FailureResult<AnimeCharacter>.new,
    );
  }

  @override
  Future<Result<List<AnimeGenre>>> getGenres() async {
    final payload = await _graphQl('query { GenreCollection }', null);
    return payload.fold(
      onSuccess: (json) {
        try {
          final genres = _map(json['data'])?['GenreCollection'];
          if (genres is! List) return const Success(<AnimeGenre>[]);
          final items = mapAniListGenres(
            genres,
          ).where((genre) => genre.kind == AnimeTagKind.genre).toList();
          return Success<List<AnimeGenre>>(
            List<AnimeGenre>.unmodifiable(items),
          );
        } on Object catch (error) {
          return animeHttpFailure<List<AnimeGenre>>(error);
        }
      },
      onFailure: FailureResult<List<AnimeGenre>>.new,
    );
  }

  @override
  Future<Result<AnimePage>> getByGenre(
    String genreId, {
    int page = 1,
    int limit = 20,
  }) async {
    final genre = genreId.trim();
    if (genre.isEmpty) {
      return const Success(AnimePage.empty);
    }
    return _page(
      extra: <String, Object?>{
        'genre_in': <String>[genre],
      },
      page: page,
      limit: limit,
      sort: 'POPULARITY_DESC',
    );
  }

  @override
  Future<Result<List<AnimeStudio>>> getStudios({int limit = 25}) async {
    final payload = await _graphQl(
      '''
query Studios(\$page: Int, \$perPage: Int) {
  Page(page: \$page, perPage: \$perPage) {
    media(type: ANIME, isAdult: false, sort: [POPULARITY_DESC]) {
      studios { nodes { id name isAnimationStudio } }
    }
  }
}''',
      const <String, Object?>{'page': 1, 'perPage': 60},
    );
    return payload.fold(
      onSuccess: (json) {
        try {
          final media = _map(_map(json['data'])?['Page'])?['media'];
          final studios = <AnimeStudio>[];
          final seen = <String>{};
          if (media is List) {
            for (final entry in media) {
              for (final node in _nodesOf(_map(entry)?['studios'])) {
                final id = anilistIdOf(node['id']);
                final name = _string(node['name']);
                if (id == null || name == null || name.isEmpty) continue;
                if (!seen.add(id)) continue;
                studios.add(AnimeStudio(id: id, name: name));
                if (studios.length >= limit) break;
              }
              if (studios.length >= limit) break;
            }
          }
          return Success<List<AnimeStudio>>(
            List<AnimeStudio>.unmodifiable(studios),
          );
        } on Object catch (error) {
          return animeHttpFailure<List<AnimeStudio>>(error);
        }
      },
      onFailure: FailureResult<List<AnimeStudio>>.new,
    );
  }

  @override
  Future<Result<AnimePage>> getByStudio(
    String studioId, {
    int page = 1,
    int limit = 20,
  }) async {
    final id = int.tryParse(studioId.trim());
    if (id == null) return const Success(AnimePage.empty);
    return _page(
      extra: <String, Object?>{'studioId': id},
      page: page,
      limit: limit,
      sort: 'POPULARITY_DESC',
    );
  }

  @override
  Future<Result<List<AnimeSeasonYear>>> getAvailableSeasons() async {
    final now = DateTime.now();
    final years = <AnimeSeasonYear>[];
    final allSeasons = const <AnimeSeason>[
      AnimeSeason.winter,
      AnimeSeason.spring,
      AnimeSeason.summer,
      AnimeSeason.fall,
    ];
    for (var year = now.year - 2; year <= now.year + 1; year++) {
      if (year == now.year + 1) {
        final upcoming = <AnimeSeason>[];
        final start = AnimeSeason.fromDate(now).index;
        for (var i = 0; i < allSeasons.length; i++) {
          if (i >= start) upcoming.add(allSeasons[i]);
        }
        years.add(
          AnimeSeasonYear(
            year: year,
            seasons: List<AnimeSeason>.unmodifiable(upcoming),
          ),
        );
      } else {
        years.add(AnimeSeasonYear(year: year, seasons: allSeasons));
      }
    }
    years.sort((a, b) => b.year.compareTo(a.year));
    return Success(List<AnimeSeasonYear>.unmodifiable(years));
  }

  @override
  Future<Result<AnimePage>> getBySeason({
    required int year,
    required AnimeSeason season,
    int page = 1,
    int limit = 20,
  }) => _page(
    extra: <String, Object?>{
      'season': season.name.toUpperCase(),
      'seasonYear': year,
    },
    page: page,
    limit: limit,
    sort: 'POPULARITY_DESC',
  );

  Future<Result<AnimePage>> _page({
    required Map<String, Object?> extra,
    Map<String, Object?>? template,
    required int page,
    required int limit,
    required String sort,
  }) async {
    final variables = <String, Object?>{
      'page': page,
      'perPage': limit.clamp(1, 50),
      'isAdult': false,
      'sort': sort,
      ...?template,
      ...extra,
    };
    final query =
        '''
query MediaPage(\$search: String, \$page: Int, \$perPage: Int, \$season: MediaSeason, \$seasonYear: Int, \$format_in: [MediaFormat], \$genre_in: [String], \$studioId: Int, \$status: MediaStatus, \$sort: [MediaSort], \$isAdult: Boolean) {
  Page(page: \$page, perPage: \$perPage) {
    pageInfo { currentPage hasNextPage }
    media(search: \$search, season: \$season, seasonYear: \$seasonYear, format_in: \$format_in, genre_in: \$genre_in, studioId: \$studioId, status: \$status, sort: \$sort, isAdult: \$isAdult, type: ANIME) {
      $mediaFields
    }
  }
}''';
    return (await _graphQl(query, variables)).fold(
      onSuccess: (json) {
        try {
          final data = _map(json['data']);
          final pageInfo = _map(_map(data?['Page'])?['pageInfo']);
          final media = _map(data?['Page'])?['media'];
          return Success(
            AnimePage(
              items: mapAniListAnimeList(media),
              page: _int(pageInfo?['currentPage']) ?? page,
              hasNextPage: pageInfo?['hasNextPage'] == true,
            ),
          );
        } on Object catch (error) {
          return animeHttpFailure<AnimePage>(error);
        }
      },
      onFailure: FailureResult<AnimePage>.new,
    );
  }

  Future<Result<Anime>> _object(String id) async {
    final query =
        '''
query Media(\$_id: Int, \$_idMal: Int) {
  Media(id: \$_id, idMal: \$_idMal, type: ANIME) {
    $mediaFields
  }
}''';
    return (await _graphQl(query, _idVariables(id))).fold(
      onSuccess: (json) {
        try {
          final map = _map(_map(json['data'])?['Media']);
          final item = map == null ? null : mapAniListAnime(map);
          if (item == null) {
            return const FailureResult(
              NotFoundError('This anime could not be found.'),
            );
          }
          return Success<Anime>(item);
        } on Object catch (error) {
          return animeHttpFailure<Anime>(error);
        }
      },
      onFailure: FailureResult<Anime>.new,
    );
  }

  Map<String, Object?> _idVariables(String id) {
    final numeric = int.tryParse(id);
    return {if (numeric != null) '_idMal': numeric else '_id': numeric};
  }

  Map<String, Object?> _searchFilters(AnimeSearchFilter filter) {
    final studioId = int.tryParse(filter.studioId?.trim() ?? '');
    return <String, Object?>{
      if (filter.type != null)
        'format_in': <String>[_anilistFormat(filter.type!)],
      if (filter.airing != null) 'status': _anilistStatus(filter.airing!),
      if (filter.ageRating != null)
        'isAdult': filter.ageRating == AnimeAgeFilter.adult,
      if (filter.genreId != null && filter.genreId!.isNotEmpty)
        'genre_in': <String>[filter.genreId!],
      'studioId': ?studioId,
    };
  }

  String _anilistFormat(AnimeTypeFilter type) => switch (type) {
    AnimeTypeFilter.tv => 'TV',
    AnimeTypeFilter.movie => 'MOVIE',
    AnimeTypeFilter.ova => 'OVA',
    AnimeTypeFilter.special => 'SPECIAL',
    AnimeTypeFilter.ona => 'ONA',
  };

  String _anilistStatus(AnimeAiringFilter airing) => switch (airing) {
    AnimeAiringFilter.airing => 'RELEASING',
    AnimeAiringFilter.finished => 'FINISHED',
    AnimeAiringFilter.upcoming => 'NOT_YET_RELEASED',
  };

  String _sort(AnimeSearchSort sort) => switch (sort) {
    AnimeSearchSort.members => 'POPULARITY_DESC',
    AnimeSearchSort.title => 'TITLE_ROMAJI',
    AnimeSearchSort.newest => 'UPDATED_AT_DESC',
    AnimeSearchSort.favorites => 'FAVOURITES_DESC',
  };

  Future<Result<Map<String, dynamic>>> _graphQl(
    String query,
    Map<String, Object?>? variables,
  ) async {
    try {
      final response = await _http.post(
        _baseUri,
        body: <String, Object?>{'query': query, 'variables': ?variables},
        priority: AnimeRequestPriority.interactive,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorStatus = _graphQlErrorStatus(_tryDecode(response.body));
        if (errorStatus == 404) {
          return const FailureResult(
            NotFoundError('This anime could not be found.'),
          );
        }
        return animeHttpFailure<Map<String, dynamic>>(
          'http ${response.statusCode}',
          statusCode: response.statusCode,
          retryAfter: response.retryAfter,
        );
      }
      try {
        final json = decodeAnimeJsonObject(response.body);
        final errorStatus = _graphQlErrorStatus(json);
        if (errorStatus != null) {
          if (errorStatus == 404) {
            return const FailureResult(
              NotFoundError('This anime could not be found.'),
            );
          }
          return animeHttpFailure<Map<String, dynamic>>(
            'graphql $errorStatus',
            statusCode: errorStatus,
          );
        }
        return Success(json);
      } on Object catch (error) {
        return animeHttpFailure<Map<String, dynamic>>(error);
      }
    } on Object catch (error) {
      return animeHttpFailure<Map<String, dynamic>>(error);
    }
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return decodeAnimeJsonObject(body);
    } catch (_) {
      return null;
    }
  }

  int? _graphQlErrorStatus(Map<String, dynamic>? json) {
    final errors = json?['errors'];
    if (errors is! List || errors.isEmpty) return null;
    final first = errors.first;
    if (first is Map) return _int(first['status']);
    return null;
  }
}

Map<String, dynamic>? _map(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

List<Map<String, dynamic>> _nodesOf(Object? raw) {
  if (raw is! Map) return const <Map<String, dynamic>>[];
  final list = raw['nodes'];
  if (list is! List) return const <Map<String, dynamic>>[];
  final nodes = <Map<String, dynamic>>[];
  for (final entry in list) {
    if (entry is Map) nodes.add(Map<String, dynamic>.from(entry));
  }
  return nodes;
}

int? _int(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}

String? _string(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  return text.isEmpty ? null : text;
}
