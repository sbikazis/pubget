import 'dart:typed_data';

import '../errors/failure.dart';
import '../errors/result.dart';
import 'media_asset.dart';
import 'media_kind.dart';
import 'media_repository.dart';
import 'media_upload_service.dart';

/// Media repository used when Firebase is not ready in this build. Every
/// call fails with one clear message instead of throwing.
final class UnavailableMediaRepository implements MediaRepository {
  const UnavailableMediaRepository(this.message);

  final String message;

  FailureResult<T> _failure<T>() => FailureResult(UnavailableError(message));

  @override
  MediaBackend get backend => MediaBackend.firebase;

  @override
  Future<Result<MediaAsset>> upload({
    required String ownerUid,
    required MediaKind kind,
    required Uint8List bytes,
    required String claimedContentType,
    String? fileName,
    MediaUploadProgress? onProgress,
    bool Function()? isCancelled,
  }) async =>
      _failure();

  @override
  Future<Result<MediaAsset?>> getById(String mediaId) async => _failure();

  @override
  Future<Result<List<MediaAsset>>> listForOwner(
    String ownerUid, {
    MediaKind? kind,
    int limit = 30,
    String? afterMediaId,
  }) async =>
      _failure();

  @override
  Future<Result<void>> deleteMedia(String mediaId) async => _failure();

  @override
  Future<Result<String>> resolveUrl(MediaAsset asset) async => _failure();
}
