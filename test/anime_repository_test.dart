import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/features/anime/data/anime_http_client.dart';
import 'package:pubget/features/anime/repositories/jikan_anime_repository.dart';

import 'anime_test_support.dart';

void main() {
  late FakeAnimeHttpClient http;
  late JikanAnimeRepository repository;

  setUp(() {
    http = FakeAnimeHttpClient(
      responses: <String, AnimeHttpResponse>{
        '/anime': AnimeHttpResponse(statusCode: 200, body: samplePageJson),
        '/full': AnimeHttpResponse(
          statusCode: 200,
          body: '{"data":$sampleAnimeJson}',
        ),
        '/characters': AnimeHttpResponse(
          statusCode: 200,
          body: sampleCharactersJson,
        ),
        '/top/anime': AnimeHttpResponse(statusCode: 200, body: samplePageJson),
        '/seasons/now': AnimeHttpResponse(statusCode: 200, body: samplePageJson),
        '/seasons/upcoming': AnimeHttpResponse(
          statusCode: 200,
          body: samplePageJson,
        ),
        '/genres/anime': const AnimeHttpResponse(
          statusCode: 200,
          body: '{"data":[{"mal_id":1,"name":"Action","count":10}]}',
        ),
        '/seasons': const AnimeHttpResponse(
          statusCode: 200,
          body:
              '{"data":[{"year":2026,"seasons":["winter","spring","summer","fall"]}]}',
        ),
        '/2026/winter': AnimeHttpResponse(statusCode: 200, body: samplePageJson),
      },
    );
    repository = JikanAnimeRepository(
      http: http,
      baseUri: Uri.parse('https://example.test/v4'),
    );
  });

  test('search maps a successful page', () async {
    final result = await repository.searchAnime('frieren');
    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull!.items.single.title, 'Frieren');
    expect(result.valueOrNull!.hasNextPage, isTrue);
    expect(http.calls.single.queryParameters['q'], 'frieren');
  });

  test('details success', () async {
    final result = await repository.getAnimeDetails('52991');
    expect(result.valueOrNull!.id, '52991');
    expect(result.valueOrNull!.studios, <String>['Madhouse']);
  });

  test('characters success', () async {
    final result = await repository.getCharacters('52991');
    expect(result.valueOrNull!.single.name, 'Frieren');
  });

  test('trending popular top and airing all succeed', () async {
    expect((await repository.getTrending()).isSuccess, isTrue);
    expect((await repository.getPopular()).isSuccess, isTrue);
    expect((await repository.getTop()).isSuccess, isTrue);
    expect((await repository.getAiring()).isSuccess, isTrue);
    expect((await repository.getThisSeason()).isSuccess, isTrue);
    expect((await repository.getUpcoming()).isSuccess, isTrue);
  });

  test('genre and season lists succeed', () async {
    expect((await repository.getGenres()).valueOrNull!.single.name, 'Action');
    expect((await repository.getByGenre('1')).isSuccess, isTrue);
    expect((await repository.getAvailableSeasons()).valueOrNull!.first.year, 2026);
    expect(
      (await repository.getBySeason(year: 2026, season: (await repository.getAvailableSeasons()).valueOrNull!.first.seasons.first)).isSuccess,
      isTrue,
    );
  });

  test('404 becomes NotFoundError', () async {
    http.responses.clear();
    final result = await repository.getAnimeDetails('missing');
    expect(result.failureOrNull, isA<NotFoundError>());
  });

  test('429 becomes RateLimitedError', () async {
    http.responses['/anime'] = const AnimeHttpResponse(
      statusCode: 429,
      body: '{}',
      headers: <String, String>{'retry-after': '2'},
    );
    final result = await repository.searchAnime('naruto');
    expect(result.failureOrNull, isA<RateLimitedError>());
  });

  test('server error becomes UnavailableError', () async {
    http.responses['/anime'] = const AnimeHttpResponse(
      statusCode: 503,
      body: '{}',
    );
    final result = await repository.searchAnime('naruto');
    expect(result.failureOrNull, isA<UnavailableError>());
  });

  test('malformed JSON becomes MalformedDataError', () async {
    http.responses['/full'] = const AnimeHttpResponse(
      statusCode: 200,
      body: 'not-json',
    );
    final result = await repository.getAnimeDetails('1');
    expect(result.failureOrNull, isA<MalformedDataError>());
  });

  test('timeout becomes TimeoutError', () async {
    http.throwError = TimeoutException('timeout');
    http.alwaysThrow = true;
    final result = await repository.getTop();
    expect(result.failureOrNull, isA<TimeoutError>());
  });

  test('empty search query does not hit the network', () async {
    final result = await repository.searchAnime('  ');
    expect(result.valueOrNull!.items, isEmpty);
    expect(http.calls, isEmpty);
  });
}
