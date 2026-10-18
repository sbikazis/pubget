import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import 'media_kind.dart';
import 'media_keys.dart';
import 'media_storage_provider.dart';

/// Stores bytes in Firebase Cloud Storage under `media/`-style prefixed keys
/// (`images/{uid}/{uuid}.jpg`, `reels/…`, `audio/…`).
///
/// The path shape is identical to the R2 provider so Firestore records stay
/// portable across backends. Writes are authorized by `storage.rules`
/// (`/{folder}/{uid}/{fileName}`), which re-check type, size and uploader.
final class FirebaseMediaStorageProvider implements MediaStorageProvider {
  FirebaseMediaStorageProvider({
    FirebaseStorage? storage,
    Random? random,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _random = random ?? Random.secure();

  final FirebaseStorage _storage;
  final Random _random;

  @override
  MediaBackend get backend => MediaBackend.firebase;

  @override
  Future<String> upload({
    required String ownerUid,
    required MediaKind kind,
    required Uint8List bytes,
    required String contentType,
    required String extension,
    void Function(double progress)? onProgress,
  }) async {
    final key = buildMediaKey(
      kind: kind,
      ownerUid: ownerUid,
      extension: extension,
      random: _random,
    );
    final reference = _storage.ref(key);
    final task = reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: <String, String>{'uploadedBy': ownerUid},
      ),
    );
    if (onProgress != null) {
      task.snapshotEvents.listen((snapshot) {
        final total = snapshot.totalBytes;
        if (total > 0) {
          onProgress(snapshot.bytesTransferred / total);
        }
      });
    }
    await task;
    return key;
  }

  @override
  Future<void> delete(String storageKey) async {
    try {
      await _storage.ref(storageKey).delete();
    } on FirebaseException catch (error) {
      // Deleting what is already gone is success, not a failure — the
      // repository relies on this to finish a half-completed delete.
      final code = error.code.toLowerCase();
      if (code == 'object-not-found' || code == 'not-found') return;
      rethrow;
    }
  }

  @override
  Future<String> resolveUrl(String storageKey) =>
      _storage.ref(storageKey).getDownloadURL();
}
