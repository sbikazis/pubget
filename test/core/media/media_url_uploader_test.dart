import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/media/media_asset.dart';
import 'package:pubget/core/media/media_kind.dart';
import 'package:pubget/core/media/media_repository.dart';
import 'package:pubget/core/media/media_upload_service.dart';
import 'package:pubget/core/media/media_url_uploader.dart';

import 'media_test_support.dart';

/// Records the upload call and returns a scripted result, so the adapter's
/// contract can be checked without any backend.
final class FakeMediaRepository implements MediaRepository {
  FakeMediaRepository({this.uploadResult, this.resolveResult, this.backendValue = MediaBackend.firebase});

  Result<MediaAsset>? uploadResult;
  Result<String>? resolveResult;
  MediaBackend backendValue;

  final List<Map<String, Object?>> uploadCalls = <Map<String, Object?>>[];
  final List<MediaAsset> resolvedAssets = <MediaAsset>[];

  MediaAsset _asset() => MediaAsset(
        mediaId: 'm1',
        ownerUid: 'alice',
        storageKey: 'images/alice/m1.jpg',
        backend: MediaBackend.firebase,
        kind: MediaKind.image,
        contentType: 'image/jpeg',
        sizeBytes: 3,
        createdAt: DateTime(2026, 1, 1),
      );

  @override
  MediaBackend get backend => backendValue;

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
    uploadCalls.add(<String, Object?>{
      'ownerUid': ownerUid,
      'kind': kind,
      'bytes': bytes,
      'claimedContentType': claimedContentType,
      'fileName': fileName,
    });
    return uploadResult ?? Success<MediaAsset>(_asset());
  }

  @override
  Future<Result<MediaAsset?>> getById(String mediaId) async =>
      const Success<MediaAsset?>(null);

  @override
  Future<Result<List<MediaAsset>>> listForOwner(
    String ownerUid, {
    MediaKind? kind,
    int limit = 30,
    String? afterMediaId,
  }) async => const Success<List<MediaAsset>>(<MediaAsset>[]);

  @override
  Future<Result<void>> deleteMedia(String mediaId) async =>
      const Success<void>(null);

  @override
  Future<Result<String>> resolveUrl(MediaAsset asset) async {
    resolvedAssets.add(asset);
    return resolveResult ??
        Success<String>('https://cdn.test/${asset.storageKey}');
  }
}

void main() {
  final bytes = Uint8List.fromList(jpegBytes);

  test('uploadImage returns the resolved URL on success', () async {
    final repository = FakeMediaRepository();
    final uploader = RepositoryMediaUrlUploader(repository: repository);

    final result = await uploader.uploadImage(
      ownerUid: 'alice',
      bytes: bytes,
      claimedContentType: 'image/jpeg',
      fileName: 'avatar.jpg',
    );

    expect(result.valueOrNull, 'https://cdn.test/images/alice/m1.jpg');
    expect(repository.uploadCalls, hasLength(1));
    expect(repository.uploadCalls.single['ownerUid'], 'alice');
    expect(repository.uploadCalls.single['kind'], MediaKind.image);
    expect(repository.uploadCalls.single['fileName'], 'avatar.jpg');
    expect(repository.resolvedAssets, hasLength(1));
  });

  test('uploadImage propagates an upload failure and never resolves', () async {
    final repository = FakeMediaRepository(
      uploadResult: const FailureResult<MediaAsset>(
        PermissionError('Sign in to upload media.'),
      ),
    );
    final uploader = RepositoryMediaUrlUploader(repository: repository);

    final result = await uploader.uploadImage(
      ownerUid: '',
      bytes: bytes,
      claimedContentType: 'image/jpeg',
    );

    expect(result.failureOrNull, isA<PermissionError>());
    expect(repository.resolvedAssets, isEmpty);
  });

  test('uploadImage surfaces a resolve failure', () async {
    final repository = FakeMediaRepository(
      resolveResult: const FailureResult<String>(
        NetworkError('Check your connection and try again.'),
      ),
    );
    final uploader = RepositoryMediaUrlUploader(repository: repository);

    final result = await uploader.uploadImage(
      ownerUid: 'alice',
      bytes: bytes,
      claimedContentType: 'image/jpeg',
    );

    expect(result.failureOrNull, isA<NetworkError>());
  });

  test('uploadImage uses the configured kind', () async {
    final repository = FakeMediaRepository();
    final uploader = RepositoryMediaUrlUploader(
      repository: repository,
      kind: MediaKind.image,
    );

    await uploader.uploadImage(
      ownerUid: 'alice',
      bytes: bytes,
      claimedContentType: 'image/jpeg',
    );

    expect(repository.uploadCalls.single['kind'], MediaKind.image);
  });
}
