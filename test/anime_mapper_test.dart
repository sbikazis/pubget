import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/anime/data/jikan_mapper.dart';
import 'package:pubget/features/anime/models/anime_models.dart';

import 'anime_test_support.dart';

void main() {
  test('maps a Jikan anime payload into the domain model', () {
    final anime = mapJikanAnime(jsonDecode(sampleAnimeJson) as Map<String, dynamic>);
    expect(anime, isNotNull);
    expect(anime!.id, '52991');
    expect(anime.title, 'Frieren');
    expect(anime.alternativeTitles, contains("Frieren: Beyond Journey's End"));
    expect(anime.score, 9.3);
    expect(anime.rank, 1);
    expect(anime.season, AnimeSeason.fall);
    expect(anime.year, 2023);
    expect(anime.studios, <String>['Madhouse']);
    expect(anime.images.thumbnailUrl, 'https://example.test/thumb.jpg');
    expect(anime.trailerUrl, 'https://youtube.test/watch?v=abc');
    expect(anime.genres.map((g) => g.kind), containsAll(<AnimeTagKind>[AnimeTagKind.genre, AnimeTagKind.theme]));
  });

  test('maps characters including voice actors', () {
    final payload = jsonDecode(sampleCharactersJson) as Map<String, dynamic>;
    final characters = mapJikanCharacters(payload['data']);
    expect(characters, hasLength(1));
    expect(characters.first.name, 'Frieren');
    expect(characters.first.role, 'Main');
    expect(characters.first.voiceActors.first.name, 'Ueda, Reina');
  });

  test('skips malformed anime entries instead of throwing', () {
    final items = mapJikanAnimeList(<Object?>[
      <String, Object?>{'mal_id': 1},
      jsonDecode(sampleAnimeJson),
    ]);
    expect(items, hasLength(1));
    expect(items.single.id, '52991');
  });

  test('maps season years newest first', () {
    final years = mapJikanSeasons(<Object?>[
      <String, Object?>{
        'year': 2024,
        'seasons': <String>['winter', 'spring'],
      },
      <String, Object?>{
        'year': 2026,
        'seasons': <String>['fall'],
      },
    ]);
    expect(years.first.year, 2026);
    expect(years.first.seasons, <AnimeSeason>[AnimeSeason.fall]);
  });
}
