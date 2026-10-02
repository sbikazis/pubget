import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/fan_works/models/fan_work_models.dart';
import 'package:pubget/features/fan_works/models/fan_work_taxonomy.dart';

/// Locks the Dart taxonomy mirror against the ids hard-coded here.
///
/// The server copy lives in `functions/src/fanWorksTaxonomy.js` and is locked
/// by `functions/test/fanWorksTaxonomy.test.js`. Neither test can read the
/// other file, so the shared source of truth is this pair of literal id lists:
/// when the product owner adds a category, one of the two suites must fail
/// until both sides change. That is deliberate.
void main() {
  group('creatable types', () {
    test('exactly four, matching the server', () {
      expect(FanWorkType.creatable, <FanWorkType>[
        FanWorkType.manga,
        FanWorkType.story,
        FanWorkType.drawing,
        FanWorkType.character,
      ]);
    });

    test('legacy types stay known but not creatable', () {
      for (final type in <FanWorkType>[
        FanWorkType.worldbuilding,
        FanWorkType.other,
      ]) {
        expect(FanWorkType.values, contains(type), reason: type.name);
        expect(type.isCreatable, isFalse, reason: type.name);
        expect(FanWorkCategories.supportsCategory(type), isFalse);
        expect(FanWorkCategories.forType(type), isEmpty);
        expect(fanWorkTypeFrom(type.name), type, reason: type.name);
      }
    });
  });

  group('category ids mirror the server', () {
    test('narrative ids match functions/src/fanWorksTaxonomy.js', () {
      expect(FanWorkCategories.idsFor(FanWorkType.manga), <String>[
        'action',
        'adventure',
        'comedy',
        'drama',
        'romance',
        'fantasy',
        'sciFi',
        'supernatural',
        'horror',
        'mystery',
        'sliceOfLife',
        'historical',
      ]);
      expect(
        FanWorkCategories.idsFor(FanWorkType.story),
        FanWorkCategories.idsFor(FanWorkType.manga),
      );
    });

    test('art ids match the server', () {
      expect(FanWorkCategories.idsFor(FanWorkType.drawing), <String>[
        'portrait',
        'characterArt',
        'fullBody',
        'landscape',
        'conceptArt',
        'digitalArt',
        'traditionalArt',
        'animeStyle',
        'chibi',
        'fanArt',
      ]);
    });

    test('character ids match the server', () {
      expect(FanWorkCategories.idsFor(FanWorkType.character), <String>[
        'human',
        'superhuman',
        'demon',
        'spirit',
        'creature',
        'android',
        'animal',
        'warrior',
        'royalty',
        'antiHero',
      ]);
    });

    test('aiCharacter reads as character with an explicit origin', () {
      expect(fanWorkTypeFrom('aiCharacter'), FanWorkType.character);
      expect(fanWorkTypeFrom('aiCharacter').isCreatable, isTrue);
      expect(FanWorkOrigin.from('aiGenerated'), FanWorkOrigin.aiGenerated);
      expect(FanWorkOrigin.from('anything else'), FanWorkOrigin.handmade);
    });

    test('an unknown type degrades to other instead of throwing', () {
      expect(fanWorkTypeFrom('nonsense'), FanWorkType.other);
      expect(fanWorkTypeFrom(null), FanWorkType.other);
    });
  });

  group('closed list enforcement', () {
    test('ids are unique per list and every one has both labels', () {
      for (final type in FanWorkType.creatable) {
        final categories = FanWorkCategories.forType(type);
        expect(categories, isNotEmpty, reason: type.name);
        final ids = categories.map((category) => category.id).toList();
        expect(ids.toSet().length, ids.length, reason: type.name);
        for (final category in categories) {
          expect(category.en, isNotEmpty, reason: category.id);
          expect(category.ar, isNotEmpty, reason: category.id);
        }
      }
    });

    test('byId rejects empty, unknown, and cross-type ids', () {
      expect(FanWorkCategories.byId(FanWorkType.manga, 'action'), isNotNull);
      expect(FanWorkCategories.byId(FanWorkType.manga, 'portrait'), isNull);
      expect(FanWorkCategories.byId(FanWorkType.drawing, 'action'), isNull);
      expect(FanWorkCategories.byId(FanWorkType.manga, ''), isNull);
      expect(FanWorkCategories.byId(FanWorkType.manga, 'made-up'), isNull);
      expect(
        FanWorkCategories.byId(FanWorkType.worldbuilding, 'human'),
        isNull,
      );
    });

    test('label switches on the app locale', () {
      final category = FanWorkCategories.byId(FanWorkType.manga, 'sciFi')!;
      expect(category.label(arabic: false), 'Sci-Fi');
      expect(category.label(arabic: true), 'خيال علمي');
    });
  });
}
