import 'package:flutter_test/flutter_test.dart';

import 'package:pubget/core/media/media_kind.dart';
import 'package:pubget/core/media/media_storage_provider.dart';

void main() {
  group('resolveMediaBackendConfig', () {
    test('defaults to Firebase Storage', () {
      final config = resolveMediaBackendConfig(backendOverride: '', workerUrlOverride: '');
      expect(config.backend, MediaBackend.firebase);
      expect(config.usesR2, isFalse);
      expect(config.workerUrl, isEmpty);
    });

    test('selects the in-memory backend explicitly', () {
      final config = resolveMediaBackendConfig(backendOverride: 'memory');
      expect(config.backend, MediaBackend.memory);
    });

    test('selects R2 only when a https worker URL is configured', () {
      final config = resolveMediaBackendConfig(
        backendOverride: 'r2',
        workerUrlOverride: 'https://pubget-media.example.workers.dev/',
      );
      expect(config.backend, MediaBackend.r2);
      expect(config.usesR2, isTrue);
      expect(config.workerUrl, 'https://pubget-media.example.workers.dev');
    });

    test('degrades to Firebase when the worker URL is missing or not https', () {
      expect(
        resolveMediaBackendConfig(backendOverride: 'r2', workerUrlOverride: '').backend,
        MediaBackend.firebase,
      );
      expect(
        resolveMediaBackendConfig(
          backendOverride: 'r2',
          workerUrlOverride: 'http://insecure.example.com',
        ).backend,
        MediaBackend.firebase,
      );
    });

    test('an unknown backend name falls back to Firebase', () {
      expect(
        resolveMediaBackendConfig(backendOverride: 's3').backend,
        MediaBackend.firebase,
      );
    });
  });
}
