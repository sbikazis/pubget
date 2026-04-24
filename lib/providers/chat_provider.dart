// lib/providers/chat_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:rxdart/rxdart.dart';

import '../models/message_model.dart';
import '../models/member_model.dart';
import '../models/group_model.dart'; 

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
  // ✅ تحديث وقت القراءة (تصفير العداد)
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
        'lastReadAt': FieldValue.serverTimestamp(),
      },
    );
  }

  // =========================================================
  // ✅ استبعاد رسائل المستخدم الحالي من العداد
  // =========================================================

  Stream<int> streamUnreadCount({
    required String groupId,
    required String userId, 
    required dynamic lastReadAt, 
  }) {
    final path = FirestorePaths.groupMessages(groupId);
   
    Timestamp compareTimestamp;
    
    if (lastReadAt is Timestamp) {
      compareTimestamp = lastReadAt;
    } else if (lastReadAt is DateTime) {
      compareTimestamp = Timestamp.fromDate(lastReadAt);
    } else {
      compareTimestamp = Timestamp.fromDate(DateTime(2000));
    }

    final query = _firestore.buildQuery(
      path: path,
      conditions: [
        QueryCondition(
          field: 'createdAt',
          isGreaterThan: compareTimestamp,
        ),
      ],
    );

    return _firestore.streamCollection(path: path, query: query).map((snap) {
      return snap.docs.where((doc) => doc.data()['senderId'] != userId).length;
    });
  }

  // =========================================================
  // ✅ تمرير userId لضمان دقة مراقب المجموعات
  // =========================================================

  Stream<int> streamTotalGroupsUnreadCount({
    required String userId,
    required List<GroupModel> groups,
  }) {
    if (groups.isEmpty) return Stream.value(0);

    final streams = groups.map((group) {
      return _firestore
          .streamDocument(
            path: FirestorePaths.groupMembers(group.id),
            docId: userId,
          )
          .asyncExpand((memberDoc) {
        if (!memberDoc.exists) return Stream.value(0);
        final lastReadAt = memberDoc.data()?['lastReadAt'];
        
        return streamUnreadCount(
          groupId: group.id, 
          userId: userId, 
          lastReadAt: lastReadAt,
        );
      });
    }).toList();

    return Rx.combineLatestList(streams).map((counts) {
      return counts.fold<int>(0, (sum, count) => sum + count);
    });
  }

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
  // SEND TEXT MESSAGE (FIXED: PHOTO LOGIC BY DISPLAY_IMAGE_URL)
  // =========================================================

  Future<void> sendTextMessage({
    required String groupId,
    required String messageId,
    required MemberModel sender,
    required String text,
    String? userAvatar,
    String? replyToId, 
    String? replyText, 
  }) async {
    if (text.trim().isEmpty) return;

    bool freshPremiumStatus = sender.isPremium;
    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection(FirestorePaths.groupMembers(groupId))
          .doc(sender.userId)
          .get();
      if (memberDoc.exists) {
        freshPremiumStatus = memberDoc.data()?['isPremium'] ?? sender.isPremium;
      }
    } catch (e) {
      debugPrint("⚠️ Warning: Could not fetch fresh premium status, using local: $e");
    }

    // ✅ التعديل المطلوب: استخدام الـ Getter الذكي لضمان جلب صورة التقمص أو الحقيقية
    final finalAvatar = sender.displayImageUrl ?? userAvatar ?? '';

    final message = MessageModel(
      id: messageId,
      senderId: sender.userId,
      senderName: sender.effectiveName, // استخدام الاسم الفعال (تقمص أو حقيقي)
      senderAvatar: finalAvatar,
      senderRole: sender.role,
      senderIsPremium: freshPremiumStatus,
      text: text.trim(),
      replyToId: replyToId, 
      replyText: replyText, 
      createdAt: DateTime.now(),
    );

    await _firestore.createDocument(
      path: FirestorePaths.groupMessages(groupId),
      docId: messageId,
      data: message.toMap(),
    );
  }

  // =========================================================
  // SEND MEDIA MESSAGE (FIXED: PHOTO LOGIC BY DISPLAY_IMAGE_URL)
  // =========================================================

  Future<void> sendMediaMessage({
    required String groupId,
    required String messageId,
    required MemberModel sender,
    required File file,
    required String mediaType,
    String? userAvatar,
    String? replyToId, 
    String? replyText, 
  }) async {
    final mediaUrl = await _storage.uploadGroupChatMedia(
      groupId: groupId,
      messageId: messageId,
      file: file,
    );

    bool freshPremiumStatus = sender.isPremium;
    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection(FirestorePaths.groupMembers(groupId))
          .doc(sender.userId)
          .get();
      if (memberDoc.exists) {
        freshPremiumStatus = memberDoc.data()?['isPremium'] ?? sender.isPremium;
      }
    } catch (e) {
      debugPrint("⚠️ Error fetching premium status for media: $e");
    }

    // ✅ التعديل المطلوب: استخدام الـ Getter الذكي لضمان جلب الصورة الصحيحة في الميديا
    final finalAvatar = sender.displayImageUrl ?? userAvatar ?? '';

    final message = MessageModel(
      id: messageId,
      senderId: sender.userId,
      senderName: sender.effectiveName, 
      senderAvatar: finalAvatar,
      senderRole: sender.role,
      senderIsPremium: freshPremiumStatus,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      replyToId: replyToId, 
      replyText: replyText, 
      createdAt: DateTime.now(),
    );

    await _firestore.createDocument(
      path: FirestorePaths.groupMessages(groupId),
      docId: messageId,
      data: message.toMap(),
    );
  }

  // =========================================================
  // TOGGLE REACTION
  // =========================================================

  Future<void> toggleReaction({
    required String groupId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final path = FirestorePaths.groupMessages(groupId);
   
    final doc = await _firestore.getDocument(path: path, docId: messageId);
    if (doc == null) return;

    final message = MessageModel.fromMap(messageId, doc);
    Map<String, String> updatedReactions = Map.from(message.reactions ?? {});

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
  // SEND GAME MESSAGE (FIXED: PHOTO LOGIC BY DISPLAY_IMAGE_URL)
  // =========================================================

  Future<void> sendGameMessage({
    required String groupId,
    required String messageId,
    required MemberModel sender,
    required String gameId,
  }) async {
    bool freshPremiumStatus = sender.isPremium;
    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection(FirestorePaths.groupMembers(groupId))
          .doc(sender.userId)
          .get();
      if (memberDoc.exists) {
        freshPremiumStatus = memberDoc.data()?['isPremium'] ?? sender.isPremium;
      }
    } catch (e) {
      debugPrint("⚠️ Error fetching premium status for game: $e");
    }

    // ✅ التعديل المطلوب: ضمان جلب الصورة في رسائل الألعاب أيضاً
    final finalAvatar = sender.displayImageUrl ?? '';

    final message = MessageModel(
      id: messageId,
      senderId: sender.userId,
      senderName: sender.effectiveName,
      senderAvatar: finalAvatar,
      senderRole: sender.role,
      senderIsPremium: freshPremiumStatus,
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
  // GET MEMBER
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