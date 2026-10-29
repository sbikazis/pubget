import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../errors/failure.dart';
import '../errors/result.dart';
import 'media_asset.dart';
import 'media_kind.dart';
import 'media_metadata_store.dart';
import 'media_repository.dart';
import 'media_storage_provider.dart';
import 'media_upload_service.dart';

/// The standard [MediaRepository]: one upload service, one metadata store,
/// one storage provider.
///
/// ## Deletion ordering (Firestore ↔ storage consistency)
/// 1. load the record — nothing to do when it is already gone;
/// 2. mark `status = deleting` (the transitional marker);
/// 3. delete the storage object (providers are idempotent — a missing object
///    counts as deleted);
/// 4. delete the record.
///
/// Failures at step 3 leave the record in `deleting`, which is safe and
/// retryable — no unreachable object is ever orphaned silently. Failures at
/// step 4 leave a record pointing at an already-deleted object; the next
/// retry passes step 3 trivially and finishes step 4.
final class DefaultMediaRepository implements MediaRepository {
  DefaultMediaRepository({
    required MediaUploadService uploadService,
    required MediaMetadataStore store,
    required MediaStorageProvider provider,
  })  : _uploadService = uploadService,
        _store = store,
        _provider = provider;

  final MediaUploadService _uploadService;
  final MediaMetadataStore _store;
  final MediaStorageProvider _provider;

  @override
  MediaBackend get backend => _provider.backend;

  @override
  Future<Result<MediaAsset>> upload({
    required String ownerUid,
    required MediaKind kind,
    required Uint8List bytes,
    required String claimedContentType,
    String? fileName,
    MediaUploadProgress? onProgress,
    bool Function()? isCancelled,
  }) async {
    final upload = await _uploadService.upload(
      ownerUid: ownerUid,
      kind: kind,
      bytes: bytes,
      claimedContentType: claimedContentType,
      fileName: fileName,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    final asset = upload.valueOrNull;
    if (asset == null) return FailureResult(upload.failureOrNull!);

    try {
      await _store.put(asset);
      return Success(asset);
    } on Object catch (error) {
      // Metadata write failed after the bytes landed: remove the object so
      // no unreachable bytes remain, then surface the original problem.
      try {
        await _provider.delete(asset.storageKey);
      } on Object {
        // The delete path above is best-effort; `deleteMedia` can clean up.
      }
      return FailureResult(mapMediaException(error));
    }
  }

  @override
  Future<Result<MediaAsset?>> getById(String mediaId) async {
    try {
      return Success(await _store.get(mediaId));
    } on Object catch (error) {
      return FailureResult(mapMediaException(error));
    }
  }

  @override
  Future<Result<List<MediaAsset>>> listForOwner(
    String ownerUid, {
    MediaKind? kind,
    int limit = 30,
    String? afterMediaId,
  }) async {
    try {
      return Success(
        await _store.listForOwner(
          ownerUid,
          kind: kind,
          limit: limit,
          afterMediaId: afterMediaId,
        ),
      );
    } on Object catch (error) {
      return FailureResult(mapMediaException(error));
    }
  }

  @override
  Future<Result<void>> deleteMedia(String mediaId) async {
    try {
      final asset = await _store.get(mediaId);
      if (asset == null) return const Success(null);
      if (asset.status == MediaUploadStatus.deleted) {
        await _store.remove(mediaId);
        return const Success(null);
      }

      await _store.patch(mediaId, <String, dynamic>{
        'status': MediaUploadStatus.deleting.name,
        'updatedAt': DateTime.now(),
      });

      try {
        await _provider.delete(asset.storageKey);
      } on Object catch (error) {
        // Storage step failed — the record stays `deleting` (retryable) and
        // the object is untouched, so nothing becomes orphaned.
        return FailureResult(mapMediaException(error));
      }

      try {
        await _store.remove(mediaId);
      } on Object catch (error) {
        return FailureResult(mapMediaException(error));
      }
      return const Success(null);
    } on Object catch (error) {
      return FailureResult(mapMediaException(error));
    }
  }

  @override
  Future<Result<String>> resolveUrl(MediaAsset asset) async {
    try {
      if (asset.backend == _provider.backend) {
        return Success(await _provider.resolveUrl(asset.storageKey));
      }
      if (asset.backend == MediaBackend.firebase) {
        // Record was written when Firebase was the active backend; resolving
        // it directly keeps old media readable across a backend change.
        return Success(
          await FirebaseStorage.instance.ref(asset.storageKey).getDownloadURL(),
        );
      }
      return FailureResult(
        NotFoundError(
          'This file was stored on a backend that is not configured here.',
        ),
      );
    } on Object catch (error) {
      return FailureResult(mapMediaException(error));
    }
  }

}
