import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pubget/models/edits_model.dart';

class EditsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  double _score(EditModel e) {
    final ageHours =
        DateTime.now().difference(e.createdAt).inHours.toDouble();
    final interactionScore =
        (e.likes.length * 3.0) + (e.views * 0.5) + (e.commentsCount * 2.0);
    final decayFactor = 1.0 / (1.0 + (ageHours / 24.0));
    return interactionScore * decayFactor + (1.0 / (1.0 + ageHours * 0.01));
  }

  Stream<List<EditModel>> getEdits({required Set<String> Function() seenIdsGetter}) {
    return _firestore.collection('edits').snapshots().map((snap) {
      final seenIds = seenIdsGetter();
      final list = snap.docs.map(EditModel.fromFirestore).toList();
      final unseen = list.where((e) => !seenIds.contains(e.id)).toList();
      final seen = list.where((e) => seenIds.contains(e.id)).toList();
      unseen.sort((a, b) => _score(b).compareTo(_score(a)));
      seen.sort((a, b) => _score(b).compareTo(_score(a)));
      return [...unseen, ...seen];
    });
  }

  Stream<List<EditModel>> getUserEdits(String userId) {
    return _firestore
        .collection('edits')
        .where('uploaderId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(EditModel.fromFirestore).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<String> uploadVideo(File file, String userId) async {
    final ref = _storage
        .ref()
        .child('edits/$userId/v_${DateTime.now().millisecondsSinceEpoch}.mp4');
    await ref.putFile(file, SettableMetadata(contentType: 'video/mp4'));
    return await ref.getDownloadURL();
  }

  Future<String> uploadThumbnail(File file, String userId) async {
    final ref = _storage
        .ref()
        .child('edits/$userId/t_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  Future<String> postEdit(EditModel edit) async {
    final doc = await _firestore.collection('edits').add(edit.toMap());
    return doc.id;
  }

  Future<void> toggleLike(String editId, String userId) async {
    final ref = _firestore.collection('edits').doc(editId);
    final doc = await ref.get();
    final likes = List<String>.from(doc['likes'] ?? []);
    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
    }
    await ref.update({'likes': likes});
  }

  Future<void> incrementViews(String editId, String userId) async {
    final viewRef = _firestore
        .collection('edits')
        .doc(editId)
        .collection('viewers')
        .doc(userId);

    final existing = await viewRef.get();
    if (existing.exists) return;

    await viewRef.set({'viewedAt': FieldValue.serverTimestamp()});
    await _firestore.collection('edits').doc(editId).update({
      'views': FieldValue.increment(1),
    });
  }

  Future<void> deleteEdit(EditModel edit) async {
    await _firestore.collection('edits').doc(edit.id).delete();
    try {
      await _storage.refFromURL(edit.videoUrl).delete();
    } catch (_) {}
    try {
      await _storage.refFromURL(edit.thumbnailUrl).delete();
    } catch (_) {}
  }
}