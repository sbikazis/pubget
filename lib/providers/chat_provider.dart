import 'dart:io';
import 'package:flutter/material.dart';

import '../models/message_model.dart';
import '../models/member_model.dart';

import '../services/firebase/firestore_service.dart';
import '../services/firebase/storage_service.dart';

import '../core/constants/firestore_paths.dart';


class ChatProvider extends ChangeNotifier {
  final FirestoreService _firestore;
  final StorageService _storage;

  ChatProvider({
    required FirestoreService firestoreService,
    required StorageService storageService,
  })  : _firestore = firestoreService,
        _storage = storageService;

  // =========================================================
  // STREAM MESSAGES (REALTIME)
  // =========================================================

  Stream<List<MessageModel>> streamMessages({
    required String groupId,
  }) {
    final path = FirestorePaths.groupMessages(groupId);

    final query = _firestore.buildQuery(
      path: path,
      orderBy: 'createdAt',
      descending: false,
    );

    return _firestore
        .streamCollection(
          path: path,
          query: query,
        )
        .map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => MessageModel.fromMap(
              doc.id,
              doc.data(),
            ),
          )
          .toList();
    });
  }

  // =========================================================
  // SEND TEXT MESSAGE
  // =========================================================

  Future<void> sendTextMessage({
    required String groupId,
    required String messageId,
    required MemberModel sender,
    required String text,
    String? userAvatar, // ✅ أضفنا هذا ليكون احتياطياً
  }) async {
    if (text.trim().isEmpty) return;

    final message = MessageModel(
      id: messageId,
      senderId: sender.userId,
      senderName: sender.displayName ?? '',
      // ✅ المنطق الجديد: إذا كانت صورة التقمص فارغة، استخدم صورة المستخدم الأساسية
      senderAvatar: (sender.characterImageUrl != null && sender.characterImageUrl!.isNotEmpty)
          ? sender.characterImageUrl!
          : (userAvatar ?? ''), 
      senderRole: sender.role,
      text: text.trim(),
      createdAt: DateTime.now(),
    );

    await _firestore.createDocument(
      path: FirestorePaths.groupMessages(groupId),
      docId: messageId,
      data: message.toMap(),
    );
  }

  // =========================================================
  // SEND MEDIA MESSAGE
  // =========================================================

  // =========================================================
  // SEND MEDIA MESSAGE (UPDATED)
  // =========================================================

  Future<void> sendMediaMessage({
    required String groupId,
    required String messageId,
    required MemberModel sender,
    required File file,
    required String mediaType, // image | video | audio
    String? userAvatar, // ✅ إضافة هذا البارامتر لحل المشكلة
  }) async {
    // 1. رفع الملف إلى Storage
    final mediaUrl = await _storage.uploadGroupChatMedia(
      groupId: groupId,
      messageId: messageId,
      file: file,
    );

    // 2. إنشاء كائن الرسالة مع معالجة الصورة الشخصية
    final message = MessageModel(
      id: messageId,
      senderId: sender.userId,
      senderName: sender.displayName ?? '',
      // ✅ إذا لم تكن هناك صورة تقمص، استخدم صورة المستخدم الأساسية
      senderAvatar: (sender.characterImageUrl != null && sender.characterImageUrl!.isNotEmpty)
          ? sender.characterImageUrl!
          : (userAvatar ?? ''),
      senderRole: sender.role,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      createdAt: DateTime.now(),
    );

    // 3. حفظ الرسالة في Firestore
    await _firestore.createDocument(
      path: FirestorePaths.groupMessages(groupId),
      docId: messageId,
      data: message.toMap(),
    );
  }

  // =========================================================
  // SEND GAME MESSAGE
  // =========================================================

  Future<void> sendGameMessage({
    required String groupId,
    required String messageId,
    required MemberModel sender,
    required String gameId,
  }) async {
    final message = MessageModel(
      id: messageId,
      senderId: sender.userId,
      senderName: sender.displayName ?? '',
      senderAvatar: sender.characterImageUrl ?? '',
      senderRole: sender.role,
      gameId: gameId,
      createdAt: DateTime.now(),
    );

    await _firestore.createDocument(
      path: FirestorePaths.groupMessages(groupId),
      docId: messageId,
      data: message.toMap(),
    );
  }

  // =========================================================
  // DELETE MESSAGE
  // =========================================================

  Future<void> deleteMessage({
    required String groupId,
    required String messageId,
  }) async {
    await _firestore.deleteDocument(
      path: FirestorePaths.groupMessages(groupId),
      docId: messageId,
    );
  }

  // =========================================================
  // GET MEMBER ROLE
  // =========================================================

  Future<MemberModel?> getMember({
    required String groupId,
    required String userId,
  }) async {
    final data = await _firestore.getDocument(
      path: FirestorePaths.groupMembers(groupId),
      docId: userId,
    );

    if (data == null) return null;

    return MemberModel.fromMap(data);
  }

  // =========================================================
  // LOAD RECENT MESSAGES (ONCE)
  // =========================================================

  Future<List<MessageModel>> getRecentMessages({
    required String groupId,
    int limit = 50,
  }) async {
    final path = FirestorePaths.groupMessages(groupId);

    final query = _firestore.buildQuery(
      path: path,
      orderBy: 'createdAt',
      descending: true,
      limit: limit,
    );

    final snapshot = await _firestore.getCollection(
      path: path,
      query: query,
    );

    return snapshot.docs
        .map(
          (doc) => MessageModel.fromMap(
            doc.id,
            doc.data(),
          ),
        )
        .toList();
  }
}