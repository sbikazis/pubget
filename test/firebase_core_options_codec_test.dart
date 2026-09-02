import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  List<Object?> fourteenFieldPigeonList() {
    return <Object?>[
      'api-key',
      'app-id',
      'sender',
      'project',
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
    ];
  }

  /// Mirrors `CoreFirebaseOptions.decode` reading `recaptchaSiteKey` at index 14.
  String? recaptchaSiteKeyFromPigeon(List<Object?> result) {
    return result[14] as String?;
  }

  test('14-field CoreFirebaseOptions lists throw the device RangeError', () {
    expect(fourteenFieldPigeonList(), hasLength(14));
    expect(
      () => recaptchaSiteKeyFromPigeon(fourteenFieldPigeonList()),
      throwsA(
        isA<RangeError>().having(
          (error) => error.toString(),
          'toString',
          contains('Not in inclusive range 0..13: 14'),
        ),
      ),
    );
  });

  test('15-field CoreFirebaseOptions lists include recaptchaSiteKey', () {
    final decoded = recaptchaSiteKeyFromPigeon(<Object?>[
      ...fourteenFieldPigeonList(),
      'site-key',
    ]);

    expect(decoded, 'site-key');
  });

  test(
    'firebase_core Android pigeon encodes 15 CoreFirebaseOptions fields',
    () {
      final generated = _androidGeneratedCodec();
      expect(generated.existsSync(), isTrue, reason: generated.path);
      final source = generated.readAsStringSync();
      expect(source, contains('new ArrayList<>(15)'));
      expect(source, contains('pigeonVar_list.get(14)'));
      expect(source, contains('setRecaptchaSiteKey'));
      expect(source, isNot(contains('new ArrayList<>(14)')));
    },
  );
}

File _androidGeneratedCodec() {
  final roots = <String>[
    if (Platform.environment['PUB_CACHE'] != null)
      '${Platform.environment['PUB_CACHE']}/hosted/pub.dev',
    '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev',
  ];
  for (final root in roots) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;
    for (final entity in directory.listSync()) {
      if (entity is! Directory) continue;
      if (!entity.path.contains('firebase_core-4.')) continue;
      final generated = File(
        '${entity.path}/android/src/main/java/io/flutter/plugins/firebase/core/GeneratedAndroidFirebaseCore.java',
      );
      if (generated.existsSync() &&
          generated.readAsStringSync().contains('setRecaptchaSiteKey')) {
        return generated;
      }
    }
  }
  return File('missing-firebase-core-android-codec.java');
}
