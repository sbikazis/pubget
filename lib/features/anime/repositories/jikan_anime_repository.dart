import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../data/anime_http_client.dart';
import '../data/jikan_mapper.dart';
import '../models/anime_models.dart';
import 'anime_repository.dart';

final class JikanAnimeRepository implements AnimeRepository {
  JikanAnimeRepository({
    required AnimeHttpClient http,
    Uri? baseUri,
  }) : _http = http,
       _baseUri = baseUri ?? Uri.parse('https://api.jikan.moe/v4');

  final AnimeHttpClient _http;
  final Uri _baseUri;

  @override
  Future<Result<AnimePage>> searchAnime(
    String query, {
    int page = 1,
    int limit = 20,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return Future<Result<AnimePage>>.value(const Success(AnimePage.empty));
    }
    return _page(
      _uri('anime', <String, String>{
        'q': trimmed,
        'page': '$page',
        'limit': '${_limit(limit)}',
        'sfw': 'true',
      }),
      page: page,
    );
  }

  @override
  Future<Result<Anime>> getAnimeDetails(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      return const FailureResult(ValidationError('Anime id is required.'));
    }
    return _object(
      _uri('anime/${Uri.encodeComponent(normalized)}/full'),
      mapJikanAnime,
      const NotFoundError('This anime could not be found.'),
    );
  }

  @override
  Future<Result<AnimePage>> getTrending({int page = 1, int limit = 20}) =>
      _page(
        _uri('top/anime', <String, String>{
          'filter': 'favorite',
          'page': '$page',
          'limit': '${_limit(limit)}',
        }),
        page: page,
      );

  @override
  Future<Result<AnimePage>> getPopular({int page = 1, int limit = 20}) => _page(
    _uri('top/anime', <String, String>{
      'filter': 'bypopularity',
      'page': '$page',
      'limit': '${_limit(limit)}',
    }),
    page: page,
  );

  @override
  Future<Result<AnimePage>> getTop({int page = 1, int limit = 20}) => _page(
    _uri('top/anime', <String, String>{
      'page': '$page',
      'limit': '${_limit(limit)}',
    }),
    page: page,
  );

  @override
  Future<Result<AnimePage>> getAiring({int page = 1, int limit = 20}) => _page(
    _uri('top/anime', <String, String>{
      'filter': 'airing',
      'page': '$page',
      'limit': '${_limit(limit)}',
    }),
    page: page,
  );

  @override
  Future<Result<AnimePage>> getUpcoming({int page = 1, int limit = 20}) =>
      _page(
        _uri('seasons/upcoming', <String, String>{
          'page': '$page',
          'limit': '${_limit(limit)}',
        }),
        page: page,
      );

  @override
  Future<Result<AnimePage>> getThisSeason({int page = 1, int limit = 20}) =>
      _page(
        _uri('seasons/now', <String, String>{
          'page': '$page',
          'limit': '${_limit(limit)}',
        }),
        page: page,
      );

  @override
  Future<Result<List<AnimeCharacter>>> getCharacters(String animeId) {
    final normalized = animeId.trim();
    if (normalized.isEmpty) {
      return Future<Result<List<AnimeCharacter>>>.value(
        const FailureResult(ValidationError('Anime id is required.')),
      );
    }
    return _list(
      _uri('anime/${Uri.encodeComponent(normalized)}/characters'),
      mapJikanCharacters,
    );
  }

  @override
  Future<Result<List<AnimeGenre>>> getGenres() async {
    final genres = await _list(
      _uri('genres/anime', const <String, String>{'filter': 'genres'}),
      (raw) => mapJikanGenres(raw, kind: AnimeTagKind.genre),
    );
    return genres;
  }

  @override
  Future<Result<AnimePage>> getByGenre(
    String genreId, {
    int page = 1,
    int limit = 20,
  }) {
    final normalized = genreId.trim();
    if (normalized.isEmpty) {
      return Future<Result<AnimePage>>.value(
        const FailureResult(ValidationError('Genre id is required.')),
      );
    }
    return _page(
      _uri('anime', <String, String>{
        'genres': normalized,
        'page': '$page',
        'limit': '${_limit(limit)}',
        'order_by': 'members',
        'sort': 'desc',
        'sfw': 'true',
      }),
      page: page,
    );
  }

  @override
  Future<Result<List<AnimeSeasonYear>>> getAvailableSeasons() {
    return _list(_uri('seasons'), mapJikanSeasons);
  }

  @override
  Future<Result<AnimePage>> getBySeason({
    required int year,
    required AnimeSeason season,
    int page = 1,
    int limit = 20,
  }) {
    if (year < 1917) {
      return Future<Result<AnimePage>>.value(
        const FailureResult(ValidationError('Season year is not valid.')),
      );
    }
    return _page(
      _uri('seasons/$year/${season.apiValue}', <String, String>{
        'page': '$page',
        'limit': '${_limit(limit)}',
        'sfw': 'true',
      }),
      page: page,
    );
  }

  Uri _uri(String path, [Map<String, String> query = const <String, String>{}]) {
    return _baseUri.replace(
      path: '${_baseUri.path.endsWith('/') ? _baseUri.path : '${_baseUri.path}/'}$path',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  int _limit(int limit) => limit.clamp(1, 25);

  Future<Result<AnimePage>> _page(Uri uri, {required int page}) async {
    final payload = await _get(uri);
    return payload.fold(
      onSuccess: (body) {
        try {
          final pagination = mapJikanPagination(body['pagination']);
          return Success(
            AnimePage(
              items: mapJikanAnimeList(body['data']),
              page: pagination.page == 0 ? page : pagination.page,
              hasNextPage: pagination.hasNextPage,
            ),
          );
        } on Object catch (error) {
          return animeHttpFailure<AnimePage>(error);
        }
      },
      onFailure: FailureResult<AnimePage>.new,
    );
  }

  Future<Result<T>> _object<T>(
    Uri uri,
    T? Function(Object? raw) map,
    Failure missing,
  ) async {
    final payload = await _get(uri);
    return payload.fold(
      onSuccess: (body) {
        try {
          final value = map(body['data']);
          if (value == null) return FailureResult<T>(missing);
          return Success<T>(value);
        } on Object catch (error) {
          return animeHttpFailure<T>(error);
        }
      },
      onFailure: FailureResult<T>.new,
    );
  }

  Future<Result<List<T>>> _list<T>(
    Uri uri,
    List<T> Function(Object? raw) map,
  ) async {
    final payload = await _get(uri);
    return payload.fold(
      onSuccess: (body) {
        try {
          return Success<List<T>>(map(body['data']));
        } on Object catch (error) {
          return animeHttpFailure<List<T>>(error);
        }
      },
      onFailure: FailureResult<List<T>>.new,
    );
  }

  Future<Result<Map<String, dynamic>>> _get(Uri uri) async {
    try {
      final response = await _http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return animeHttpFailure<Map<String, dynamic>>(
          'http ${response.statusCode}',
          statusCode: response.statusCode,
          retryAfter: response.retryAfter,
        );
      }
      try {
        return Success(decodeAnimeJsonObject(response.body));
      } on Object catch (error) {
        return animeHttpFailure<Map<String, dynamic>>(error);
      }
    } on Object catch (error) {
      return animeHttpFailure<Map<String, dynamic>>(error);
    }
  }
}
