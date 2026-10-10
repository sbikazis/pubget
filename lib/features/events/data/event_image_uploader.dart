import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads poll-option images for events.
///
/// Staging lives under `events/{uid}/drafts/…`, which matches the Storage rule
/// `events/{userId}/{eventId}/{fileName}` (the draft bucket is just an
/// eventId-shaped prefix), so option images can be written before the draft
/// document exists and stay valid after publishing.
final class FirebaseEventImageUploader {
  FirebaseEventImageUploader({FirebaseStorage? storage}) : _storage = storage;

  final FirebaseStorage? _storage;

  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

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

  static String _bytesSeed(Uint8List bytes) {
    var seed = 0;
    final step = bytes.length > 64 ? bytes.length ~/ 8 : 1;
    for (var i = 0; i < bytes.length; i += step) {
      seed = (seed * 31 + bytes[i]) & 0x7fffffff;
    }
    return seed.toRadixString(16);
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

  /// Uploads one cropped option image and returns its download URL.
  Future<String> uploadOptionImage({
    required String uid,
    required Uint8List bytes,
  }) async {
    validate(uid: uid, bytes: bytes);
    final mime = contentType(bytes);
    final name =
        'opt_${DateTime.now().millisecondsSinceEpoch}_${_bytesSeed(bytes)}'
        '.${extensionFor(mime)}';
    final ref = storage.ref('events/$uid/drafts/$name');
    await ref.putData(bytes, SettableMetadata(contentType: mime));
    return ref.getDownloadURL();
  }
}