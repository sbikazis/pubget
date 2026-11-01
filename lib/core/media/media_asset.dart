import 'package:cloud_firestore/cloud_firestore.dart';

import 'media_kind.dart';

/// Lifecycle of an upload as recorded in Firestore.
enum MediaUploadStatus {
  /// Bytes validated but not yet accepted by the backend.
  pending,

  /// Backend accepted the object; metadata written.
  uploaded,

  /// Upload failed; no object should remain, metadata marks the failure.
  failed,

  /// Delete requested — the transitional state that keeps Firestore and the
  /// storage backend consistent (see `MediaRepository.deleteMedia`).
  deleting,

  /// Storage object is gone (or was already gone); metadata follows.
  deleted,
}

/// The Firestore record for one media object.
///
/// Only metadata is stored — never bytes, never a permanent public URL as the
/// sole reference. Rendering resolves [storageKey] through the backend.
final class MediaAsset {
  const MediaAsset({
    required this.mediaId,
    required this.ownerUid,
    required this.storageKey,
    required this.backend,
    required this.kind,
    required this.contentType,
    required this.sizeBytes,
    required this.createdAt,
    this.status = MediaUploadStatus.uploaded,
    this.durationSeconds,
    this.width,
    this.height,
    this.originalFileName,
    this.updatedAt,
  });

  final String mediaId;
  final String ownerUid;
  final String storageKey;
  final MediaBackend backend;
  final MediaKind kind;
  final String contentType;
  final int sizeBytes;
  final DateTime createdAt;
  final MediaUploadStatus status;

  /// Present for video/audio when the duration was read from the container.
  final int? durationSeconds;
  final int? width;
  final int? height;

  /// Original client file name — advisory only, never used as a storage key.
  final String? originalFileName;
  final DateTime? updatedAt;

  MediaAsset copyWith({
    MediaUploadStatus? status,
    int? sizeBytes,
    int? durationSeconds,
    DateTime? updatedAt,
  }) {
    return MediaAsset(
      mediaId: mediaId,
      ownerUid: ownerUid,
      storageKey: storageKey,
      backend: backend,
      kind: kind,
      contentType: contentType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt,
      status: status ?? this.status,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      width: width,
      height: height,
      originalFileName: originalFileName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'mediaId': mediaId,
        'ownerUid': ownerUid,
        'storageKey': storageKey,
        'backend': backend.name,
        'kind': kind.name,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
        'status': status.name,
        'durationSeconds': durationSeconds,
        'width': width,
        'height': height,
        'originalFileName': originalFileName,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt':
            updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      };

  static MediaAsset? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final mediaId = map['mediaId'] as String?;
    final ownerUid = map['ownerUid'] as String?;
    final storageKey = map['storageKey'] as String?;
    final kindName = map['kind'] as String?;
    if (mediaId == null ||
        ownerUid == null ||
        storageKey == null ||
        kindName == null) {
      return null;
    }
    final kind = _enumByName(MediaKind.values, kindName);
    if (kind == null) return null;
    final backendName = map['backend'] as String?;
    final backend = _enumByName(
      MediaBackend.values,
      backendName ?? MediaBackend.firebase.name,
    );
    if (backend == null) return null;
    final statusName = map['status'] as String?;
    final status = statusName == null
        ? MediaUploadStatus.uploaded
        : _enumByName(MediaUploadStatus.values, statusName) ??
            MediaUploadStatus.uploaded;

    return MediaAsset(
      mediaId: mediaId,
      ownerUid: ownerUid,
      storageKey: storageKey,
      backend: backend,
      kind: kind,
      contentType: (map['contentType'] as String?) ?? '',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      createdAt: _toDateTime(map['createdAt']) ?? DateTime.now(),
      status: status,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt(),
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      originalFileName: map['originalFileName'] as String?,
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

T? _enumByName<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
