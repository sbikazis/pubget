import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> spec;

  setUpAll(() {
    spec = jsonDecode(
      File('firestore.indexes.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  test('composite indexes are not redundant single-field + __name__ entries', () {
    final indexes = spec['indexes'] as List<dynamic>;
    final redundant = <String>[];
    for (final raw in indexes) {
      final index = raw as Map<String, dynamic>;
      final fields = (index['fields'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final realFields = fields
          .where((field) => field['fieldPath'] != '__name__')
          .toList(growable: false);
      if (realFields.length < 2) {
        redundant.add(
          '${index['collectionGroup']} ${realFields.map((field) => field['fieldPath']).join(',')}',
        );
      }
    }
    expect(
      redundant,
      isEmpty,
      reason:
          'Firestore rejects single-field composites; use automatic '
          'single-field indexes (or fieldOverrides for collection groups). '
          'Found: $redundant',
    );
  });

  test('Joined tab keeps the members.uid collection-group field override', () {
    final overrides = spec['fieldOverrides'] as List<dynamic>;
    expect(
      overrides.any((raw) {
        final override = raw as Map<String, dynamic>;
        if (override['collectionGroup'] != 'members') return false;
        if (override['fieldPath'] != 'uid') return false;
        final indexes = override['indexes'] as List<dynamic>;
        return indexes.any((entry) {
          final index = entry as Map<String, dynamic>;
          return index['queryScope'] == 'COLLECTION_GROUP' &&
              index['order'] == 'ASCENDING';
        });
      }),
      isTrue,
    );
  });
}
