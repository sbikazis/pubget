import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/media/default_media_repository.dart';
import 'package:pubget/core/media/in_memory_media_metadata_store.dart';
import 'package:pubget/core/media/media_asset.dart';
import 'package:pubget/core/media/media_kind.dart';
import 'package:pubget/core/media/media_metadata_store.dart';
import 'package:pubget/core/media/media_upload_service.dart';

import 'media_test_support.dart';

/// A store whose write fails, to prove the repository rolls back the object.
final class ThrowingMediaMetadataStore implements MediaMetadataStore {
  final InMemoryMediaMetadataStore _inner = InMemoryMediaMetadataStore();
  bool failPut = false;

  @override
  Future<void> put(MediaAsset asset) async {
    if (failPut) throw const UnknownError('firestore down');
    return _inner.put(asset);
  }

  @override
  Future<MediaAsset?> get(String mediaId) => _inner.get(mediaId);

  @override
  Future<void> patch(String mediaId, Map<String, dynamic> fields) =>
      _inner.patch(mediaId, fields);

  @override
  Future<void> remove(String mediaId) => _inner.remove(mediaId);

  @override
  Future<List<MediaAsset>> listForOwner(
    String ownerUid, {
    MediaKind? kind,
    int limit = 30,
    String? afterMediaId,
  }) =>
      _inner.listForOwner(
        ownerUid,
        kind: kind,
        limit: limit,
        afterMediaId: afterMediaId,
      );
}

void main() {
  late FakeMediaStorageProvider provider;
  late ThrowingMediaMetadataStore store;
  late DefaultMediaRepository repository;

  setUp(() {
    provider = FakeMediaStorageProvider(random: Random(7));
    store = ThrowingMediaMetadataStore();
    final uploadService = MediaUploadService(
      provider: provider,
      compressor: FakeMediaCompressor(),
      random: Random(7),
      clock: () => DateTime.utc(2026, 10, 17),
    );
    repository = DefaultMediaRepository(
      uploadService: uploadService,
      store: store,
      provider: provider,
    );
  });

  Future<MediaAsset> uploadOne() async {
    final result = await repository.upload(
      ownerUid: 'alice',
      kind: MediaKind.image,
      bytes: jpegBytes,
      claimedContentType: 'image/jpeg',
      fileName: 'photo.jpg',
    );
    return result.valueOrNull!;
  }

  test('upload stores metadata and lists it back', () async {
    final asset = await uploadOne();
    final fetched = (await repository.getById(asset.mediaId)).valueOrNull;
    expect(fetched?.storageKey, asset.storageKey);

    final list = (await repository.listForOwner('alice')).valueOrNull;
    expect(list, hasLength(1));
    expect(list!.single.mediaId, asset.mediaId);
  });

  test('upload rolls back the object when the metadata write fails', () async {
    store.failPut = true;
    final result = await repository.upload(
      ownerUid: 'alice',
      kind: MediaKind.image,
      bytes: jpegBytes,
      claimedContentType: 'image/jpeg',
    );
    expect(result.failureOrNull, isA<UnknownError>());
    expect(provider.uploadCalls, hasLength(1));
    expect(provider.deletedKeys, hasLength(1));
  });

  test('deleteMedia removes both the object and the record', () async {
    final asset = await uploadOne();
    final result = await repository.deleteMedia(asset.mediaId);
    expect(result.isSuccess, isTrue);
    expect(provider.deletedKeys, contains(asset.storageKey));
    expect((await repository.getById(asset.mediaId)).valueOrNull, isNull);
  });

  test('deleteMedia is a no-op for an unknown id', () async {
    final result = await repository.deleteMedia('does-not-exist');
    expect(result.isSuccess, isTrue);
    expect(provider.deletedKeys, isEmpty);
  });

  test('deleteMedia keeps the record retryable when storage delete fails', () async {
    final asset = await uploadOne();
    provider.deleteError = const NetworkError();

    final result = await repository.deleteMedia(asset.mediaId);
    expect(result.failureOrNull, isA<NetworkError>());

    final record = (await repository.getById(asset.mediaId)).valueOrNull;
    expect(record, isNotNull);
    expect(record!.status, MediaUploadStatus.deleting);
  });

  test('deleteMedia finishes cleanup when the record was already deleted', () async {
    final asset = await uploadOne();
    await store.patch(asset.mediaId, <String, dynamic>{
      'status': MediaUploadStatus.deleted.name,
    });

    final result = await repository.deleteMedia(asset.mediaId);
    expect(result.isSuccess, isTrue);
    expect(provider.deletedKeys, isEmpty);
    expect((await repository.getById(asset.mediaId)).valueOrNull, isNull);
  });

  test('resolveUrl uses the provider for a matching backend', () async {
    final asset = await uploadOne();
    final url = (await repository.resolveUrl(asset)).valueOrNull;
    expect(url, 'fake://${asset.storageKey}');
  });

  test('resolveUrl refuses an asset from an unconfigured backend', () async {
    final asset = await uploadOne();
    final foreign = MediaAsset(
      mediaId: asset.mediaId,
      ownerUid: asset.ownerUid,
      storageKey: asset.storageKey,
      backend: MediaBackend.r2,
      kind: asset.kind,
      contentType: asset.contentType,
      sizeBytes: asset.sizeBytes,
      createdAt: asset.createdAt,
    );
    final result = await repository.resolveUrl(foreign);
    expect(result.failureOrNull, isA<NotFoundError>());
  });
}
