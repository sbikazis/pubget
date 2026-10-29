import 'dart:typed_data';

import '../../../core/storage/media_upload_service.dart';

bool isRemoteHttpUrl(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.startsWith('https://') || trimmed.startsWith('http://');
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
  FirebaseGroupImageUploader({MediaUploadService? mediaUploadService})
      : _mediaUploadService = mediaUploadService ?? MediaUploadService();

  final MediaUploadService _mediaUploadService;

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
    final safeKind = kind.trim().isEmpty ? 'image' : kind.trim();
    try {
      final extension = extensionFor(mime);
      final result = await _mediaUploadService.uploadImageBytes(
        userId: uid,
        bytes: bytes,
        extension: extension,
      );
      final url = result.downloadUrl;
      if (!isRemoteHttpUrl(url)) {
        throw const GroupImageUploadException(
          'Upload did not return a download URL.',
          code: 'missing-url',
        );
      }
      return url;
    } on GroupImageUploadException {
      rethrow;
    } on Object catch (error) {
      throw GroupImageUploadException(
        'Image upload failed: $error',
        code: 'unknown',
        cause: error,
      );
    }
  }

  static String _messageForFirebase(Object error) {
    return 'Upload failed: $error';
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
