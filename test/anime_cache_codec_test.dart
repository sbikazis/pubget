import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/anime/data/anime_cache_codec.dart';
import 'package:pubget/features/anime/models/anime_models.dart';

import 'anime_test_support.dart';

void main() {
  group('AnimeCacheCodec round trips', () {
    test('anime preserves every field', () {
      const original = Anime(
        id: '52991',
        title: 'Frieren: Beyond Journey’s End',
        alternativeTitles: <String>['Frieren', '葬送のフリーレン'],
        synopsis: 'An elf travels after the demon king falls.',
        type: 'TV',
        status: 'Finished Airing',
        score: 9.3,
        rank: 1,
        popularity: 80,
        episodes: 28,
        duration: '24 min per ep',
        startDate: null,
        endDate: null,
        season: AnimeSeason.fall,
        year: 2023,
        genres: <AnimeGenre>[
          AnimeGenre(id: '2', name: 'Adventure'),
          AnimeGenre(id: '72', name: 'Reincarnation', kind: AnimeTagKind.theme),
        ],
        studios: <String>['Madhouse'],
        producers: <String>['Aniplex'],
        source: 'Manga',
        images: AnimeImages(
          thumbnailUrl: 'https://example.test/thumb.jpg',
          largeUrl: 'https://example.test/large.jpg',
        ),
        trailerUrl: 'https://youtube.test/watch?v=abc',
        externalLinks: <AnimeExternalLink>[
          AnimeExternalLink(label: 'Official Site', url: 'https://frieren.test'),
        ],
        nextEpisodeLabel: 'Ep 29',
        airing: false,
        relations: <AnimeRelated>[
          AnimeRelated(
            id: '59978',
            title: 'Frieren Season 2',
            relation: 'Sequel',
            type: 'anime',
            imageUrl: 'https://example.test/related.jpg',
          ),
          AnimeRelated(id: '126996', title: 'Sousou no Frieren', relation: 'Adaptation'),
        ],
      );

      final json = AnimeCacheCodec.animeToMap(original);
      final restored = AnimeCacheCodec.animeFromMap(json);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.alternativeTitles, original.alternativeTitles);
      expect(restored.synopsis, original.synopsis);
      expect(restored.type, original.type);
      expect(restored.status, original.status);
      expect(restored.score, original.score);
      expect(restored.rank, original.rank);
      expect(restored.popularity, original.popularity);
      expect(restored.episodes, original.episodes);
      expect(restored.duration, original.duration);
      expect(restored.season, original.season);
      expect(restored.year, original.year);
      expect(restored.genres.map((g) => (g.id, g.kind)), [
        ('2', AnimeTagKind.genre),
        ('72', AnimeTagKind.theme),
      ]);
      expect(restored.studios, original.studios);
      expect(restored.producers, original.producers);
      expect(restored.source, original.source);
      expect(restored.images.thumbnailUrl, original.images.thumbnailUrl);
      expect(restored.images.largeUrl, original.images.largeUrl);
      expect(restored.trailerUrl, original.trailerUrl);
      expect(restored.externalLinks.first.label, 'Official Site');
      expect(restored.nextEpisodeLabel, original.nextEpisodeLabel);
      expect(restored.airing, original.airing);
      expect(restored.relations, hasLength(2));
      expect(restored.relations.first.id, '59978');
      expect(restored.relations.first.relation, 'Sequel');
      expect(restored.relations.first.type, 'anime');
      expect(restored.relations.first.imageUrl, 'https://example.test/related.jpg');
      expect(restored.relations[1].title, 'Sousou no Frieren');
      expect(restored.relations[1].type, isNull);
    });

    test('anime page preserves items, page, and hasNextPage', () {
      final original = AnimePage(
        items: <Anime>[sampleAnime(), sampleAnime(id: '999', title: 'Dorohedoro')],
        page: 2,
        hasNextPage: true,
      );

      final json = AnimeCacheCodec.pageToMap(original);
      final restored = AnimeCacheCodec.pageFromMap(json);

      expect(restored.page, 2);
      expect(restored.hasNextPage, isTrue);
      expect(restored.items, hasLength(2));
      expect(restored.items.first.id, '52991');
      expect(restored.items[1].title, 'Dorohedoro');
    });

    test('character preserves profile and helpers', () {
      final original = AnimeCharacter(
        id: '10',
        name: 'Frieren',
        imageUrl: 'https://example.test/char.jpg',
        role: 'Main',
        favorites: 9000,
        url: 'https://myanimelist.net/character/10',
        about: 'An elf mage.',
        nameKanji: 'フリーレン',
        nicknames: <String>['Frieren'],
        voiceActors: <VoiceActor>[
          VoiceActor(id: '44', name: 'Ueda, Reina', language: 'Japanese'),
        ],
        animeography: <CharacterAppearance>[
          CharacterAppearance(
            id: '52991',
            title: 'Frieren',
            role: 'Main',
            imageUrl: 'https://example.test/app.jpg',
          ),
        ],
      );

      final json = AnimeCacheCodec.characterToMap(original);
      final restored = AnimeCacheCodec.characterFromMap(json);

      expect(restored.id, '10');
      expect(restored.name, 'Frieren');
      expect(restored.role, 'Main');
      expect(restored.favorites, 9000);
      expect(restored.about, original.about);
      expect(restored.nameKanji, original.nameKanji);
      expect(restored.nicknames, original.nicknames);
      expect(restored.voiceActors.first.name, 'Ueda, Reina');
      expect(restored.voiceActors.first.language, 'Japanese');
      expect(restored.animeography.first.title, 'Frieren');
      expect(restored.hasFullProfile, isTrue);
    });

    test('character list round trip', () {
      const original = <AnimeCharacter>[
        AnimeCharacter(id: '10', name: 'Frieren'),
        AnimeCharacter(id: '11', name: 'Fern'),
      ];
      final restored = AnimeCacheCodec.charactersFromMap(
        AnimeCacheCodec.charactersToMap(original),
      );
      expect(restored.map((c) => c.name), ['Frieren', 'Fern']);
    });

    test('genres round trip', () {
      const original = <AnimeGenre>[
        AnimeGenre(id: '1', name: 'Action'),
        AnimeGenre(
          id: '2',
          name: 'Adventure',
          kind: AnimeTagKind.theme,
          count: 1200,
        ),
      ];
      final restored = AnimeCacheCodec.genresFromMap(
        AnimeCacheCodec.genresToMap(original),
      );
      expect(restored.first.name, 'Action');
      expect(restored[1].kind, AnimeTagKind.theme);
      expect(restored[1].count, 1200);
    });

    test('studios round trip', () {
      const original = <AnimeStudio>[
        AnimeStudio(id: '11', name: 'Madhouse', count: 340),
        AnimeStudio(id: '43', name: 'Ufotable'),
      ];
      final restored = AnimeCacheCodec.studiosFromMap(
        AnimeCacheCodec.studiosToMap(original),
      );
      expect(restored.map((s) => s.id), ['11', '43']);
      expect(restored.first.name, 'Madhouse');
      expect(restored.first.count, 340);
      expect(restored[1].count, isNull);
    });

    test('seasons round trip', () {
      const original = <AnimeSeasonYear>[
        AnimeSeasonYear(year: 2026, seasons: <AnimeSeason>[
          AnimeSeason.winter,
          AnimeSeason.fall,
        ]),
      ];
      final restored = AnimeCacheCodec.seasonsFromMap(
        AnimeCacheCodec.seasonsToMap(original),
      );
      expect(restored.single.year, 2026);
      expect(restored.single.seasons, [AnimeSeason.winter, AnimeSeason.fall]);
    });
  });
}