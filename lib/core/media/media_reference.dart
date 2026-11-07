/// Normalizes media references stored by Pubget. New bare object keys are
/// Cloudflare R2 keys and are resolved through the authenticated media Worker.
/// Existing full HTTPS URLs remain directly fetchable.
library;

import 'package:firebase_auth/firebase_auth.dart';

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

/// Matches only the stable object-key formats accepted by the R2 Worker.
/// This is client-side input hygiene; the Worker remains the security boundary.
bool isR2MediaKey(String reference) {
  final parts = reference.trim().split('/');
  final imageExt = RegExp(r'^[A-Za-z0-9_-]{1,80}\\.(jpg|jpeg|png|webp|gif)
/// Resolves an R2 object key to a short-lived, access-controlled URL.
/// Full URLs are returned unchanged; unsupported/legacy bare paths fail closed.
Future<String?> resolveMediaDownloadUrl(String reference) async {
  final value = reference.trim();
  if (value.isEmpty || isOpaqueMediaReference(value)) return null;
  if (isRemoteMediaUrl(value)) return value;
  if (!isR2MediaKey(value)) return null;

  final config = resolveMediaBackendConfig();
  if (!config.isConfigured) return null;
  final provider = R2MediaStorageProvider(
    workerUrl: config.workerUrl,
    idTokenProvider: () async =>
        await FirebaseAuth.instance.currentUser?.getIdToken(),
  );
  try {
    return await provider.resolveUrl(value);
  } on Object {
    return null;
  } finally {
    // AppImageLoader resolves every R2 image through this one-shot provider.
    // Close its HTTP client so a long feed does not accumulate idle pools.
    provider.close();
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
);
  final videoExt = RegExp(r'^[A-Za-z0-9_-]{1,80}\\.(mp4|webm|mov)
/// Resolves an R2 object key to a short-lived, access-controlled URL.
/// Full URLs are returned unchanged; unsupported/legacy bare paths fail closed.
Future<String?> resolveMediaDownloadUrl(String reference) async {
  final value = reference.trim();
  if (value.isEmpty || isOpaqueMediaReference(value)) return null;
  if (isRemoteMediaUrl(value)) return value;

  final config = resolveMediaBackendConfig();
  if (!config.isConfigured) return null;
  final provider = R2MediaStorageProvider(
    workerUrl: config.workerUrl,
    idTokenProvider: () async =>
        await FirebaseAuth.instance.currentUser?.getIdToken(),
  );
  try {
    return await provider.resolveUrl(value);
  } on Object {
    return null;
  } finally {
    // AppImageLoader resolves every R2 image through this one-shot provider.
    // Close its HTTP client so a long feed does not accumulate idle pools.
    provider.close();
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
);
  final audioExt = RegExp(r'^[A-Za-z0-9_-]{1,80}\\.(mp3|aac|ogg|m4a)
/// Resolves an R2 object key to a short-lived, access-controlled URL.
/// Full URLs are returned unchanged; unsupported/legacy bare paths fail closed.
Future<String?> resolveMediaDownloadUrl(String reference) async {
  final value = reference.trim();
  if (value.isEmpty || isOpaqueMediaReference(value)) return null;
  if (isRemoteMediaUrl(value)) return value;

  final config = resolveMediaBackendConfig();
  if (!config.isConfigured) return null;
  final provider = R2MediaStorageProvider(
    workerUrl: config.workerUrl,
    idTokenProvider: () async =>
        await FirebaseAuth.instance.currentUser?.getIdToken(),
  );
  try {
    return await provider.resolveUrl(value);
  } on Object {
    return null;
  } finally {
    // AppImageLoader resolves every R2 image through this one-shot provider.
    // Close its HTTP client so a long feed does not accumulate idle pools.
    provider.close();
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
);
  final uid = RegExp(r'^[A-Za-z0-9_-]{1,128}
/// Resolves an R2 object key to a short-lived, access-controlled URL.
/// Full URLs are returned unchanged; unsupported/legacy bare paths fail closed.
Future<String?> resolveMediaDownloadUrl(String reference) async {
  final value = reference.trim();
  if (value.isEmpty || isOpaqueMediaReference(value)) return null;
  if (isRemoteMediaUrl(value)) return value;

  final config = resolveMediaBackendConfig();
  if (!config.isConfigured) return null;
  final provider = R2MediaStorageProvider(
    workerUrl: config.workerUrl,
    idTokenProvider: () async =>
        await FirebaseAuth.instance.currentUser?.getIdToken(),
  );
  try {
    return await provider.resolveUrl(value);
  } on Object {
    return null;
  } finally {
    // AppImageLoader resolves every R2 image through this one-shot provider.
    // Close its HTTP client so a long feed does not accumulate idle pools.
    provider.close();
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
);
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
      !RegExp(r'^[A-Za-z0-9_:-]{1,320}
/// Resolves an R2 object key to a short-lived, access-controlled URL.
/// Full URLs are returned unchanged; unsupported/legacy bare paths fail closed.
Future<String?> resolveMediaDownloadUrl(String reference) async {
  final value = reference.trim();
  if (value.isEmpty || isOpaqueMediaReference(value)) return null;
  if (isRemoteMediaUrl(value)) return value;

  final config = resolveMediaBackendConfig();
  if (!config.isConfigured) return null;
  final provider = R2MediaStorageProvider(
    workerUrl: config.workerUrl,
    idTokenProvider: () async =>
        await FirebaseAuth.instance.currentUser?.getIdToken(),
  );
  try {
    return await provider.resolveUrl(value);
  } on Object {
    return null;
  } finally {
    // AppImageLoader resolves every R2 image through this one-shot provider.
    // Close its HTTP client so a long feed does not accumulate idle pools.
    provider.close();
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
).hasMatch(parts[1]) ||
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

  final config = resolveMediaBackendConfig();
  if (!config.isConfigured) return null;
  final provider = R2MediaStorageProvider(
    workerUrl: config.workerUrl,
    idTokenProvider: () async =>
        await FirebaseAuth.instance.currentUser?.getIdToken(),
  );
  try {
    return await provider.resolveUrl(value);
  } on Object {
    return null;
  } finally {
    // AppImageLoader resolves every R2 image through this one-shot provider.
    // Close its HTTP client so a long feed does not accumulate idle pools.
    provider.close();
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
