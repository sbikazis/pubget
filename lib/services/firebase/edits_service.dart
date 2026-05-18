import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/edits_model.dart';

class EditsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<EditModel>> getEdits() {
    return _firestore
      .collection('edits')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => EditModel.fromFirestore(doc)).toList());
  }

  Stream<List<EditModel>> getUserEdits(String userId) {
    return _firestore
      .collection('edits')
      .where('uploaderId', isEqualTo: userId)
      .snapshots()
      .map((snap) {
      final list = snap.docs.map((doc) => EditModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<String> uploadVideo(File file, String userId) async {
    final ref = _storage.ref().child('edits/$userId/v_${DateTime.now().millisecondsSinceEpoch}.mp4');
    await ref.putFile(file, SettableMetadata(contentType: 'video/mp4'));
    return await ref.getDownloadURL();
  }

  Future<String> uploadThumbnail(File file, String userId) async {
    final ref = _storage.ref().child('edits/$userId/t_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  Future<String> postEdit(EditModel edit) async {
    final doc = await _firestore.collection('edits').add(edit.toMap());
    return doc.id;
  }

  // ← النسخة النهائية بدون get()
  Future<void> toggleLike(String editId, String userId, bool isCurrentlyLiked) async {
    final ref = _firestore.collection('edits').doc(editId);
    await ref.update({
      'likes': isCurrentlyLiked
         ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> incrementViews(String editId, String userId) async {
    final viewerRef = _firestore.collection('edits').doc(editId).collection('viewers').doc(userId);
    final existing = await viewerRef.get();
    if (existing.exists) return;
    await viewerRef.set({'viewedAt': FieldValue.serverTimestamp()});
    await _firestore.collection('edits').doc(editId).update({'views': FieldValue.increment(1)});
  }

  Future<void> deleteEdit(EditModel edit) async {
    await _firestore.collection('edits').doc(edit.id).delete();
    try { await _storage.refFromURL(edit.videoUrl).delete(); } catch (_) {}
    try { await _storage.refFromURL(edit.thumbnailUrl).delete(); } catch (_) {}
  }
}