import 'dart:async';

import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/anime/data/anime_http_client.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/repositories/anime_repository.dart';

const sampleAnimeJson = '''
{
  "mal_id": 52991,
  "url": "https://myanimelist.net/anime/52991",
  "images": {
    "jpg": {
      "image_url": "https://example.test/thumb.jpg",
      "large_image_url": "https://example.test/large.jpg"
    }
  },
  "trailer": {"url": "https://youtube.test/watch?v=abc"},
  "title": "Frieren",
  "title_english": "Frieren: Beyond Journey's End",
  "title_japanese": "葬送のフリーレン",
  "title_synonyms": ["Sousou no Frieren"],
  "type": "TV",
  "source": "Manga",
  "episodes": 28,
  "status": "Finished Airing",
  "airing": false,
  "aired": {"from": "2023-09-29T00:00:00+00:00", "to": "2024-03-22T00:00:00+00:00"},
  "duration": "24 min per ep",
  "score": 9.3,
  "rank": 1,
  "popularity": 80,
  "synopsis": "An elf travels.",
  "season": "fall",
  "year": 2023,
  "broadcast": {"string": "Fridays at 23:00 (JST)"},
  "producers": [{"mal_id": 1, "name": "Aniplex"}],
  "studios": [{"mal_id": 11, "name": "Madhouse"}],
  "genres": [{"mal_id": 2, "name": "Adventure"}],
  "themes": [{"mal_id": 72, "name": "Reincarnation"}],
  "demographics": [],
  "explicit_genres": [],
  "external": [{"name": "Official Site", "url": "https://frieren.test"}]
}
''';

const samplePageJson = '''
{
  "pagination": {"last_visible_page": 2, "has_next_page": true, "current_page": 1},
  "data": [$sampleAnimeJson]
}
''';

const sampleCharactersJson = '''
{
  "data": [
    {
      "character": {
        "mal_id": 10,
        "name": "Frieren",
        "url": "https://myanimelist.net/character/10",
        "images": {"jpg": {"image_url": "https://example.test/char.jpg"}}
      },
      "role": "Main",
      "favorites": 9000,
      "voice_actors": [
        {
          "language": "Japanese",
          "person": {
            "mal_id": 44,
            "name": "Ueda, Reina",
            "images": {"jpg": {"image_url": "https://example.test/va.jpg"}}
          }
        }
      ]
    }
  ]
}
''';

Anime sampleAnime({String id = '52991', String title = 'Frieren'}) => Anime(
  id: id,
  title: title,
  alternativeTitles: const <String>["Frieren: Beyond Journey's End"],
  type: 'TV',
  status: 'Finished Airing',
  score: 9.3,
  year: 2023,
  season: AnimeSeason.fall,
  images: const AnimeImages(thumbnailUrl: 'https://example.test/thumb.jpg'),
);

final class FakeAnimeHttpClient implements AnimeHttpClient {
  FakeAnimeHttpClient({Map<String, AnimeHttpResponse>? responses})
    : responses = Map<String, AnimeHttpResponse>.from(
        responses ?? const <String, AnimeHttpResponse>{},
      );

  final Map<String, AnimeHttpResponse> responses;
  final List<Uri> calls = <Uri>[];
  Object? throwError;
  int failuresBeforeSuccess = 0;
  bool alwaysThrow = false;

  @override
  Future<AnimeHttpResponse> get(Uri uri, {Duration? timeout}) async {
    calls.add(uri);
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess -= 1;
      throw throwError ?? TimeoutException('timeout');
    }
    if (alwaysThrow && throwError != null) {
      throw throwError!;
    }
    final keys = responses.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      if (uri.path == key ||
          uri.path.endsWith(key) ||
          uri.path.endsWith('/$key')) {
        return responses[key]!;
      }
    }
    return const AnimeHttpResponse(statusCode: 404, body: '{}');
  }
}

final class FakeAnimeRepository implements AnimeRepository {
  FakeAnimeRepository({
    this.page,
    this.details,
    this.characters = const <AnimeCharacter>[],
    this.genres = const <AnimeGenre>[],
    this.seasons = const <AnimeSeasonYear>[],
    this.failure,
    this.detailsFailure,
    this.charactersFailure,
    this.nextPageFailure,
  });

  AnimePage? page;
  Anime? details;
  List<AnimeCharacter> characters;
  List<AnimeGenre> genres;
  List<AnimeSeasonYear> seasons;
  Failure? failure;
  Failure? detailsFailure;
  Failure? charactersFailure;
  Failure? nextPageFailure;
  Completer<void>? gate;
  int searchCalls = 0;
  int detailsCalls = 0;
  int trendingCalls = 0;
  int popularCalls = 0;
  int topCalls = 0;
  int airingCalls = 0;
  int upcomingCalls = 0;
  int thisSeasonCalls = 0;
  int charactersCalls = 0;
  int genresCalls = 0;
  int genreCalls = 0;
  int seasonsCalls = 0;
  int seasonListCalls = 0;
  final List<int> requestedPages = <int>[];

  Future<Result<AnimePage>> _pageResult(int pageNumber) async {
    if (gate != null) await gate!.future;
    requestedPages.add(pageNumber);
    if (pageNumber > 1 && nextPageFailure != null) {
      return FailureResult<AnimePage>(nextPageFailure!);
    }
    if (failure != null) return FailureResult<AnimePage>(failure!);
    final base = page ??
        AnimePage(
          items: <Anime>[sampleAnime()],
          page: pageNumber,
          hasNextPage: pageNumber < 2,
        );
    return Success(
      AnimePage(
        items: base.items
            .map(
              (item) => Anime(
                id: pageNumber == 1 ? item.id : '${item.id}-p$pageNumber',
                title: item.title,
                type: item.type,
                status: item.status,
                score: item.score,
                year: item.year,
                images: item.images,
              ),
            )
            .toList(growable: false),
        page: pageNumber,
        hasNextPage: base.hasNextPage && pageNumber < 2,
      ),
    );
  }

  @override
  Future<Result<AnimePage>> searchAnime(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    searchCalls++;
    return _pageResult(page);
  }

  @override
  Future<Result<Anime>> getAnimeDetails(String id) async {
    detailsCalls++;
    if (gate != null) await gate!.future;
    if (detailsFailure != null) {
      return FailureResult<Anime>(detailsFailure!);
    }
    if (id == 'missing' || id.isEmpty) {
      return const FailureResult<Anime>(
        NotFoundError(AnimeStrings.detailsMissing),
      );
    }
    return Success<Anime>(details ?? sampleAnime(id: id));
  }

  @override
  Future<Result<AnimePage>> getTrending({int page = 1, int limit = 20}) async {
    trendingCalls++;
    return _pageResult(page);
  }

  @override
  Future<Result<AnimePage>> getPopular({int page = 1, int limit = 20}) async {
    popularCalls++;
    return _pageResult(page);
  }

  @override
  Future<Result<AnimePage>> getTop({int page = 1, int limit = 20}) async {
    topCalls++;
    return _pageResult(page);
  }

  @override
  Future<Result<AnimePage>> getAiring({int page = 1, int limit = 20}) async {
    airingCalls++;
    return _pageResult(page);
  }

  @override
  Future<Result<AnimePage>> getUpcoming({int page = 1, int limit = 20}) async {
    upcomingCalls++;
    return _pageResult(page);
  }

  @override
  Future<Result<AnimePage>> getThisSeason({int page = 1, int limit = 20}) async {
    thisSeasonCalls++;
    return _pageResult(page);
  }

  @override
  Future<Result<List<AnimeCharacter>>> getCharacters(String animeId) async {
    charactersCalls++;
    if (charactersFailure != null) {
      return FailureResult<List<AnimeCharacter>>(charactersFailure!);
    }
    return Success<List<AnimeCharacter>>(characters);
  }

  @override
  Future<Result<List<AnimeGenre>>> getGenres() async {
    genresCalls++;
    if (gate != null) await gate!.future;
    if (failure != null) return FailureResult<List<AnimeGenre>>(failure!);
    return Success<List<AnimeGenre>>(
      genres.isEmpty
          ? const <AnimeGenre>[AnimeGenre(id: '1', name: 'Action')]
          : genres,
    );
  }

  @override
  Future<Result<AnimePage>> getByGenre(
    String genreId, {
    int page = 1,
    int limit = 20,
  }) async {
    genreCalls++;
    return _pageResult(page);
  }

  @override
  Future<Result<List<AnimeSeasonYear>>> getAvailableSeasons() async {
    seasonsCalls++;
    if (gate != null) await gate!.future;
    if (failure != null) {
      return FailureResult<List<AnimeSeasonYear>>(failure!);
    }
    return Success<List<AnimeSeasonYear>>(
      seasons.isEmpty
          ? const <AnimeSeasonYear>[
              AnimeSeasonYear(
                year: 2026,
                seasons: <AnimeSeason>[
                  AnimeSeason.winter,
                  AnimeSeason.spring,
                  AnimeSeason.summer,
                  AnimeSeason.fall,
                ],
              ),
            ]
          : seasons,
    );
  }

  @override
  Future<Result<AnimePage>> getBySeason({
    required int year,
    required AnimeSeason season,
    int page = 1,
    int limit = 20,
  }) async {
    seasonListCalls++;
    return _pageResult(page);
  }
}
