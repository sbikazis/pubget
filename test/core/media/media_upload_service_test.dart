import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/media/media_asset.dart';
import 'package:pubget/core/media/media_compressor.dart';
import 'package:pubget/core/media/media_kind.dart';
import 'package:pubget/core/media/media_upload_service.dart';

import 'media_test_support.dart';

void main() {
  late FakeMediaStorageProvider provider;
  late FakeMediaCompressor compressor;
  late List<Duration> delays;
  late MediaUploadService service;

  setUp(() {
    provider = FakeMediaStorageProvider(random: Random(7));
    compressor = FakeMediaCompressor();
    delays = <Duration>[];
    service = MediaUploadService(
      provider: provider,
      compressor: compressor,
      random: Random(7),
      clock: () => DateTime.utc(2026, 10, 17),
      delay: (duration) async => delays.add(duration),
    );
  });

  Future<Result<MediaAsset>> uploadImage({
    String ownerUid = 'alice',
    Uint8List? bytes,
    String? fileName = 'photo.jpg',
    bool Function()? isCancelled,
  }) {
    return service.upload(
      ownerUid: ownerUid,
      kind: MediaKind.image,
      bytes: bytes ?? jpegBytes,
      claimedContentType: 'image/jpeg',
      fileName: fileName,
      isCancelled: isCancelled,
    );
  }

  test('rejects an empty owner uid', () async {
    final result = await uploadImage(ownerUid: '   ');
    expect(result.failureOrNull, isA<PermissionError>());
    expect(provider.uploadCalls, isEmpty);
  });

  test('rejects bytes that are not accepted media', () async {
    final result = await uploadImage(bytes: htmlBytes);
    expect(result.failureOrNull, isA<ValidationError>());
    expect(provider.uploadCalls, isEmpty);
  });

  test('uploads a valid image and returns its metadata', () async {
    final result = await uploadImage();
    final asset = result.valueOrNull;
    expect(asset, isNotNull);
    expect(asset!.ownerUid, 'alice');
    expect(asset.kind, MediaKind.image);
    expect(asset.storageKey, startsWith('images/alice/'));
    expect(asset.contentType, 'image/jpeg');
    expect(asset.status, MediaUploadStatus.uploaded);
    expect(asset.sizeBytes, jpegBytes.length);
    expect(asset.originalFileName, 'photo.jpg');
    expect(asset.createdAt, DateTime.utc(2026, 10, 17));
    expect(asset.durationSeconds, isNull);
  });

  test('re-checks the hard ceiling on the compressed output', () async {
    compressor.result = CompressedMedia(
      bytes: Uint8List(20 * 1024 * 1024),
      contentType: 'image/jpeg',
    );
    final result = await uploadImage();
    expect(result.failureOrNull, isA<ValidationError>());
    expect(provider.uploadCalls, isEmpty);
  });

  test('retries transient failures, then succeeds', () async {
    provider.uploadErrors.addAll(<Object>[
      const NetworkError(),
      const TimeoutError(),
    ]);
    final result = await uploadImage();
    expect(result.isSuccess, isTrue);
    expect(provider.uploadCalls.length, 3);
    expect(delays, <Duration>[
      const Duration(milliseconds: 300),
      const Duration(milliseconds: 900),
    ]);
  });

  test('gives up after the attempt cap and returns the failure', () async {
    provider.uploadErrors.addAll(<Object>[
      const NetworkError(),
      const NetworkError(),
      const NetworkError(),
    ]);
    final result = await uploadImage();
    expect(result.failureOrNull, isA<NetworkError>());
    expect(provider.uploadCalls.length, 3);
  });

  test('does not retry a non-transient failure', () async {
    provider.uploadErrors.add(const ValidationError('bad'));
    final result = await uploadImage();
    expect(result.failureOrNull, isA<ValidationError>());
    expect(provider.uploadCalls.length, 1);
    expect(delays, isEmpty);
  });

  test('cancelling before the upload stops it with no stored object', () async {
    final result = await uploadImage(isCancelled: () => true);
    expect(result.failureOrNull, isA<CancelledError>());
    expect(provider.uploadCalls, isEmpty);
    expect(provider.deletedKeys, isEmpty);
  });

  test('cancelling after the object is stored deletes it', () async {
    var calls = 0;
    final result = await uploadImage(
      isCancelled: () => calls++ >= 4,
    );
    expect(result.failureOrNull, isA<CancelledError>());
    expect(provider.uploadCalls.length, 1);
    expect(provider.deletedKeys.length, 1);
  });

  group('duration', () {
    Future<Result<MediaAsset>> uploadVideo(Uint8List bytes) {
      return service.upload(
        ownerUid: 'alice',
        kind: MediaKind.reels,
        bytes: bytes,
        claimedContentType: 'video/mp4',
        fileName: 'clip.mp4',
      );
    }

    test('accepts a video inside the 3..60 s window', () async {
      final result = await uploadVideo(buildMp4Bytes(seconds: 30));
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.durationSeconds, 30);
    });

    test('rejects a video below the minimum length', () async {
      final result = await uploadVideo(buildMp4Bytes(seconds: 2));
      expect(result.failureOrNull, isA<ValidationError>());
      expect(result.failureOrNull?.message, contains('at least'));
      expect(provider.uploadCalls, isEmpty);
    });

    test('rejects a video above the maximum length', () async {
      final result = await uploadVideo(buildMp4Bytes(seconds: 61));
      expect(result.failureOrNull, isA<ValidationError>());
      expect(result.failureOrNull?.message, contains('at most'));
    });

    test('rejects a video whose duration cannot be verified', () async {
      final result = await uploadVideo(Uint8List.fromList(webmBytes));
      expect(result.failureOrNull, isA<ValidationError>());
    });
  });

  test('does not compress non-image media', () async {
    await service.upload(
      ownerUid: 'alice',
      kind: MediaKind.reels,
      bytes: buildMp4Bytes(seconds: 10),
      claimedContentType: 'video/mp4',
      fileName: 'clip.mp4',
    );
    expect(compressor.calls, isEmpty);
  });
}
