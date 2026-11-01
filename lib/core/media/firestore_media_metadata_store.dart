import 'package:cloud_firestore/cloud_firestore.dart';

import 'media_asset.dart';
import 'media_kind.dart';
import 'media_metadata_store.dart';

/// Firestore-backed metadata store for the `media` collection.
///
/// Every read/write is scoped to a document the caller already owns — the
/// security rules re-check ownership regardless (see `firestore.rules`,
/// `/media/{mediaId}`).
final class FirestoreMediaMetadataStore implements MediaMetadataStore {
  FirestoreMediaMetadataStore({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collectionName = 'media';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  @override
  Future<void> put(MediaAsset asset) =>
      _collection.doc(asset.mediaId).set(asset.toMap());

  @override
  Future<MediaAsset?> get(String mediaId) async {
    final snapshot = await _collection.doc(mediaId).get();
    return MediaAsset.fromMap(snapshot.data());
  }

  @override
  Future<void> patch(String mediaId, Map<String, dynamic> fields) =>
      _collection.doc(mediaId).update(fields);

  @override
  Future<void> remove(String mediaId) =>
      _collection.doc(mediaId).delete();

  @override
  Future<List<MediaAsset>> listForOwner(
    String ownerUid, {
    MediaKind? kind,
    int limit = 30,
    String? afterMediaId,
  }) async {
    Query<Map<String, dynamic>> query = _collection
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (kind != null) {
      query = query.where('kind', isEqualTo: kind.name);
    }
    if (afterMediaId != null) {
      final anchor = await _collection.doc(afterMediaId).get();
      final data = anchor.data();
      if (data != null && data['createdAt'] != null) {
        query = query.startAfter(<Object?>[data['createdAt']]);
      }
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => MediaAsset.fromMap(doc.data()))
        .whereType<MediaAsset>()
        .toList(growable: false);
  }
}
