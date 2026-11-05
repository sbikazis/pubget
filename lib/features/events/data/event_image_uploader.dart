import 'dart:typed_data';

import '../../../core/media/media_kind.dart';
import '../../../core/media/media_repository_factory.dart';
import '../../../core/media/r2_media_storage_provider.dart';

/// Uploads poll-option images for events.
///
/// Draft images are stored as owner-scoped R2 objects. The stable object key
/// is persisted with the event and resolved through the media Worker.
final class FirebaseEventImageUploader {
  FirebaseEventImageUploader({R2MediaStorageProvider? mediaStorage})
    : _mediaStorage = mediaStorage ?? createR2MediaStorageProvider();

  final R2MediaStorageProvider _mediaStorage;

  static const maxBytes = 5 * 1024 * 1024;

  static String contentType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  static String extensionFor(String contentType) {
    return switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'jpg',
    };
  }

  void validate({required String uid, required Uint8List bytes}) {
    if (uid.trim().isEmpty) {
      throw const FormatException('Sign in to upload an event image.');
    }
    if (bytes.isEmpty) {
      throw const FormatException('The selected image is empty.');
    }
    if (bytes.length > maxBytes) {
      throw const FormatException('Choose an image up to 5 MB.');
    }
  }

  /// Uploads one cropped option image and returns its stable R2 object key.
  Future<String> uploadOptionImage({
    required String uid,
    required Uint8List bytes,
  }) async {
    validate(uid: uid, bytes: bytes);
    final mime = contentType(bytes);
    return _mediaStorage.upload(
      ownerUid: uid,
      kind: MediaKind.image,
      bytes: bytes,
      contentType: mime,
      extension: extensionFor(mime),
    );
  }
}