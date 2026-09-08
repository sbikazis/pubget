import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/anime/data/anime_search_ranker.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/groups/data/group_image_uploader.dart';

Anime _anime(
  String title, {
  List<String> alts = const <String>[],
  double? score,
  int? popularity,
}) {
  return Anime(
    id: title,
    title: title,
    alternativeTitles: alts,
    score: score,
    popularity: popularity,
  );
}

void main() {
  group('AnimeSearchRanker', () {
    test('ranks exact > prefix > contains, then score/popularity', () {
      final ranked = AnimeSearchRanker.rank(
        <Anime>[
          _anime('Demon Slayer', score: 8.7, popularity: 5),
          _anime('Blue Period', score: 7.9, popularity: 400),
          _anime('BLUE LOCK', score: 8.2, popularity: 40),
          _anime('The Blue Bird', score: 6.1, popularity: 9000),
          _anime('Random Show', score: 9.0, popularity: 1),
        ],
        'blue',
      );
      // "blue" is prefix for BLUE LOCK / Blue Period (not exact); Demon Slayer
      // is excluded. Within prefix: higher score wins → BLUE LOCK first.
      expect(ranked.map((a) => a.title).toList(), <String>[
        'BLUE LOCK',
        'Blue Period',
        'The Blue Bird',
      ]);
      expect(AnimeSearchRanker.matchTier(ranked.first, 'blue'), 1);
      expect(ranked.first.title.toLowerCase(), 'blue lock');
    });

    test('exact match beats popular contains-only titles', () {
      final ranked = AnimeSearchRanker.rank(
        <Anime>[
          _anime('Blue', score: 6.0, popularity: 8000),
          _anime('BLUE LOCK', score: 8.2, popularity: 40),
        ],
        'blue',
      );
      expect(ranked.first.title, 'Blue');
      expect(AnimeSearchRanker.matchTier(ranked.first, 'blue'), 0);
    });

    test('matches alternative English titles', () {
      final ranked = AnimeSearchRanker.rank(
        <Anime>[
          _anime('Sorcerous Stabber Orphen', alts: <String>['Blue'], score: 6),
          _anime('Lock', alts: <String>['Blue Lock'], score: 8.3, popularity: 20),
        ],
        'Blue Lock',
      );
      expect(ranked.first.title, 'Lock');
      expect(AnimeSearchRanker.matchTier(ranked.first, 'Blue Lock'), 0);
    });
    test('famous partial queries surface the expected hits first', () {
      final catalog = <Anime>[
        _anime('Demon Slayer: Kimetsu no Yaiba', score: 8.5, popularity: 3),
        _anime('Blue Lock', score: 8.1, popularity: 80),
        _anime('Blue Exorcist', score: 7.5, popularity: 200),
        _anime('One Piece', score: 8.7, popularity: 4),
        _anime('One Punch Man', score: 8.5, popularity: 10),
        _anime(
          'Shingeki no Kyojin',
          alts: <String>['Attack on Titan', 'AoT'],
          score: 8.5,
          popularity: 1,
        ),
        _anime('AOT: Another One', score: 5.0, popularity: 9000),
      ];

      expect(AnimeSearchRanker.rank(catalog, 'blue').first.title, 'Blue Lock');
      expect(
        AnimeSearchRanker.rank(catalog, 'one piece').first.title,
        'One Piece',
      );
      expect(
        AnimeSearchRanker.rank(catalog, 'aot').first.title,
        'Shingeki no Kyojin',
      );
    });
  });

  group('FirebaseGroupImageUploader helpers', () {
    test('normalizes crop PNG and jpeg aliases', () {
      expect(
        FirebaseGroupImageUploader.normalizeContentType('image/png'),
        'image/png',
      );
      expect(
        FirebaseGroupImageUploader.normalizeContentType('image/jpeg; charset=binary'),
        'image/jpeg',
      );
      expect(
        FirebaseGroupImageUploader.extensionFor('image/png'),
        'png',
      );
      expect(
        FirebaseGroupImageUploader.extensionFor('image/jpeg'),
        'jpg',
      );
    });

    test('rejects empty and oversized payloads with typed errors', () {
      expect(
        () => FirebaseGroupImageUploader.validatePayload(
          uid: 'u1',
          bytes: Uint8List(0),
        ),
        throwsA(
          isA<GroupImageUploadException>().having(
            (e) => e.code,
            'code',
            'empty-file',
          ),
        ),
      );
      expect(
        () => FirebaseGroupImageUploader.validatePayload(
          uid: 'u1',
          bytes: Uint8List(FirebaseGroupImageUploader.maxBytes + 1),
        ),
        throwsA(
          isA<GroupImageUploadException>().having(
            (e) => e.code,
            'code',
            'too-large',
          ),
        ),
      );
    });
  });
}
