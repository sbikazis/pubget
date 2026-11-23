/// Normalizes media references stored by Pubget. New bare object keys are
/// Cloudflare R2 keys and are resolved through the authenticated media Worker.
/// Existing full HTTPS URLs remain directly fetchable.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../errors/failure.dart';

import 'media_storage_provider.dart';
import 'media_url_cache.dart';
import 'r2_media_storage_provider.dart';

/// Shared cache for signed URLs resolved through the media Worker. Image
/// widgets reuse it across rebuilds, and invalidate a reference when a URL
/// fails to decode so the next attempt fetches a fresh signature.
final MediaUrlCache mediaUrlCache = MediaUrlCache();

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

/// Extracts a legacy Firebase Storage object path from a canonical download URL.
/// Only this project's known Firebase bucket is eligible for R2-first resolution.
String? firebaseStorageObjectPath(String reference) {
  final uri = Uri.tryParse(reference.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'firebasestorage.googleapis.com') {
    return null;
  }
  final segments = uri.pathSegments;
  if (segments.length < 5 ||
      segments[0] != 'v0' ||
      segments[1] != 'b' ||
      segments[2] != 'pubget-aaf27.firebasestorage.app' ||
      segments[3] != 'o') {
    return null;
  }
  final objectPath = segments.skip(4).join('/');
  return objectPath.isEmpty ? null : objectPath;
}

Future<ResolvedMediaUrl> _resolveR2Key(String key) async {
  final config = resolveMediaBackendConfig();
  if (!config.isConfigured) {
    throw const NotFoundError(
      "R2 media is not configured; use the legacy Firebase object.",
    );
  }
  final provider = R2MediaStorageProvider(
    workerUrl: config.workerUrl,
    idTokenProvider: () async =>
        await FirebaseAuth.instance.currentUser?.getIdToken(),
  );
  try {
    final resolved = await provider.resolveUrlWithExpiry(key);
    return ResolvedMediaUrl(url: resolved.url, expiresAt: resolved.expiresAt);
  } finally {
    provider.close();
  }
}

/// Drops any cached signature for [reference] so the next resolve call reaches
/// the Worker again. Called when a previously cached URL fails to load.
void invalidateMediaUrl(String reference, {MediaUrlCache? cache}) =>
    (cache ?? mediaUrlCache).invalidate(reference.trim());

/// Resolves R2 first for current keys and legacy Firebase download URLs.
/// A 404 means the source has not been verified in R2 yet, so the original
/// Firebase object remains the fallback. Authorization/network errors fail
/// closed rather than bypassing the Worker with a Firebase URL.
Future<String?> resolveMediaDownloadUrl(
  String reference, {
  MediaUrlCache? cache,
}) async {
  final value = reference.trim();
  if (value.isEmpty || isOpaqueMediaReference(value)) return null;
  final activeCache = cache ?? mediaUrlCache;

  if (isRemoteMediaUrl(value)) {
    final legacyKey = firebaseStorageObjectPath(value);
    if (legacyKey == null || !isR2MediaKey(legacyKey)) return value;
    final cached = activeCache.read(legacyKey);
    if (cached != null) return cached;
    try {
      final resolved = await _resolveR2Key(legacyKey);
      activeCache.write(legacyKey, resolved);
      return resolved.url;
    } on NotFoundError {
      // Use the Firebase SDK fallback so Storage Rules still authorize the
      // caller; do not silently fall back to a long-lived bearer URL token.
      try {
        return await FirebaseStorage.instance.ref(legacyKey).getDownloadURL();
      } on Object {
        return null;
      }
    } on Object {
      return null;
    }
  }

  if (isR2MediaKey(value)) {
    final cached = activeCache.read(value);
    if (cached != null) return cached;
    try {
      final resolved = await _resolveR2Key(value);
      activeCache.write(value, resolved);
      return resolved.url;
    } on NotFoundError {
      // Keep the original Firebase object readable until its R2 copy verifies.
    } on Object {
      return null;
    }
  }

  // Legacy Firebase object paths outside the current R2 key grammar remain
  // readable. Firebase Storage Rules enforce signed-in access on this path.
  if (value.startsWith('/') ||
      value.contains('..') ||
      value.contains('\\') ||
      value.contains('?') ||
      value.length > 1024) {
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
