import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pubget/core/media/media_asset.dart';
import 'package:pubget/core/media/media_kind.dart';

void main() {
  final createdAt = DateTime.utc(2026, 10, 17, 12);

  MediaAsset buildAsset() => MediaAsset(
        mediaId: 'media-1',
        ownerUid: 'alice',
        storageKey: 'reels/alice/clip.mp4',
        backend: MediaBackend.r2,
        kind: MediaKind.reels,
        contentType: 'video/mp4',
        sizeBytes: 1234,
        createdAt: createdAt,
        durationSeconds: 30,
        width: 1080,
        height: 1920,
        originalFileName: 'clip.mp4',
        updatedAt: createdAt,
      );

  group('toMap / fromMap', () {
    test('round-trips a full record', () {
      final asset = buildAsset();
      final restored = MediaAsset.fromMap(asset.toMap());
      expect(restored, isNotNull);
      expect(restored!.mediaId, asset.mediaId);
      expect(restored.ownerUid, 'alice');
      expect(restored.backend, MediaBackend.r2);
      expect(restored.kind, MediaKind.reels);
      expect(restored.status, MediaUploadStatus.uploaded);
      expect(restored.durationSeconds, 30);
      expect(restored.createdAt.toUtc(), createdAt);
    });

    test('stores timestamps as Firestore Timestamps', () {
      final map = buildAsset().toMap();
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
    });

    test('returns null when required fields are missing', () {
      expect(MediaAsset.fromMap(null), isNull);
      expect(MediaAsset.fromMap(<String, dynamic>{'mediaId': 'x'}), isNull);
    });

    test('returns null for an unknown kind', () {
      final map = buildAsset().toMap()..['kind'] = 'not-a-kind';
      expect(MediaAsset.fromMap(map), isNull);
    });

    test('defaults the status when it is absent or unrecognized', () {
      final map = buildAsset().toMap()..remove('status');
      expect(MediaAsset.fromMap(map)?.status, MediaUploadStatus.uploaded);

      final weird = buildAsset().toMap()..['status'] = 'nonsense';
      expect(MediaAsset.fromMap(weird)?.status, MediaUploadStatus.uploaded);
    });
  });

  test('copyWith only changes the fields it is given', () {
    final asset = buildAsset();
    final next = asset.copyWith(status: MediaUploadStatus.deleting);
    expect(next.status, MediaUploadStatus.deleting);
    expect(next.storageKey, asset.storageKey);
    expect(next.sizeBytes, asset.sizeBytes);
    expect(next.durationSeconds, asset.durationSeconds);
  });
}
