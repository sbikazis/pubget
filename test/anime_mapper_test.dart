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

  test('maps a full character profile', () {
    final character = mapJikanCharacterFull(<String, Object?>{
      'mal_id': 10,
      'url': 'https://myanimelist.net/character/10',
      'name': 'Frieren',
      'name_kanji': 'フリーレン',
      'about': 'An elf mage.',
      'nicknames': <String>['Frieren'],
      'favorites': 9,
      'images': <String, Object?>{
        'jpg': <String, Object?>{'image_url': 'https://example.test/char.jpg'},
      },
      'anime': <Object?>[
        <String, Object?>{
          'role': 'Main',
          'anime': <String, Object?>{
            'mal_id': 52991,
            'title': 'Frieren',
            'url': 'https://myanimelist.net/anime/52991',
          },
        },
      ],
      'manga': <Object?>[
        <String, Object?>{
          'role': 'Main',
          'manga': <String, Object?>{
            'mal_id': 126996,
            'title': 'Sousou no Frieren',
          },
        },
      ],
      'voices': <Object?>[
        <String, Object?>{
          'language': 'Japanese',
          'person': <String, Object?>{
            'mal_id': 44,
            'name': 'Ueda, Reina',
          },
        },
      ],
    });
    expect(character, isNotNull);
    expect(character!.about, 'An elf mage.');
    expect(character.nameKanji, 'フリーレン');
    expect(character.nicknames, <String>['Frieren']);
    expect(character.favorites, 9);
    expect(character.animeography, hasLength(1));
    expect(character.animeography.single.title, 'Frieren');
    expect(character.mangaography, hasLength(1));
    expect(character.voiceActors.single.name, 'Ueda, Reina');
    expect(character.voiceActors.single.language, 'Japanese');
    expect(character.url, 'https://myanimelist.net/character/10');
  });

  test('splits Jikan about text into facts and narrative', () {
    final sections = CharacterAboutSections.parse(
      'Birthday: Unknown\nHeight: 150 cm\n\nAn elf mage who has lived for centuries.',
    );
    expect(sections.facts, hasLength(2));
    expect(sections.facts.first.label, 'Birthday');
    expect(sections.facts.first.value, 'Unknown');
    expect(sections.narrative, contains('An elf mage'));
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
