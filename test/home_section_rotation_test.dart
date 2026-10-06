import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/home/section_rotation.dart';

/// §5.2.3 rotation: the sections after the two fixed ones change order between
/// visits, but nothing is lost and nothing reshuffles mid-scroll.
void main() {
  const sections = <String>[
    'events',
    'suggested',
    'rising',
    'animeOfWeek',
    'popularCharacters',
    'risingCreators',
    'friendsActivity',
    'freshest',
    'achievements',
    'fanWorks',
    'animeSeason',
  ];

  test('rotation keeps every section exactly once', () {
    final rotated = sections.rotate(7);
    expect(rotated.length, sections.length);
    expect(rotated.toSet(), sections.toSet());
  });

  test('the same seed produces the same order, so a rebuild cannot reshuffle', () {
    expect(sections.rotate(42), sections.rotate(42));
  });

  test('different seeds actually produce different orders', () {
    final seen = <String>{
      for (final seed in List<int>.generate(40, (i) => i))
        sections.rotate(seed).join('|'),
    };
    // With eleven sections there is no realistic chance of a fixed order across
    // forty seeds; this asserts rotation is real rather than incidental.
    expect(seen.length, greaterThan(5));
  });

  test('rotation leaves the list it was called on untouched', () {
    final original = List<String>.of(sections);
    sections.rotate(3);
    expect(sections, original);
  });

  test('a list too short to reorder is returned unchanged', () {
    expect(<String>['only'].rotate(9), <String>['only']);
    expect(<String>[].rotate(9), isEmpty);
  });
}