// lib/services/firebase/sticker_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/sticker_model.dart';

class StickerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // ─── Firestore paths ───────────────────────────────────────
  CollectionReference _userStickers(String userId) =>
      _firestore.collection('users').doc(userId).collection('stickers');

  // ─── Storage path ──────────────────────────────────────────
  // users/{userId}/stickers/{stickerId}.png
  Reference _stickerRef(String userId, String stickerId) =>
      _storage.ref('users/$userId/stickers/$stickerId.png');

  // ─── رفع ملصق جديد ─────────────────────────────────────────
  Future<StickerModel?> uploadSticker({
    required String userId,
    required File imageFile,
  }) async {
    try {
      final stickerId = _uuid.v4();

      // رفع الصورة لـ Storage
      final ref = _stickerRef(userId, stickerId);
      await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/png'),
      );
      final imageUrl = await ref.getDownloadURL();

      // حفظ في Firestore
      final sticker = StickerModel(
        id: stickerId,
        creatorId: userId,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
      );

      await _userStickers(userId).doc(stickerId).set(sticker.toMap());

      debugPrint('✅ Sticker uploaded: $stickerId');
      return sticker;
    } catch (e) {
      debugPrint('❌ StickerService.uploadSticker: $e');
      return null;
    }
  }

  // ─── جلب ملصقات المستخدم ────────────────────────────────────
  Future<List<StickerModel>> getUserStickers(String userId) async {
    try {
      final snapshot = await _userStickers(userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => StickerModel.fromMap(
                doc.id,
                doc.data() as Map<String, dynamic>,
              ))
          .toList();
    } catch (e) {
      debugPrint('❌ StickerService.getUserStickers: $e');
      return [];
    }
  }

  // ─── حفظ ملصق شخص آخر عند المستخدم الحالي ──────────────────
  Future<void> saveReceivedSticker({
    required String userId,
    required StickerModel sticker,
  }) async {
    try {
      // نحفظه بنفس الـ ID حتى لا يتكرر
      final existing =
          await _userStickers(userId).doc(sticker.id).get();
      if (existing.exists) {
        debugPrint('ℹ️ Sticker already saved: ${sticker.id}');
        return;
      }

      await _userStickers(userId).doc(sticker.id).set(sticker.toMap());
      debugPrint('✅ Sticker saved from other user: ${sticker.id}');
    } catch (e) {
      debugPrint('❌ StickerService.saveReceivedSticker: $e');
    }
  }

  // ─── حذف ملصق ───────────────────────────────────────────────
  Future<void> deleteSticker({
    required String userId,
    required String stickerId,
  }) async {
    try {
      await _userStickers(userId).doc(stickerId).delete();
      await _stickerRef(userId, stickerId).delete();
      debugPrint('🗑️ Sticker deleted: $stickerId');
    } catch (e) {
      debugPrint('❌ StickerService.deleteSticker: $e');
    }
  }
}