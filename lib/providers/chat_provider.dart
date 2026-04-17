import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // مضاف لدعم Timestamp
import 'package:rxdart/rxdart.dart';

import '../models/message_model.dart';
import '../models/member_model.dart';
import '../models/group_model.dart'; // مضاف لدعم التعامل مع المجموعات

import '../services/firebase/firestore_service.dart';
import '../services/firebase/storage_service.dart';

import '../core/constants/firestore_paths.dart';

class ChatProvider extends ChangeNotifier {
  final FirestoreService _firestore;
  final StorageService _storage;

  ChatProvider({
    required FirestoreService firestoreService,
    required StorageService storageService,
  }) : _firestore = firestoreService,
        _storage = storageService;

  // =========================================================
  // ✅ التعديل الجديد: تحديث وقت القراءة (تصفير العداد)
  // =========================================================
 
  Future<void> updateLastRead({
    required String groupId,
    required String userId,
  }) async {
    final path = FirestorePaths.groupMembers(groupId);
   
    await _firestore.updateDocument(
      path: path,
      docId: userId,
      data: {
        'lastReadAt': FieldValue.serverTimestamp(), // استخدام توقيت السيرفر للدقة
      },
    );
  }

  // =========================================================
  // ✅ التعديل المطلوب: توحيد المقارنة باستخدام Timestamp لضمان الدقة
  // =========================================================

  Stream<int> streamUnreadCount({
    required String groupId,
    required dynamic lastReadAt, // تم تغيير النوع ليكون مرناً (DateTime أو Timestamp)
  }) {
    final path = FirestorePaths.groupMessages(groupId);
   
    // ✅ تحويل القيمة القادمة إلى Timestamp أياً كان نوعها لضمان التوافق مع Firestore
    Timestamp compareTimestamp;
    
    if (lastReadAt is Timestamp) {
      compareTimestamp = lastReadAt;
    } else if (lastReadAt is DateTime) {
      compareTimestamp = Timestamp.fromDate(lastReadAt);
    } else {
      // إذا كانت القيمة null أو غير معروفة، نستخدم تاريخ قديم جداً
      compareTimestamp = Timestamp.fromDate(DateTime(2000));
    }

    final query = _firestore.buildQuery(
      path: path,
      conditions: [
        QueryCondition(
          field: 'createdAt',
          isGreaterThan: compareTimestamp, // المقارنة الآن بين Timestamp و Timestamp
        ),
      ],
    );

    return _firestore.streamCollection(path: path, query: query).map((snap) => snap.size);
  }

  // =========================================================
  // ✅ التعديل الجوهري الجديد: مراقب إجمالي للمجموعات (للشريط السفلي)
  // =========================================================

  Stream<int> streamTotalGroupsUnreadCount({
    required String userId,
    required List<GroupModel> groups,
  }) {
    if (groups.isEmpty) return Stream.value(0);

    // نقوم بإنشاء قائمة من الـ Streams، كل Stream يراقب عداد مجموعة واحدة
    final streams = groups.map((group) {
      return _firestore
          .streamDocument(
            path: FirestorePaths.groupMembers(group.id),
            docId: userId,
          )
          .asyncExpand((memberDoc) {
        if (!memberDoc.exists) return Stream.value(0);
        final lastReadAt = memberDoc.data()?['lastReadAt'];
        return streamUnreadCount(groupId: group.id, lastReadAt: lastReadAt);
      });
    }).toList();

    // ندمج جميع الـ Streams ونجمع نتائجها
    return Rx.combineLatestList(streams).map((counts) {
      return counts.fold<int>(0, (sum, count) => sum + count);
    });
  }
  // ملاحظة: إذا كنت لا تستخدم RxDart، سأقوم بتبديل المنطق في ملف الواجهة لجمع الـ Streams يدوياً.

  // =========================================================
  // STREAM MESSAGES (REALTIME)
  // =========================================================

  Stream<List<MessageModel>> streamMessages({
    required String groupId,
  }) {
    final path = FirestorePaths.groupMessages(groupId);

    // ✅ ضمان الترتيب التصاعدي (القديم فوق والجديد تحت) بشكل مستقر
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
  // SEND TEXT MESSAGE (UPDATED WITH REPLY)
  // =========================================================

  Future<void> sendTextMessage({
    required String groupId,
    required String messageId,
    required MemberModel sender,
    required String text,
    String? userAvatar,
    String? replyToId, // ✅ إضافة بارامتر الرد
    String? replyText, // ✅ إضافة نص الرد
  }) async {
    if (text.trim().isEmpty) return;

    final message = MessageModel(
      id: messageId,
      senderId: sender.userId,
      senderName: sender.displayName ?? '',
      senderAvatar: (sender.characterImageUrl != null && sender.characterImageUrl!.isNotEmpty)
          ? sender.characterImageUrl!
          : (userAvatar ?? ''),
      senderRole: sender.role,
      text: text.trim(),
      replyToId: replyToId, // ✅ إسناد الرد
      replyText: replyText, // ✅ إسناد نص الرد
      createdAt: DateTime.now(),
    );

    await _firestore.createDocument(
      path: FirestorePaths.groupMessages(groupId),
      docId: messageId,
      data: message.toMap(),
    );
  }

  // =========================================================
  // SEND MEDIA MESSAGE (UPDATED WITH REPLY)
  // =========================================================

  Future<void> sendMediaMessage({
    required String groupId,
    required String messageId,
    required MemberModel sender,
    required File file,
    required String mediaType,
    String? userAvatar,
    String? replyToId, // ✅ إضافة بارامتر الرد للميديا
    String? replyText, // ✅ إضافة نص الرد للميديا
  }) async {
    // 1. رفع الملف إلى Storage
    final mediaUrl = await _storage.uploadGroupChatMedia(
      groupId: groupId,
      messageId: messageId,
      file: file,
    );

    // 2. إنشاء كائن الرسالة
    final message = MessageModel(
      id: messageId,
      senderId: sender.userId,
      senderName: sender.displayName ?? '',
      senderAvatar: (sender.characterImageUrl != null && sender.characterImageUrl!.isNotEmpty)
          ? sender.characterImageUrl!
          : (userAvatar ?? ''),
      senderRole: sender.role,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      replyToId: replyToId, // ✅ إسناد الرد
      replyText: replyText, // ✅ إسناد نص الرد
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
  // TOGGLE REACTION (NEW)
  // =========================================================

  Future<void> toggleReaction({
    required String groupId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final path = FirestorePaths.groupMessages(groupId);
   
    // الحصول على بيانات الرسالة الحالية
    final doc = await _firestore.getDocument(path: path, docId: messageId);
    if (doc == null) return;

    final message = MessageModel.fromMap(messageId, doc);
    Map<String, String> updatedReactions = Map.from(message.reactions ?? {});

    // إذا كان المستخدم قد وضع نفس الإيموجي سابقاً، نقوم بإزالته (Toggle)
    if (updatedReactions[userId] == emoji) {
      updatedReactions.remove(userId);
    } else {
      updatedReactions[userId] = emoji;
    }

    await _firestore.updateDocument(
      path: path,
      docId: messageId,
      data: {'reactions': updatedReactions},
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