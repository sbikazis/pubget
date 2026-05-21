// lib/services/firebase/chat_background_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/constants/storage_paths.dart';

class ChatBackgroundService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ══════════════════════════════════════════════
  // ── رفع خلفية دردشة المجموعة
  // ══════════════════════════════════════════════

  /// يرفع صورة الخلفية إلى Firebase Storage
  /// ويحفظ الـ URL في Firestore على وثيقة المجموعة
  /// يعود بالـ URL النهائي
  Future<String> uploadGroupChatBackground({
    required String groupId,
    required File file,
  }) async {
    try {
      // 1. رفع الصورة إلى Storage
      final path = StoragePaths.groupChatBackground(groupId);
      final ref = _storage.ref().child(path);

      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final url = await uploadTask.ref.getDownloadURL();

      // 2. حفظ الـ URL في Firestore
      await _firestore
          .collection('groups')
          .doc(groupId)
          .update({'chatBackgroundUrl': url});

      return url;
    } on FirebaseException catch (e) {
      throw Exception('فشل رفع خلفية المجموعة: ${e.message}');
    }
  }

  // ══════════════════════════════════════════════
  // ── حذف خلفية دردشة المجموعة
  // ══════════════════════════════════════════════

  /// يحذف صورة الخلفية من Storage
  /// ويزيل الـ URL من Firestore
  Future<void> deleteGroupChatBackground({
    required String groupId,
  }) async {
    try {
      // 1. حذف الصورة من Storage
      final path = StoragePaths.groupChatBackground(groupId);
      final ref = _storage.ref().child(path);

      await ref.delete();
    } on FirebaseException catch (e) {
      // إذا الملف مش موجود أصلاً → تجاهل الخطأ
      if (e.code != 'object-not-found') {
        throw Exception('فشل حذف صورة الخلفية من Storage: ${e.message}');
      }
    }

    try {
      // 2. مسح الـ URL من Firestore
      await _firestore
          .collection('groups')
          .doc(groupId)
          .update({'chatBackgroundUrl': FieldValue.delete()});
    } on FirebaseException catch (e) {
      throw Exception('فشل مسح رابط الخلفية من Firestore: ${e.message}');
    }
  }

  // ══════════════════════════════════════════════
  // ── جلب الـ URL الحالي للخلفية
  // ══════════════════════════════════════════════

  /// يجلب رابط الخلفية الحالي للمجموعة من Firestore
  Future<String?> getGroupChatBackgroundUrl({
    required String groupId,
  }) async {
    try {
      final doc =
          await _firestore.collection('groups').doc(groupId).get();

      if (!doc.exists) return null;

      return doc.data()?['chatBackgroundUrl'] as String?;
    } on FirebaseException catch (e) {
      throw Exception('فشل جلب رابط الخلفية: ${e.message}');
    }
  }
}