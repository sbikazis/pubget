import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

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
  FirebaseGroupImageUploader({FirebaseStorage? storage}) : _storage = storage;

  final FirebaseStorage? _storage;

  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

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
    final name =
        '${safeKind}_${DateTime.now().millisecondsSinceEpoch}.${extensionFor(mime)}';
    final path = 'users/$uid/group_staging/$name';
    final ref = storage.ref(path);
    try {
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: mime,
          customMetadata: <String, String>{
            'kind': safeKind,
            'clientBytes': '${bytes.length}',
          },
        ),
      );
      final url = await ref.getDownloadURL();
      if (!isRemoteHttpUrl(url)) {
        throw const GroupImageUploadException(
          'Upload did not return a download URL.',
          code: 'missing-url',
        );
      }
      return url;
    } on GroupImageUploadException {
      rethrow;
    } on FirebaseException catch (error) {
      // Preserve the real Storage code for logs/UI — do not invent "offline".
      throw GroupImageUploadException(
        _messageForFirebase(error),
        code: error.code,
        cause: error,
      );
    } on Object catch (error) {
      throw GroupImageUploadException(
        'Image upload failed: $error',
        code: 'unknown',
        cause: error,
      );
    }
  }

  static String _messageForFirebase(FirebaseException error) {
    final code = error.code.toLowerCase();
    if (code == 'unauthorized' || code == 'permission-denied') {
      return 'Storage rejected the upload (permission). Sign in again, then retry.';
    }
    if (code == 'canceled') return 'Upload was canceled.';
    if (code == 'retry-limit-exceeded' ||
        code == 'unavailable' ||
        code == 'network-request-failed') {
      return 'Network interrupted during upload. Retry the same image.';
    }
    if (code == 'object-not-found') {
      return 'Upload could not be verified in Storage.';
    }
    final detail = error.message?.trim();
    if (detail != null && detail.isNotEmpty) {
      return 'Upload failed ($code): $detail';
    }
    return 'Upload failed ($code).';
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
