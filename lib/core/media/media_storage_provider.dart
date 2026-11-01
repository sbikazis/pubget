import 'dart:typed_data';

import 'media_kind.dart';

/// Runtime selection of where media bytes live.
final class MediaBackendConfig {
  const MediaBackendConfig({
    required this.backend,
    required this.workerUrl,
  });

  final MediaBackend backend;

  /// Absolute base URL of the R2 worker (`https://…workers.dev`), empty
  /// unless [backend] is [MediaBackend.r2].
  final String workerUrl;

  bool get usesR2 => backend == MediaBackend.r2;
}

/// Decides the active backend from build-time configuration.
///
/// Rules:
/// * `--dart-define=MEDIA_BACKEND=r2` **and** a non-empty
///   `--dart-define=R2_WORKER_URL=…` are both required for R2; anything else
///   falls back to Firebase Storage so a missing or placeholder worker URL
///   can never silently break uploads.
/// * `MEDIA_BACKEND=memory` selects the in-memory backend for previews.
///
/// No secrets are ever read here — the worker holds all credentials.
MediaBackendConfig resolveMediaBackendConfig({
  String? backendOverride,
  String? workerUrlOverride,
}) {
  final backend = (backendOverride ??
          const String.fromEnvironment('MEDIA_BACKEND'))
      .trim()
      .toLowerCase();
  final workerUrl =
      (workerUrlOverride ?? const String.fromEnvironment('R2_WORKER_URL'))
          .trim();

  if (backend == 'memory') {
    return const MediaBackendConfig(
      backend: MediaBackend.memory,
      workerUrl: '',
    );
  }
  if (backend == 'r2') {
    final normalized = workerUrl.replaceAll(RegExp(r'/+$'), '');
    if (normalized.startsWith('https://') && normalized.isNotEmpty) {
      return MediaBackendConfig(
        backend: MediaBackend.r2,
        workerUrl: normalized,
      );
    }
    // Misconfiguration must degrade to the working backend, not fail closed.
    return const MediaBackendConfig(
      backend: MediaBackend.firebase,
      workerUrl: '',
    );
  }
  return const MediaBackendConfig(
    backend: MediaBackend.firebase,
    workerUrl: '',
  );
}

/// The storage-backend contract features and the media repository depend on.
///
/// Implementations must:
/// * generate keys internally via `buildMediaKey` (never trust a caller's
///   object name),
/// * reject nothing themselves — validation happens once, in
///   `MediaUploadService` — but may surface backend rejections as
///   [FailureResult]s,
/// * never expose credentials to the caller.
abstract interface class MediaStorageProvider {
  MediaBackend get backend;

  /// Stores [bytes] and returns the storage key under which they are now
  /// readable. Throws on failure; the upload service maps errors.
  Future<String> upload({
    required String ownerUid,
    required MediaKind kind,
    required Uint8List bytes,
    required String contentType,
    required String extension,
    void Function(double progress)? onProgress,
  });

  /// Removes the object at [storageKey]. Idempotent: removing a missing
  /// object succeeds.
  Future<void> delete(String storageKey);

  /// Resolves a fetchable URL for [storageKey].
  Future<String> resolveUrl(String storageKey);
}
