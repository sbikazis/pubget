import 'media_asset.dart';
import 'media_kind.dart';
import 'media_metadata_store.dart';

/// In-memory metadata store for tests — mirrors Firestore semantics closely
/// enough for repository logic (insert, patch, ordered listing).
final class InMemoryMediaMetadataStore implements MediaMetadataStore {
  final Map<String, MediaAsset> _documents = <String, MediaAsset>{};

  /// Every stored asset, for test assertions.
  List<MediaAsset> get all => _documents.values.toList(growable: false);

  @override
  Future<void> put(MediaAsset asset) async {
    _documents[asset.mediaId] = asset;
  }

  @override
  Future<MediaAsset?> get(String mediaId) async => _documents[mediaId];

  @override
  Future<void> patch(String mediaId, Map<String, dynamic> fields) async {
    final existing = _documents[mediaId];
    if (existing == null) return;
    var next = existing;
    final statusName = fields['status'] as String?;
    if (statusName != null) {
      MediaUploadStatus? status;
      for (final candidate in MediaUploadStatus.values) {
        if (candidate.name == statusName) status = candidate;
      }
      if (status != null) next = next.copyWith(status: status);
    }
    final updatedAt = fields['updatedAt'];
    if (updatedAt is DateTime) next = next.copyWith(updatedAt: updatedAt);
    _documents[mediaId] = next;
  }

  @override
  Future<void> remove(String mediaId) async {
    _documents.remove(mediaId);
  }

  @override
  Future<List<MediaAsset>> listForOwner(
    String ownerUid, {
    MediaKind? kind,
    int limit = 30,
    String? afterMediaId,
  }) async {
    var items = _documents.values
        .where((a) => a.ownerUid == ownerUid && (kind == null || a.kind == kind))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (afterMediaId != null) {
      final index = items.indexWhere((a) => a.mediaId == afterMediaId);
      if (index >= 0) items = items.sublist(index + 1);
    }
    return items.take(limit).toList(growable: false);
  }
}
