import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

bool isRemoteHttpUrl(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.startsWith('https://') || trimmed.startsWith('http://');
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
  FirebaseGroupImageUploader({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  static const maxBytes = 10 * 1024 * 1024;

  @override
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  }) async {
    if (uid.trim().isEmpty) {
      throw StateError('Sign in to upload a group image.');
    }
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw StateError('Choose an image up to 10 MB.');
    }
    final safeKind = kind.trim().isEmpty ? 'image' : kind.trim();
    final name = '${safeKind}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref('users/$uid/group_staging/$name');
    final mime = contentType.startsWith('image/')
        ? contentType
        : 'image/jpeg';
    await ref.putData(bytes, SettableMetadata(contentType: mime));
    final url = await ref.getDownloadURL();
    if (!isRemoteHttpUrl(url)) {
      throw StateError('Upload did not return a download URL.');
    }
    return url;
  }
}

final class UnavailableGroupImageUploader implements GroupImageUploader {
  UnavailableGroupImageUploader([this.message = 'Image upload is unavailable.']);

  final String message;

  @override
  Future<String> uploadGroupImage({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required String kind,
  }) async {
    throw StateError(message);
  }
}
