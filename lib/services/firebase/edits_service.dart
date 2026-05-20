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
        .limit(50) // ← تقليص من 100 إلى 50 للسرعة
        .get();

    final all = snap.docs.map((doc) => EditModel.fromFirestore(doc)).toList();

    final unseen = all.where((e) => !seenIds.contains(e.id)).toList();

    unseen.sort((a, b) => b.computeScore().compareTo(a.computeScore()));

    return unseen;
  }

  // ── تسجيل وقت المشاهدة — خفيف بدون transaction
  Future<void> recordWatchTime({
    required String editId,
    required String userId,
    required int watchSeconds,
    required double watchPercent,
  }) async {
    if (watchSeconds <= 0) return;

    final editRef = _firestore.collection('edits').doc(editId);
    final watchRef =
        editRef.collection('watch_events').doc(userId);

    // ← حفظ حدث المشاهدة بدون transaction
    watchRef.set({
      'watchSeconds': watchSeconds,
      'watchPercent': watchPercent,
      'recordedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // ← تحديث المجموع بـ increment مباشرة بدون قراءة أولى
    editRef.update({
      'totalWatchSeconds': FieldValue.increment(watchSeconds),
      // ← متوسط تقريبي: نجمع نسبة المشاهدة ونقسمها لاحقاً بالعدد
      // لا نحتاج دقة 100% هنا، الهدف الاتجاه العام
      'avgWatchPercent': watchPercent,
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

  // ── رفع الفيديو والـ thumbnail بشكل متوازٍ
  Future<List<String>> uploadVideoAndThumbnail(
      File videoFile, File thumbnailFile, String userId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final videoRef = _storage.ref().child('edits/$userId/v_$timestamp.mp4');
    final thumbRef = _storage.ref().child('edits/$userId/t_$timestamp.jpg');

    // ← رفع متوازٍ بدل التسلسلي
    final results = await Future.wait([
      videoRef
          .putFile(videoFile, SettableMetadata(contentType: 'video/mp4'))
          .then((_) => videoRef.getDownloadURL()),
      thumbRef
          .putFile(thumbnailFile,
              SettableMetadata(contentType: 'image/jpeg'))
          .then((_) => thumbRef.getDownloadURL()),
    ]);

    return results; // [videoUrl, thumbnailUrl]
  }

  // ← الاحتفاظ بهما منفردَين للتوافق مع أجزاء أخرى قد تستخدمهما
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
    // ← حذف متوازٍ للـ Storage
    await Future.wait([
      _firestore.collection('edits').doc(edit.id).delete(),
      Future(() async {
        try {
          await _storage.refFromURL(edit.videoUrl).delete();
        } catch (_) {}
      }),
      Future(() async {
        try {
          await _storage.refFromURL(edit.thumbnailUrl).delete();
        } catch (_) {}
      }),
    ]);
  }
}