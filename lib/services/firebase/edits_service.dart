import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pubget/models/edits_model.dart';

class EditsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ══════════════════════════════════════════════
  // ── الخوارزمية الذكية لحساب نقاط الإيديت
  // ══════════════════════════════════════════════
  double _score(EditModel e) {
    final ageHours =
        DateTime.now().difference(e.createdAt).inHours.toDouble();

    // نقاط التفاعل
    final interactionScore =
        (e.likes.length * 3.0) + (e.views * 0.5) + (e.commentsCount * 2.0);

    // عامل الحداثة: كلما قدم الإيديت قلت نقاطه تدريجياً
    final decayFactor = 1.0 / (1.0 + (ageHours / 24.0));

    return interactionScore * decayFactor + (1.0 / (1.0 + ageHours * 0.01));
  }

  // ══════════════════════════════════════════════
  // ── جلب الفيديوهات مع الخوارزمية + تجنب المشاهدة
  // ══════════════════════════════════════════════
  Stream<List<EditModel>> getEdits({List<String> seenIds = const []}) {
    return _firestore.collection('edits').snapshots().map((snap) {
      final list = snap.docs.map(EditModel.fromFirestore).toList();

      // ── فصل المشاهدة وغير المشاهدة
      final unseen = list.where((e) => !seenIds.contains(e.id)).toList();
      final seen = list.where((e) => seenIds.contains(e.id)).toList();

      // ── ترتيب كل مجموعة بالخوارزمية
      unseen.sort((a, b) => _score(b).compareTo(_score(a)));
      seen.sort((a, b) => _score(b).compareTo(_score(a)));

      // ── غير المشاهدة أولاً ثم المشاهدة
      return [...unseen, ...seen];
    });
  }

  // ── جلب إيديتات مستخدم معين
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

  Future<void> postEdit(EditModel edit) async {
    await _firestore.collection('edits').add(edit.toMap());
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

  Future<void> incrementViews(String editId) async {
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