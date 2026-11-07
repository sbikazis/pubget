import 'dart:typed_data';

import '../../../core/media/media_kind.dart';
import '../../../core/media/media_repository_factory.dart';
import '../../../core/media/r2_media_storage_provider.dart';

/// Accepts legacy absolute URLs and stable private R2 object keys.
bool isRemoteHttpUrl(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed);
  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty) return true;
  if (trimmed.contains('://') || trimmed.startsWith('/')) return false;
  final parts = trimmed.split('/');
  final imageKey = parts.length == 3 && parts[0] == 'images' &&
      RegExp(r'^[A-Za-z0-9_-]{1,128}

/// Typed failure for group image uploads — never collapse to a fake "offline".
final class GroupImageUploadException implements Exception {
  const GroupImageUploadException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => code == null ? message : '[$code] $message';
}

abstract interface class GroupImageUploader {
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  });
}

final class FirebaseGroupImageUploader implements GroupImageUploader {
  FirebaseGroupImageUploader({R2MediaStorageProvider? mediaStorage})
    : _mediaStorage = mediaStorage ?? createR2MediaStorageProvider();

  final R2MediaStorageProvider _mediaStorage;

  static const maxBytes = 10 * 1024 * 1024;

  /// Shared preflight checks (also unit-tested without Firebase).
  static void validatePayload({
    required String uid,
    required Uint8List bytes,
  }) {
    if (uid.trim().isEmpty) {
      throw const GroupImageUploadException(
        'Sign in to upload a group image.',
        code: 'unauthenticated',
      );
    }
    if (bytes.isEmpty) {
      throw const GroupImageUploadException(
        'The selected image is empty.',
        code: 'empty-file',
      );
    }
    if (bytes.length > maxBytes) {
      throw const GroupImageUploadException(
        'Choose an image up to 10 MB.',
        code: 'too-large',
      );
    }
  }

  static String normalizeContentType(String contentType) {
    final raw = contentType.trim().toLowerCase();
    if (raw.startsWith('image/png')) return 'image/png';
    if (raw.startsWith('image/webp')) return 'image/webp';
    if (raw.startsWith('image/gif')) return 'image/gif';
    if (raw.startsWith('image/jpeg') || raw.startsWith('image/jpg')) {
      return 'image/jpeg';
    }
    // Crop tool exports PNG by default.
    return 'image/png';
  }

  static String extensionFor(String contentType) {
    return switch (normalizeContentType(contentType)) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'jpg',
    };
  }

  @override
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  }) async {
    validatePayload(uid: uid, bytes: bytes);
    final mime = normalizeContentType(contentType);
    final extension = extensionFor(mime);
    try {
      return await _mediaStorage.upload(
        ownerUid: uid,
        kind: MediaKind.image,
        bytes: bytes,
        contentType: mime,
        extension: extension,
      );
    } on Object catch (error) {
      throw GroupImageUploadException(
        'Cloudflare image upload failed: $error',
        code: 'upload-failed',
        cause: error,
      );
    }
  }


}

final class UnavailableGroupImageUploader implements GroupImageUploader {
  UnavailableGroupImageUploader([
    this.message = 'Image upload is unavailable in this build.',
  ]);

  final String message;

  @override
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  }) async {
    throw GroupImageUploadException(message, code: 'unavailable');
  }
}
).hasMatch(parts[1]) &&
      RegExp(r'^[A-Za-z0-9_-]{1,80}\.(jpg|jpeg|png|webp|gif)

/// Typed failure for group image uploads — never collapse to a fake "offline".
final class GroupImageUploadException implements Exception {
  const GroupImageUploadException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => code == null ? message : '[$code] $message';
}

abstract interface class GroupImageUploader {
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  });
}

final class FirebaseGroupImageUploader implements GroupImageUploader {
  FirebaseGroupImageUploader({R2MediaStorageProvider? mediaStorage})
    : _mediaStorage = mediaStorage ?? createR2MediaStorageProvider();

  final R2MediaStorageProvider _mediaStorage;

  static const maxBytes = 10 * 1024 * 1024;

  /// Shared preflight checks (also unit-tested without Firebase).
  static void validatePayload({
    required String uid,
    required Uint8List bytes,
  }) {
    if (uid.trim().isEmpty) {
      throw const GroupImageUploadException(
        'Sign in to upload a group image.',
        code: 'unauthenticated',
      );
    }
    if (bytes.isEmpty) {
      throw const GroupImageUploadException(
        'The selected image is empty.',
        code: 'empty-file',
      );
    }
    if (bytes.length > maxBytes) {
      throw const GroupImageUploadException(
        'Choose an image up to 10 MB.',
        code: 'too-large',
      );
    }
  }

  static String normalizeContentType(String contentType) {
    final raw = contentType.trim().toLowerCase();
    if (raw.startsWith('image/png')) return 'image/png';
    if (raw.startsWith('image/webp')) return 'image/webp';
    if (raw.startsWith('image/gif')) return 'image/gif';
    if (raw.startsWith('image/jpeg') || raw.startsWith('image/jpg')) {
      return 'image/jpeg';
    }
    // Crop tool exports PNG by default.
    return 'image/png';
  }

  static String extensionFor(String contentType) {
    return switch (normalizeContentType(contentType)) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'jpg',
    };
  }

  @override
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  }) async {
    validatePayload(uid: uid, bytes: bytes);
    final mime = normalizeContentType(contentType);
    final extension = extensionFor(mime);
    try {
      return await _mediaStorage.upload(
        ownerUid: uid,
        kind: MediaKind.image,
        bytes: bytes,
        contentType: mime,
        extension: extension,
      );
    } on Object catch (error) {
      throw GroupImageUploadException(
        'Cloudflare image upload failed: $error',
        code: 'upload-failed',
        cause: error,
      );
    }
  }


}

final class UnavailableGroupImageUploader implements GroupImageUploader {
  UnavailableGroupImageUploader([
    this.message = 'Image upload is unavailable in this build.',
  ]);

  final String message;

  @override
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  }) async {
    throw GroupImageUploadException(message, code: 'unavailable');
  }
}
).hasMatch(parts[2]);
  final scopedKey = parts.length == 4 && (parts[0] == 'groups' || parts[0] == 'privateChats') &&
      RegExp(r'^[A-Za-z0-9_:-]{1,320}

/// Typed failure for group image uploads — never collapse to a fake "offline".
final class GroupImageUploadException implements Exception {
  const GroupImageUploadException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => code == null ? message : '[$code] $message';
}

abstract interface class GroupImageUploader {
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  });
}

final class FirebaseGroupImageUploader implements GroupImageUploader {
  FirebaseGroupImageUploader({R2MediaStorageProvider? mediaStorage})
    : _mediaStorage = mediaStorage ?? createR2MediaStorageProvider();

  final R2MediaStorageProvider _mediaStorage;

  static const maxBytes = 10 * 1024 * 1024;

  /// Shared preflight checks (also unit-tested without Firebase).
  static void validatePayload({
    required String uid,
    required Uint8List bytes,
  }) {
    if (uid.trim().isEmpty) {
      throw const GroupImageUploadException(
        'Sign in to upload a group image.',
        code: 'unauthenticated',
      );
    }
    if (bytes.isEmpty) {
      throw const GroupImageUploadException(
        'The selected image is empty.',
        code: 'empty-file',
      );
    }
    if (bytes.length > maxBytes) {
      throw const GroupImageUploadException(
        'Choose an image up to 10 MB.',
        code: 'too-large',
      );
    }
  }

  static String normalizeContentType(String contentType) {
    final raw = contentType.trim().toLowerCase();
    if (raw.startsWith('image/png')) return 'image/png';
    if (raw.startsWith('image/webp')) return 'image/webp';
    if (raw.startsWith('image/gif')) return 'image/gif';
    if (raw.startsWith('image/jpeg') || raw.startsWith('image/jpg')) {
      return 'image/jpeg';
    }
    // Crop tool exports PNG by default.
    return 'image/png';
  }

  static String extensionFor(String contentType) {
    return switch (normalizeContentType(contentType)) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'jpg',
    };
  }

  @override
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  }) async {
    validatePayload(uid: uid, bytes: bytes);
    final mime = normalizeContentType(contentType);
    final extension = extensionFor(mime);
    try {
      return await _mediaStorage.upload(
        ownerUid: uid,
        kind: MediaKind.image,
        bytes: bytes,
        contentType: mime,
        extension: extension,
      );
    } on Object catch (error) {
      throw GroupImageUploadException(
        'Cloudflare image upload failed: $error',
        code: 'upload-failed',
        cause: error,
      );
    }
  }


}

final class UnavailableGroupImageUploader implements GroupImageUploader {
  UnavailableGroupImageUploader([
    this.message = 'Image upload is unavailable in this build.',
  ]);

  final String message;

  @override
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  }) async {
    throw GroupImageUploadException(message, code: 'unavailable');
  }
}
).hasMatch(parts[1]) &&
      RegExp(r'^[A-Za-z0-9_-]{1,128}

/// Typed failure for group image uploads — never collapse to a fake "offline".
final class GroupImageUploadException implements Exception {
  const GroupImageUploadException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => code == null ? message : '[$code] $message';
}

abstract interface class GroupImageUploader {
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  });
}

final class FirebaseGroupImageUploader implements GroupImageUploader {
  FirebaseGroupImageUploader({R2MediaStorageProvider? mediaStorage})
    : _mediaStorage = mediaStorage ?? createR2MediaStorageProvider();

  final R2MediaStorageProvider _mediaStorage;

  static const maxBytes = 10 * 1024 * 1024;

  /// Shared preflight checks (also unit-tested without Firebase).
  static void validatePayload({
    required String uid,
    required Uint8List bytes,
  }) {
    if (uid.trim().isEmpty) {
      throw const GroupImageUploadException(
        'Sign in to upload a group image.',
        code: 'unauthenticated',
      );
    }
    if (bytes.isEmpty) {
      throw const GroupImageUploadException(
        'The selected image is empty.',
        code: 'empty-file',
      );
    }
    if (bytes.length > maxBytes) {
      throw const GroupImageUploadException(
        'Choose an image up to 10 MB.',
        code: 'too-large',
      );
    }
  }

  static String normalizeContentType(String contentType) {
    final raw = contentType.trim().toLowerCase();
    if (raw.startsWith('image/png')) return 'image/png';
    if (raw.startsWith('image/webp')) return 'image/webp';
    if (raw.startsWith('image/gif')) return 'image/gif';
    if (raw.startsWith('image/jpeg') || raw.startsWith('image/jpg')) {
      return 'image/jpeg';
    }
    // Crop tool exports PNG by default.
    return 'image/png';
  }

  static String extensionFor(String contentType) {
    return switch (normalizeContentType(contentType)) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'jpg',
    };
  }

  @override
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  }) async {
    validatePayload(uid: uid, bytes: bytes);
    final mime = normalizeContentType(contentType);
    final extension = extensionFor(mime);
    try {
      return await _mediaStorage.upload(
        ownerUid: uid,
        kind: MediaKind.image,
        bytes: bytes,
        contentType: mime,
        extension: extension,
      );
    } on Object catch (error) {
      throw GroupImageUploadException(
        'Cloudflare image upload failed: $error',
        code: 'upload-failed',
        cause: error,
      );
    }
  }


}

final class UnavailableGroupImageUploader implements GroupImageUploader {
  UnavailableGroupImageUploader([
    this.message = 'Image upload is unavailable in this build.',
  ]);

  final String message;

  @override
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  }) async {
    throw GroupImageUploadException(message, code: 'unavailable');
  }
}
).hasMatch(parts[2]) &&
      RegExp(r'^[A-Za-z0-9_-]{1,80}\.(jpg|jpeg|png|webp|gif|mp4|webm|mov|mp3|m4a|aac|ogg)

/// Typed failure for group image uploads — never collapse to a fake "offline".
final class GroupImageUploadException implements Exception {
  const GroupImageUploadException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => code == null ? message : '[$code] $message';
}

abstract interface class GroupImageUploader {
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  });
}

final class FirebaseGroupImageUploader implements GroupImageUploader {
  FirebaseGroupImageUploader({R2MediaStorageProvider? mediaStorage})
    : _mediaStorage = mediaStorage ?? createR2MediaStorageProvider();

  final R2MediaStorageProvider _mediaStorage;

  static const maxBytes = 10 * 1024 * 1024;

  /// Shared preflight checks (also unit-tested without Firebase).
  static void validatePayload({
    required String uid,
    required Uint8List bytes,
  }) {
    if (uid.trim().isEmpty) {
      throw const GroupImageUploadException(
        'Sign in to upload a group image.',
        code: 'unauthenticated',
      );
    }
    if (bytes.isEmpty) {
      throw const GroupImageUploadException(
        'The selected image is empty.',
        code: 'empty-file',
      );
    }
    if (bytes.length > maxBytes) {
      throw const GroupImageUploadException(
        'Choose an image up to 10 MB.',
        code: 'too-large',
      );
    }
  }

  static String normalizeContentType(String contentType) {
    final raw = contentType.trim().toLowerCase();
    if (raw.startsWith('image/png')) return 'image/png';
    if (raw.startsWith('image/webp')) return 'image/webp';
    if (raw.startsWith('image/gif')) return 'image/gif';
    if (raw.startsWith('image/jpeg') || raw.startsWith('image/jpg')) {
      return 'image/jpeg';
    }
    // Crop tool exports PNG by default.
    return 'image/png';
  }

  static String extensionFor(String contentType) {
    return switch (normalizeContentType(contentType)) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'jpg',
    };
  }

  @override
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  }) async {
    validatePayload(uid: uid, bytes: bytes);
    final mime = normalizeContentType(contentType);
    final extension = extensionFor(mime);
    try {
      return await _mediaStorage.upload(
        ownerUid: uid,
        kind: MediaKind.image,
        bytes: bytes,
        contentType: mime,
        extension: extension,
      );
    } on Object catch (error) {
      throw GroupImageUploadException(
        'Cloudflare image upload failed: $error',
        code: 'upload-failed',
        cause: error,
      );
    }
  }


}

final class UnavailableGroupImageUploader implements GroupImageUploader {
  UnavailableGroupImageUploader([
    this.message = 'Image upload is unavailable in this build.',
  ]);

  final String message;

  @override
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  }) async {
    throw GroupImageUploadException(message, code: 'unavailable');
  }
}
).hasMatch(parts[3]);
  return imageKey || scopedKey;
}

/// Typed failure for group image uploads — never collapse to a fake "offline".
final class GroupImageUploadException implements Exception {
  const GroupImageUploadException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => code == null ? message : '[$code] $message';
}

abstract interface class GroupImageUploader {
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  });
}

final class FirebaseGroupImageUploader implements GroupImageUploader {
  FirebaseGroupImageUploader({R2MediaStorageProvider? mediaStorage})
    : _mediaStorage = mediaStorage ?? createR2MediaStorageProvider();

  final R2MediaStorageProvider _mediaStorage;

  static const maxBytes = 10 * 1024 * 1024;

  /// Shared preflight checks (also unit-tested without Firebase).
  static void validatePayload({
    required String uid,
    required Uint8List bytes,
  }) {
    if (uid.trim().isEmpty) {
      throw const GroupImageUploadException(
        'Sign in to upload a group image.',
        code: 'unauthenticated',
      );
    }
    if (bytes.isEmpty) {
      throw const GroupImageUploadException(
        'The selected image is empty.',
        code: 'empty-file',
      );
    }
    if (bytes.length > maxBytes) {
      throw const GroupImageUploadException(
        'Choose an image up to 10 MB.',
        code: 'too-large',
      );
    }
  }

  static String normalizeContentType(String contentType) {
    final raw = contentType.trim().toLowerCase();
    if (raw.startsWith('image/png')) return 'image/png';
    if (raw.startsWith('image/webp')) return 'image/webp';
    if (raw.startsWith('image/gif')) return 'image/gif';
    if (raw.startsWith('image/jpeg') || raw.startsWith('image/jpg')) {
      return 'image/jpeg';
    }
    // Crop tool exports PNG by default.
    return 'image/png';
  }

  static String extensionFor(String contentType) {
    return switch (normalizeContentType(contentType)) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'jpg',
    };
  }

  @override
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  }) async {
    validatePayload(uid: uid, bytes: bytes);
    final mime = normalizeContentType(contentType);
    final extension = extensionFor(mime);
    try {
      return await _mediaStorage.upload(
        ownerUid: uid,
        kind: MediaKind.image,
        bytes: bytes,
        contentType: mime,
        extension: extension,
      );
    } on Object catch (error) {
      throw GroupImageUploadException(
        'Cloudflare image upload failed: $error',
        code: 'upload-failed',
        cause: error,
      );
    }
  }


}

final class UnavailableGroupImageUploader implements GroupImageUploader {
  UnavailableGroupImageUploader([
    this.message = 'Image upload is unavailable in this build.',
  ]);

  final String message;

  @override
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  }) async {
    throw GroupImageUploadException(message, code: 'unavailable');
  }
}
