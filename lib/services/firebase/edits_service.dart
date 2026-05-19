import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/edits_model.dart';

class EditsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── Stream للتحديثات الصغيرة فقط (لايك، كومنت)
  Stream<List<EditModel>> getEdits() {
    return _firestore
        .collection('edits')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => EditModel.fromFirestore(doc)).toList());
  }

  // ── جلب الـ Feed الذكي مرة واحدة عند بدء الجلسة
  Future<List<EditModel>> fetchSmartFeed({
    required String userId,
    required List<String> seenIds,
  }) async {
    final snap = await _firestore
        .collection('edits')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    final all = snap.docs.map((doc) => EditModel.fromFirestore(doc)).toList();

    // ── فصل المشاهَدة وغير المشاهَدة
    final unseen = all.where((e) => !seenIds.contains(e.id)).toList();
    final seen = all.where((e) => seenIds.contains(e.id)).toList();

    // ── ترتيب بالنقاط
    unseen.sort((a, b) => b.computeScore().compareTo(a.computeScore()));
    seen.sort((a, b) => b.computeScore().compareTo(a.computeScore()));

    // ── غير المشاهَدة أولاً — المشاهَدة لا تُعرض أبداً
    return unseen;
  }

  // ── تسجيل وقت المشاهدة وتحديث الإحصائيات
  Future<void> recordWatchTime({
    required String editId,
    required String userId,
    required int watchSeconds,
    required double watchPercent,
  }) async {
    if (watchSeconds <= 0) return;

    final editRef = _firestore.collection('edits').doc(editId);
    final watchRef = editRef.collection('watch_events').doc(userId);

    await _firestore.runTransaction((tx) async {
      final editSnap = await tx.get(editRef);
      if (!editSnap.exists) return;

      final currentTotal =
          (editSnap.data()?['totalWatchSeconds'] ?? 0) as int;
      final currentAvg =
          (editSnap.data()?['avgWatchPercent'] ?? 0.0).toDouble();
      final currentViews = (editSnap.data()?['views'] ?? 0) as int;

      final newTotal = currentTotal + watchSeconds;
      final newAvg = currentViews > 0
          ? ((currentAvg * currentViews) + watchPercent) /
              (currentViews + 1)
          : watchPercent;

      tx.set(watchRef, {
        'watchSeconds': watchSeconds,
        'watchPercent': watchPercent,
        'recordedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.update(editRef, {
        'totalWatchSeconds': newTotal,
        'avgWatchPercent': newAvg,
      });
    });
  }

  Stream<List<EditModel>> getUserEdits(String userId) {
    return _firestore
        .collection('edits')
        .where('uploaderId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((doc) => EditModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<String> uploadVideo(File file, String userId) async {
    final ref = _storage.ref().child(
        'edits/$userId/v_${DateTime.now().millisecondsSinceEpoch}.mp4');
    await ref.putFile(file, SettableMetadata(contentType: 'video/mp4'));
    return await ref.getDownloadURL();
  }

  Future<String> uploadThumbnail(File file, String userId) async {
    final ref = _storage.ref().child(
        'edits/$userId/t_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  Future<String> postEdit(EditModel edit) async {
    final doc = await _firestore.collection('edits').add(edit.toMap());
    return doc.id;
  }

  Future<void> toggleLike(
      String editId, String userId, bool isCurrentlyLiked) async {
    final ref = _firestore.collection('edits').doc(editId);
    await ref.update({
      'likes': isCurrentlyLiked
          ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> incrementViews(String editId, String userId) async {
    final viewerRef = _firestore
        .collection('edits')
        .doc(editId)
        .collection('viewers')
        .doc(userId);
    final existing = await viewerRef.get();
    if (existing.exists) return;
    await viewerRef.set({'viewedAt': FieldValue.serverTimestamp()});
    await _firestore
        .collection('edits')
        .doc(editId)
        .update({'views': FieldValue.increment(1)});
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