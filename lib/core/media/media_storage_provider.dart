import 'dart:typed_data';

import 'media_kind.dart';

/// Runtime selection of where new media bytes live.
final class MediaBackendConfig {
  const MediaBackendConfig({
    required this.backend,
    required this.workerUrl,
  });

  final MediaBackend backend;
  final String workerUrl;

  bool get usesR2 => backend == MediaBackend.r2;
  bool get isConfigured => usesR2 && workerUrl.isNotEmpty;
}

/// The deployed Pubget media Worker. Build-time configuration can override it
/// for local/staging environments without embedding any credentials.
const String defaultR2WorkerUrl = 'https://pubget-media.pubget.workers.dev';

/// Resolves the only supported production write backend.
///
/// New media must never silently fall back to Firebase Storage. The memory
/// backend is reserved for tests/previews. Existing Firebase-backed objects
/// remain readable through explicit legacy read paths, but are not a
/// destination for new uploads.
MediaBackendConfig resolveMediaBackendConfig({
  String? backendOverride,
  String? workerUrlOverride,
}) {
  final requestedBackend = (backendOverride ??
          const String.fromEnvironment('MEDIA_BACKEND', defaultValue: 'r2'))
      .trim()
      .toLowerCase();

  if (requestedBackend == 'memory') {
    return const MediaBackendConfig(
      backend: MediaBackend.memory,
      workerUrl: '',
    );
  }

  final configuredUrl =
      workerUrlOverride ?? const String.fromEnvironment('R2_WORKER_URL');
  final candidate = configuredUrl.trim().isEmpty
      ? defaultR2WorkerUrl
      : configuredUrl.trim();
  final normalized = candidate.replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(normalized);
  final validHttpsUrl = uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;

  return MediaBackendConfig(
    backend: MediaBackend.r2,
    workerUrl: validHttpsUrl ? normalized : '',
  );
}

/// The storage-backend contract features and the media repository depend on.
///
/// Implementations generate object keys internally, never trust a caller's
/// file name as a key, and never expose storage credentials to the caller.
abstract interface class MediaStorageProvider {
  MediaBackend get backend;

  Future<String> upload({
    required String ownerUid,
    required MediaKind kind,
    required Uint8List bytes,
    required String contentType,
    required String extension,
    String? scopeType,
    String? scopeId,
    void Function(double progress)? onProgress,
  });

  /// Removes the object at [storageKey]. Deleting a missing object succeeds.
  Future<void> delete(String storageKey);

  /// Resolves a fetchable URL for [storageKey].
  Future<String> resolveUrl(String storageKey);
}
