import 'media_asset.dart';
import 'media_kind.dart';

/// Persistence for media *metadata* only (Firestore `media` collection).
///
/// Bytes never go through this interface — that is `MediaStorageProvider`'s
/// job. Keeping the two apart is what makes a backend swap possible without
/// touching feature code.
abstract interface class MediaMetadataStore {
  Future<void> put(MediaAsset asset);

  Future<MediaAsset?> get(String mediaId);

  /// Applies a partial update; [fields] must only contain allowed keys.
  Future<void> patch(String mediaId, Map<String, dynamic> fields);

  Future<void> remove(String mediaId);

  /// Newest-first listing of [ownerUid]'s media, optionally by [kind].
  /// [afterMediaId] continues a previous page.
  Future<List<MediaAsset>> listForOwner(
    String ownerUid, {
    MediaKind? kind,
    int limit = 30,
    String? afterMediaId,
  });
}
