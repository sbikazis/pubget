import 'dart:typed_data';

import '../errors/failure.dart';
import '../errors/result.dart';
import 'media_kind.dart';
import 'media_repository.dart';

/// The narrow seam a feature repository uses to turn picked bytes into a
/// fetchable URL through the shared media stack.
///
/// Features store a URL in their own fields (e.g. `avatarUrl`), so this
/// adapter keeps that contract intact while the bytes themselves are
/// validated, compressed, stored and recorded by [MediaRepository] — the same
/// path every other feature will use. Nothing here is backend-specific: the
/// active provider decides where the bytes live.
abstract interface class MediaUrlUploader {
  /// Uploads one image and returns a fetchable URL, or the failure.
  Future<Result<String>> uploadImage({
    required String ownerUid,
    required Uint8List bytes,
    required String claimedContentType,
    String? fileName,
  });
}

final class RepositoryMediaUrlUploader implements MediaUrlUploader {
  RepositoryMediaUrlUploader({
    required MediaRepository repository,
    this.kind = MediaKind.image,
  }) : _repository = repository;

  final MediaRepository _repository;

  /// Which kind an image upload maps to. Avatars, covers and post images are
  /// all plain images, so the default is correct for them.
  final MediaKind kind;

  @override
  Future<Result<String>> uploadImage({
    required String ownerUid,
    required Uint8List bytes,
    required String claimedContentType,
    String? fileName,
  }) async {
    final uploaded = await _repository.upload(
      ownerUid: ownerUid,
      kind: kind,
      bytes: bytes,
      claimedContentType: claimedContentType,
      fileName: fileName,
    );
    final asset = uploaded.valueOrNull;
    if (asset == null) {
      return FailureResult<String>(
        uploaded.failureOrNull ?? const UnknownError('Upload failed.'),
      );
    }
    return _repository.resolveUrl(asset);
  }
}
