/// Normalizes media references stored by Pubget. New bare object keys are
/// Cloudflare R2 keys and are resolved through the authenticated media Worker.
/// Existing full HTTPS URLs remain directly fetchable.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../errors/failure.dart';

import 'media_storage_provider.dart';
import 'r2_media_storage_provider.dart';

bool isRemoteMediaUrl(String reference) {
  final value = reference.trim();
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty;
}

bool isOpaqueMediaReference(String reference) {
  final value = reference.trim();
  return !isRemoteMediaUrl(value) && value.contains('://');
}

/// Upgrades legacy `http://` media links to TLS.
///
/// Release Android forbids cleartext traffic, so an old record pointing at
/// plain HTTP would otherwise render as a broken image. Opaque and non-HTTP
/// references pass through unchanged.
String secureMediaUrl(String reference) {
  final value = reference.trim();
  if (value.startsWith('http://')) {
    return 'https://${value.substring('http://'.length)}';
  }
  return value;
}

/// Matches only the stable object-key formats accepted by the R2 Worker.
/// This is client-side input hygiene; the Worker remains the security boundary.
bool isR2MediaKey(String reference) {
  final parts = reference.trim().split('/');
  final imageExt = RegExp(r'^[A-Za-z0-9_-]{1,80}\.(jpg|jpeg|png|webp|gif)$');
  final videoExt = RegExp(r'^[A-Za-z0-9_-]{1,80}\.(mp4|webm|mov)$');
  final audioExt = RegExp(r'^[A-Za-z0-9_-]{1,80}\.(mp3|aac|ogg|m4a)$');
  final uid = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  if (parts.length == 3) {
    if (!uid.hasMatch(parts[1])) return false;
    return switch (parts[0]) {
      'images' => imageExt.hasMatch(parts[2]),
      'reels' => videoExt.hasMatch(parts[2]),
      'audio' => audioExt.hasMatch(parts[2]),
      _ => false,
    };
  }
  if (parts.length != 4 ||
      !['groups', 'privateChats'].contains(parts[0]) ||
      !RegExp(r'^[A-Za-z0-9_:-]{1,320}$').hasMatch(parts[1]) ||
      !uid.hasMatch(parts[2])) {
    return false;
  }
  return imageExt.hasMatch(parts[3]) ||
      videoExt.hasMatch(parts[3]) ||
      audioExt.hasMatch(parts[3]);
}

/// Resolves an R2 object key to a short-lived, access-controlled URL.
/// Full URLs are returned unchanged; unsupported/legacy bare paths fail closed.
Future<String?> resolveMediaDownloadUrl(String reference) async {
  final value = reference.trim();
  if (value.isEmpty || isOpaqueMediaReference(value)) return null;
  if (isRemoteMediaUrl(value)) return value;

  // New/current key shapes try verified R2 first. The Worker returns 404 for
  // an object not yet verified in the persistent migration manifest; only
  // that condition falls back to the original Firebase Storage object.
  if (isR2MediaKey(value)) {
    final config = resolveMediaBackendConfig();
    if (config.isConfigured) {
      final provider = R2MediaStorageProvider(
        workerUrl: config.workerUrl,
        idTokenProvider: () async =>
            await FirebaseAuth.instance.currentUser?.getIdToken(),
      );
      try {
        return await provider.resolveUrl(value);
      } on NotFoundError {
        // The source object is intentionally retained during backfill.
      } on Object {
        return null;
      } finally {
        provider.close();
      }
    }
  }

  // Legacy Firebase object paths outside the R2 key grammar remain readable.
  // Never accept a URL or traversal-like path here; Firebase Storage rules
  // still enforce the signed-in user's read permissions.
  if (value.startsWith('/') || value.contains('..') ||
      value.contains('\\') || value.contains('?') || value.length > 1024) {
    return null;
  }
  try {
    return await FirebaseStorage.instance.ref(value).getDownloadURL();
  } on Object {
    return null;
  }
}

/// Maps a picked video extension to a Worker-accepted MIME type.
String videoContentTypeFor(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final ext = dot >= 0 && dot < fileName.length - 1
      ? fileName.substring(dot + 1).toLowerCase()
      : '';
  switch (ext) {
    case 'webm':
      return 'video/webm';
    case 'mov':
    case 'qt':
      return 'video/quicktime';
    case 'mp4':
    case 'm4v':
    default:
      return 'video/mp4';
  }
}
