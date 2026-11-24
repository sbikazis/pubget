import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app has no Firebase Storage SDK dependency', () {
    final root = Directory.current.path;
    final pubspec = File('$root/pubspec.yaml').readAsStringSync();
    final declaration = 'firebase' '_storage:';
    expect(pubspec, isNot(contains(declaration)));

    final sdkImport = 'package:' 'firebase_storage/firebase_storage.dart';
    final lib = Directory('$root/lib');
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      expect(
        entity.readAsStringSync(),
        isNot(contains(sdkImport)),
        reason: '${entity.path} still imports the Storage SDK',
      );
    }
  });
}
