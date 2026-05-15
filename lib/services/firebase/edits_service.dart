import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pubget/models/edits_model.dart';

class EditsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── جلب الفيديوهات
  Stream<List<EditModel>> getEdits() {
    return _firestore
        .collection('edits')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(EditModel.fromFirestore).toList());
  }

  // ── رفع فيديو
  Future<String> uploadVideo(File file, String userId) async {
    final ref = _storage
        .ref()
        .child('edits/videos/$userId/${DateTime.now().millisecondsSinceEpoch}.mp4');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  // ── رفع thumbnail
  Future<String> uploadThumbnail(File file, String userId) async {
    final ref = _storage
        .ref()
        .child('edits/thumbnails/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  // ── نشر الإيديت
  Future<void> postEdit(EditModel edit) async {
    await _firestore.collection('edits').add(edit.toMap());
  }

  // ── لايك / إلغاء لايك
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

  // ── زيادة المشاهدات
  Future<void> incrementViews(String editId) async {
    await _firestore.collection('edits').doc(editId).update({
      'views': FieldValue.increment(1),
    });
  }
}