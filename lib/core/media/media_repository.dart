import 'dart:typed_data';

import '../errors/result.dart';
import 'media_asset.dart';
import 'media_kind.dart';
import 'media_upload_service.dart';

/// The one entry point features use for media: upload, metadata, listing and
/// consistent deletion — backend-agnostic by construction.
abstract interface class MediaRepository {
  MediaBackend get backend;

  /// Validates, compresses, uploads and records metadata. On success the
  /// object exists *and* its Firestore record exists — never one without the
  /// other.
  Future<Result<MediaAsset>> upload({
    required String ownerUid,
    required MediaKind kind,
    required Uint8List bytes,
    required String claimedContentType,
    String? fileName,
    MediaUploadProgress? onProgress,
    bool Function()? isCancelled,
  });

  Future<Result<MediaAsset?>> getById(String mediaId);

  Future<Result<List<MediaAsset>>> listForOwner(
    String ownerUid, {
    MediaKind? kind,
    int limit,
    String? afterMediaId,
  });

  /// Deletes metadata and the storage object as one logical operation; see
  /// `DefaultMediaRepository.deleteMedia` for the ordering that prevents
  /// orphans.
  Future<Result<void>> deleteMedia(String mediaId);

  /// Resolves a fetchable URL for [asset].
  Future<Result<String>> resolveUrl(MediaAsset asset);
}
