import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/home/models/home_models.dart';

void main() {
  test('DiscoveryFeed parses a full sectioned payload', () {
    final feed = DiscoveryFeed.fromMap(<String, dynamic>{
      'coldStart': true,
      'sections': <String, dynamic>{
        'recommendedGroups': <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'group:g1',
              'type': 'group',
              'targetId': 'g1',
              'score': 41.2,
              'metadata': <String, dynamic>{'name': 'Crew'},
            },
          ],
          'cursor': 'g1',
          'hasMore': true,
        },
      },
    });
    expect(feed.coldStart, isTrue);
    expect(feed.section('recommendedGroups').items.single.targetId, 'g1');
    expect(feed.section('recommendedGroups').hasMore, isTrue);
  });

  test('DiscoveryFeed parses a single-section page', () {
    final feed = DiscoveryFeed.fromMap(<String, dynamic>{
      'coldStart': false,
      'section': 'recommendedEdits',
      'items': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'edit:e1', 'type': 'edit', 'targetId': 'e1'},
      ],
      'cursor': 'e1',
      'hasMore': false,
    });
    expect(feed.section('recommendedEdits').items.single.type, 'edit');
    expect(feed.section('missing').items, isEmpty);
  });
}
