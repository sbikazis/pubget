import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _banned = <String>[
  'Icons.monetization_on',
  'Icons.paid',
  'Icons.attach_money',
  'Icons.currency_bitcoin',
  'Icons.savings',
  'Icons.circle_outlined',
];

void main() {
  test('lib uses PubgetCoinIcon instead of ad-hoc currency glyphs', () {
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final needle in _banned) {
        if (text.contains(needle)) {
          hits.add('${entity.path}: $needle');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));

    final chrome = File('lib/core/widgets/pubget_brand_chrome.dart').readAsStringSync();
    expect(chrome.contains('class PubgetCoinIcon'), isTrue);
    expect(chrome.contains('class PubgetCoinPainter'), isTrue);
  });
}
