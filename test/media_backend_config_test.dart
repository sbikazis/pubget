import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/media/media_kind.dart';
import 'package:pubget/core/media/media_storage_provider.dart';
import 'package:pubget/core/media/media_repository_factory.dart';

void main() {
  group('resolveMediaBackendConfig', () {
    test('uses the deployed Cloudflare Worker by default', () {
      final config = resolveMediaBackendConfig();

      expect(config.backend, MediaBackend.r2);
      expect(config.workerUrl, defaultR2WorkerUrl);
      expect(config.isConfigured, isTrue);
    });

    test('normalizes an explicit HTTPS Worker URL', () {
      final config = resolveMediaBackendConfig(
        backendOverride: 'r2',
        workerUrlOverride: 'https://media.example.workers.dev///',
      );

      expect(config.backend, MediaBackend.r2);
      expect(config.workerUrl, 'https://media.example.workers.dev');
      expect(config.isConfigured, isTrue);
    });

    test('never treats Firebase Storage as a new-upload destination', () {
      final config = resolveMediaBackendConfig(
        backendOverride: 'firebase',
      );

      expect(config.backend, MediaBackend.r2);
      expect(config.isConfigured, isTrue);
    });

    test('keeps the in-memory backend available to tests', () {
      final config = resolveMediaBackendConfig(
        backendOverride: 'memory',
      );

      expect(config.backend, MediaBackend.memory);
      expect(config.workerUrl, isEmpty);
      expect(config.isConfigured, isFalse);
    });

    test('fails closed for an invalid Worker URL instead of falling back', () {
      final config = resolveMediaBackendConfig(
        workerUrlOverride: 'http://insecure.example.workers.dev',
      );

      expect(config.backend, MediaBackend.r2);
      expect(config.workerUrl, isEmpty);
      expect(config.isConfigured, isFalse);
    });
  });

  group('createMediaRepository', () {
    test('uses the in-memory backend only when explicitly requested', () {
      final repository = createMediaRepository(backendOverride: 'memory');
      expect(repository.backend, MediaBackend.memory);
    });
  });
}
