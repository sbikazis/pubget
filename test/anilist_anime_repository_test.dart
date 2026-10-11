import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/anime/data/anime_http_client.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/repositories/anilist_anime_repository.dart';

import 'anime_test_support.dart';

const _mediaJson = '''
{
  "id": 16498,
  "title": {"romaji": "Shingeki no Kyojin", "english": "Attack on Titan", "native": "進撃の巨人", "userPreferred": "Attack on Titan"},
  "description": "<p>Humanity fights giants.</p>",
  "format": "TV",
  "status": "FINISHED",
  "episodes": 25,
  "duration": 24,
  "startDate": {"year": 2013, "month": 4, "day": 7},
  "endDate": {"year": 2013, "month": 9, "day": 29},
  "season": "SPRING",
  "averageScore": 85,
  "popularity": 123456,
  "favourites": 34567,
  "coverImage": {"extraLarge": "https://example.test/xl.jpg", "large": "https://example.test/l.jpg", "medium": "https://example.test/m.jpg"},
  "genres": ["Action", "Drama"],
  "studios": {"nodes": [{"id": 858, "name": "Wit Studio", "isAnimationStudio": true}]},
  "relations": {"edges": [{"relationType": "SEQUEL", "node": {"id": 23283, "type": "ANIME", "format": "TV", "title": {"romaji": "Shingeki no Kyojin 2"}, "coverImage": {"large": "https://example.test/r.jpg"}}}]},
  "source": "MANGA",
  "nextAiringEpisode": null,
  "trailer": {"id": "abc", "site": "youtube"},
  "externalLinks": [{"site": "Crunchyroll", "url": "https://example.test/cr"}],
  "isAdult": false
}
''';

// Native AniList id differs from the MyAnimeList id, which is what the
// canonical `Anime.id` must follow.
const _idMalMediaJson = '''
{
  "id": 1000001,
  "idMal": 52991,
  "title": {"romaji": "Sousou no Frieren", "english": "Frieren: Beyond Journey's End", "native": "葬送のフリーレン", "userPreferred": "Frieren"},
  "format": "TV",
  "status": "FINISHED",
  "episodes": 28,
  "duration": 24,
  "season": "FALL",
  "averageScore": 93,
  "popularity": 999,
  "coverImage": {"large": "https://example.test/f.jpg"},
  "genres": ["Adventure"],
  "studios": {"nodes": [{"id": 11, "name": "Madhouse", "isAnimationStudio": true}]},
  "productionCompanies": {"nodes": [{"id": 1, "name": "Aniplex"}, {"id": 2, "name": "TOHO"}]},
  "isAdult": true
}
''';

String _pageBody(String mediaJson) =>
    '{"data":{"Page":{"pageInfo":{"currentPage":1,"hasNextPage":false},"media":[$mediaJson]}}}';

String _graphQlError(int status) =>
    '{"errors":[{"message":"Not Found","status":$status}]}';

void main() {
  group('AniListAnimeRepository', () {
    Future<(AniListAnimeRepository, FakeAnimeHttpClient)> repo(
      Map<String, String> bodies,
    ) async {
      final client = FakeAnimeHttpClient(
        responses: Map<String, AnimeHttpResponse>.fromEntries(
          bodies.entries.map(
            (entry) => MapEntry(
              entry.key,
              AnimeHttpResponse(statusCode: 200, body: entry.value),
            ),
          ),
        ),
      );
      return (
        AniListAnimeRepository(
          http: client,
          baseUri: Uri.parse('https://graphql.anilist.test'),
        ),
        client,
      );
    }

    test('searchAnime maps a MediaPage result', () async {
      final (repository, _) = await repo({
        'MediaPage': _pageBody(_mediaJson),
      });
      final result = await repository.searchAnime('Attack on Titan');
      expect(result, isA<Success<dynamic>>());
      final page = (result as Success).value;
      expect(page.items.length, 1);
      final anime = page.items.first;
      expect(anime.id, '16498');
      expect(anime.title, 'Attack on Titan');
      expect(anime.alternativeTitles, contains('Shingeki no Kyojin'));
      // AniList's native title fills the same labelled slot as Jikan's
      // Japanese title, so both providers agree on where the original title
      // belongs.
      expect(anime.titleJapanese, '進撃の巨人');
      expect(anime.alternativeTitles, isNot(contains('進撃の巨人')));
      expect(anime.synopsis, 'Humanity fights giants.');
      expect(anime.score, 8.5);
      expect(anime.season, isNotNull);
      expect(anime.genres.map((genre) => genre.name), contains('Action'));
      expect(anime.studios, contains('Wit Studio'));
      expect(anime.relations.first.relation, contains('sequel'));
      expect(anime.trailerUrl, 'https://www.youtube.com/watch?v=abc');
      expect(anime.externalLinks.first.label, 'Crunchyroll');
    });

    test('getAnimeDetails with a numeric (Mal) id resolves via idMal',
        () async {
      final (repository, client) = await repo({
        'Media(': '{"data":{"Media":$_mediaJson}}',
      });
      final result = await repository.getAnimeDetails('16498');
      expect(result, isA<Success<dynamic>>());
      final anime = (result as Success).value;
      expect(anime.id, '16498');
      final posted = client.calls.last;
      expect(posted.host, 'graphql.anilist.test');
    });

    test('maps the MAL id (idMal) as the canonical id when present', () async {
      final (repository, _) = await repo({
        'MediaPage': _pageBody(_idMalMediaJson),
      });
      final result = await repository.searchAnime('Frieren');
      final page = (result as Success).value as AnimePage;
      final anime = page.items.first;
      // AniList's native id is 1000001 but the canonical id must be the MAL id
      // so cache/community keys match the primary Jikan provider.
      expect(anime.id, '52991');
      expect(anime.producers, <String>['Aniplex', 'TOHO']);
      expect(anime.rating, 'R+');
      expect(anime.ageRating, AnimeAgeFilter.adult);
    });

    test('getAnimeSummaries resolves canonical ids through idMal_in', () async {
      final (repository, client) = await repo({
        'Summaries': '{"data":{"Page":{"media":[$_idMalMediaJson]}}}',
      });
      final result = await repository.getAnimeSummaries(<String>['52991']);
      final items = (result as Success).value as List<Anime>;
      expect(items.single.id, '52991');
      final query = (client.postBodies.last as Map)['query'] as String;
      expect(query, contains('idMal_in'));
      expect(query, isNot(contains('id_in')));
    });

    test('getAnimeDetails returns NotFound when GraphQL errors with 404',
        () async {
      final (repository, _) = await repo({
        'Media(': _graphQlError(404),
      });
      final result = await repository.getAnimeDetails('99999');
      expect(result, isA<FailureResult<dynamic>>());
      expect((result as FailureResult).failure, isA<NotFoundError>());
    });

    test('getCharacters maps the media characters nodes', () async {
      final (repository, _) = await repo({
        'Characters':
            '{"data":{"Media":{"characters":{"nodes":['
            '{"id":1,"name":{"full":"Eren Yeager"},"image":{"large":"https://example.test/e.jpg"},'
            '"role":"MAIN","favourites":12,'
            '"voiceActors":{"nodes":[{"id":2,"name":{"full":"Yuki Kaji"},"language":"Japanese","image":{"medium":"https://example.test/v.jpg"}}]}}'
            ']}}}}',
      });
      final result = await repository.getCharacters('16498');
      expect(result, isA<Success<dynamic>>());
      final chars = (result as Success).value;
      expect(chars.length, 1);
      expect(chars.first.name, 'Eren Yeager');
      expect(chars.first.role, 'Main');
      expect(chars.first.voiceActors.first.name, 'Yuki Kaji');
    });

    test('getGenres maps GenreCollection', () async {
      final (repository, _) = await repo({
        'GenreCollection':
            '{"data":{"GenreCollection":["Action","Drama","Comedy"]}}',
      });
      final result = await repository.getGenres();
      expect(result, isA<Success<dynamic>>());
      final genres = (result as Success).value;
      expect(genres.map((genre) => genre.name), containsAll(<String>[
        'Action',
        'Drama',
        'Comedy',
      ]));
    });

    test('maps HTTP 429 into a RateLimitedError', () async {
      final patched = FakeAnimeHttpClient(
        responses: <String, AnimeHttpResponse>{
          'MediaPage': const AnimeHttpResponse(
            statusCode: 429,
            body: '{"errors":[]}',
          ),
        },
      );
      final repo429 = AniListAnimeRepository(
        http: patched,
        baseUri: Uri.parse('https://graphql.anilist.test'),
      );
      final result = await repo429.getPopular();
      expect(result, isA<FailureResult<dynamic>>());
      expect((result as FailureResult).failure, isA<RateLimitedError>());
    });
  });
}