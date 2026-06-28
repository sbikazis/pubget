import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

import '../models/message_model.dart';
import '../models/member_model.dart';
import '../models/group_model.dart';

import '../services/firebase/firestore_service.dart';
import '../services/firebase/storage_service.dart';

import '../core/constants/firestore_paths.dart';
import '../core/logic/game_logic_validator.dart';

class ChatProvider extends ChangeNotifier {
  final FirestoreService _firestore;
  final StorageService _storage;

  ChatProvider({
    required FirestoreService firestoreService,
    required StorageService storageService,
  }) : _firestore = firestoreService,
        _storage = storageService;

  // ✅✅✅ تعديل جوهري: حذفنا تماماً إمكانية تمرير readUpTo محلي (DateTime)
  // السبب: أي DateTime قادم من جهاز المستخدم يحمل نفس مشكلة Clock Skew
  // التي تسببت بمشكلة "الرسائل تبقى غير مقروءة حتى يحين توقيتها".
  // الآن updateLastRead يستخدم دائماً وبدون أي استثناء FieldValue.serverTimestamp()،
  // بحيث "وقت القراءة" يُكتب أيضاً بساعة سيرفر فايرستور الموحّدة لكل المستخدمين.
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
        QueryCondition(field: 'createdAt', isGreaterThan: compareTimestamp),
      ],
    );
    return _firestore.streamCollection(path: path, query: query).map((snap) {
      // ✅ رسائل النظام لا تُحتسب في العداد
      return snap.docs.where((doc) {
        final data = doc.data();
        return data['senderId'] != userId && data['type'] != 'systemEvent';
      }).length;
    });
  }

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

  Stream<List<MessageModel>> streamMessages({required String groupId}) {
    final path = FirestorePaths.groupMessages(groupId);
    final query = _firestore.buildQuery(
      path: path,
      orderBy: 'createdAt',
      descending: false,
    );
    return _firestore.streamCollection(path: path, query: query).map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  // =========================================================
  // ✅ SEND SYSTEM MESSAGE — رسالة النظام التلقائية
  // =========================================================
  Future<void> sendSystemMessage({
    required String groupId,
    required String systemEventType, // join / leave / kick / roleAssign
    required String text,
  }) async {
    try {
      final messageId = const Uuid().v4();

      // ✅✅✅ تعديل جوهري: createdAt لم يُمرَّر هنا إطلاقاً (يبقى null محلياً).
      // toMap() الافتراضي (useServerTimestamp: true) سيكتب FieldValue.serverTimestamp()
      // تلقائياً، فلا حاجة لأي DateTime.now() من جهاز العميل بعد الآن.
      final message = MessageModel(
        id: messageId,
        senderId: 'system',
        senderName: 'النظام',
        senderAvatar: '',
        senderIsPremium: false,
        senderRole: null,
        text: text,
        type: MessageType.systemEvent,
        systemEventType: systemEventType,
        isDelivered: true,
        isRead: true, // رسائل النظام تُعتبر مقروءة دائماً
      );

      await _firestore.createDocument(
        path: FirestorePaths.groupMessages(groupId),
        docId: messageId,
        data: message.toMap(),
      );

      // ✅ لا تُحدِّث lastMessageText بنص النظام لتجنب إزعاج المستخدم
      await _firestore.updateDocument(
        path: FirestorePaths.groups,
        docId: groupId,
        data: {
          'lastMessageAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      debugPrint('⚠️ sendSystemMessage failed: $e');
    }
  }

  // =========================================================
  // ✅ SEND TEXT
  // =========================================================
  Future<void> sendTextMessage({
    required String groupId,
    required String messageId,
    required MemberModel sender,
    required String text,
    String? userAvatar,
    String? replyToId,
    String? replyText,
    String? replyToSenderName,
    String? replyToMediaUrl,
    String? gameId,
    String? gameSlot,
  }) async {
    if (text.trim().isEmpty) return;
    final finalAvatar = sender.displayImageUrl ?? userAvatar ?? '';
    // ✅✅✅ تعديل جوهري: لا يوجد createdAt: DateTime.now() بعد الآن.
    // toMap() سيكتب وقت السيرفر الحقيقي تلقائياً عبر FieldValue.serverTimestamp().
    final message = MessageModel(
      id: messageId,
      senderId: sender.userId,
      senderName: sender.effectiveName,
      senderAvatar: finalAvatar,
      senderRole: sender.role,
      senderIsPremium: sender.isPremium,
      text: text.trim(),
      replyToId: replyToId,
      replyText: replyText,
      replyToSenderName: replyToSenderName,
      replyToMediaUrl: replyToMediaUrl,
      gameId: gameId,
      gameSlot: gameSlot,
      isDelivered: true,
    );
    await _firestore.createDocument(
      path: FirestorePaths.groupMessages(groupId),
      docId: messageId,
      data: message.toMap(),
    );
    final preview = text.trim().length > 80
        ? text.trim().substring(0, 80)
        : text.trim();
    await _firestore.updateDocument(
      path: FirestorePaths.groups,
      docId: groupId,
      data: {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': preview,
      },
    );
  }

  // =========================================================
  // ✅ EDIT TEXT MESSAGE
  // =========================================================
  Future<void> editMessage({
    required String groupId,
    required String messageId,
    required String newText,
  }) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;
    await _firestore.updateDocument(
      path: FirestorePaths.groupMessages(groupId),
      docId: messageId,
      data: {
        'text': trimmed,
        'isEdited': true,
      },
    );
  }

  // =========================================================
  // ✅ SEND MEDIA
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
    String? replyToSenderName,
    String? replyToMediaUrl,
  }) async {
    final mediaUrl = await _storage.uploadGroupChatMedia(
      groupId: groupId,
      messageId: messageId,
      file: file,
    );
    String? freshRealAvatar = sender.realUserImageUrl;
    String freshRealName = sender.realUserName ?? '';
    bool freshPremiumStatus = sender.isPremium;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sender.userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        freshRealAvatar = userData?['avatarUrl'];
        freshRealName = userData?['username'] ?? freshRealName;
        freshPremiumStatus = userData?['subscriptionType'] == 'premium';
      }
    } catch (e) {
      debugPrint("⚠️ Error fetching live user data for media: $e");
    }
    final updatedSender = sender.copyWith(
      realUserImageUrl: freshRealAvatar,
      realUserName: freshRealName,
      isPremium: freshPremiumStatus,
    );
    final finalAvatar = updatedSender.displayImageUrl ?? userAvatar ?? '';
    // ✅ تعديل جوهري: حذف createdAt: DateTime.now()
    final message = MessageModel(
      id: messageId,
      senderId: updatedSender.userId,
      senderName: updatedSender.effectiveName,
      senderAvatar: finalAvatar,
      senderRole: updatedSender.role,
      senderIsPremium: updatedSender.isPremium,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      replyToId: replyToId,
      replyText: replyText,
      replyToSenderName: replyToSenderName,
      replyToMediaUrl: replyToMediaUrl,
      isDelivered: true,
    );
    await _firestore.createDocument(
      path: FirestorePaths.groupMessages(groupId),
      docId: messageId,
      data: message.toMap(),
    );
    final preview = mediaType == 'image'
        ? '📷 صورة'
        : mediaType == 'video'
            ? '🎥 فيديو'
            : '📎 ملف';
    await _firestore.updateDocument(
      path: FirestorePaths.groups,
      docId: groupId,
      data: {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': preview,
      },
    );
  }

  // =========================================================
  // ✅ SEND GIF
  // =========================================================
  Future<void> sendGifMessage({
    required String groupId,
    required String messageId,
    required MemberModel sender,
    required String gifUrl,
    String? replyToId,
    String? replyText,
    String? replyToSenderName,
    String? replyToMediaUrl,
  }) async {
    final finalAvatar = sender.displayImageUrl ?? '';
    // ✅ تعديل جوهري: حذف createdAt: DateTime.now()
    final message = MessageModel(
      id: messageId,
      senderId: sender.userId,
      senderName: sender.effectiveName,
      senderAvatar: finalAvatar,
      senderRole: sender.role,
      senderIsPremium: sender.isPremium,
      mediaUrl: gifUrl,
      mediaType: 'gif',
      replyToId: replyToId,
      replyText: replyText,
      replyToSenderName: replyToSenderName,
      replyToMediaUrl: replyToMediaUrl,
      isDelivered: true,
    );
    await _firestore.createDocument(
      path: FirestorePaths.groupMessages(groupId),
      docId: messageId,
      data: message.toMap(),
    );
    await _firestore.updateDocument(
      path: FirestorePaths.groups,
      docId: groupId,
      data: {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': 'GIF',
      },
    );
  }

  // =========================================================
  // ✅ SEND AUDIO
  // =========================================================
  Future<void> sendAudioMessage({
    required String groupId,
    required String messageId,
    required MemberModel sender,
    required File audioFile,
    required int durationSeconds,
    String? replyToId,
    String? replyText,
    String? replyToSenderName,
    String? replyToMediaUrl,
  }) async {
    final audioUrl = await _storage.uploadGroupChatMedia(
      groupId: groupId,
      messageId: messageId,
      file: audioFile,
    );
    String? freshRealAvatar = sender.realUserImageUrl;
    String freshRealName = sender.realUserName ?? '';
    bool freshPremiumStatus = sender.isPremium;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sender.userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        freshRealAvatar = userData?['avatarUrl'];
        freshRealName = userData?['username'] ?? freshRealName;
        freshPremiumStatus = userData?['subscriptionType'] == 'premium';
      }
    } catch (e) {
      debugPrint("⚠️ Error fetching live user data for audio: $e");
    }
    final updatedSender = sender.copyWith(
      realUserImageUrl: freshRealAvatar,
      realUserName: freshRealName,
      isPremium: freshPremiumStatus,
    );
    final finalAvatar = updatedSender.displayImageUrl ?? '';
    // ✅ تعديل جوهري: حذف createdAt: DateTime.now()
    final message = MessageModel(
      id: messageId,
      senderId: updatedSender.userId,
      senderName: updatedSender.effectiveName,
      senderAvatar: finalAvatar,
      senderRole: updatedSender.role,
      senderIsPremium: updatedSender.isPremium,
      mediaUrl: audioUrl,
      mediaType: 'audio',
      audioDuration: durationSeconds,
      replyToId: replyToId,
      replyText: replyText,
      replyToSenderName: replyToSenderName,
      replyToMediaUrl: replyToMediaUrl,
      isDelivered: true,
    );
    await _firestore.createDocument(
      path: FirestorePaths.groupMessages(groupId),
      docId: messageId,
      data: message.toMap(),
    );
    await _firestore.updateDocument(
      path: FirestorePaths.groups,
      docId: groupId,
      data: {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': '🎤 رسالة صوتية',
      },
    );
  }

  // =========================================================
  Future<void> markAsDelivered({
    required String groupId,
    required String messageId,
  }) async {
    await _firestore.updateDocument(
      path: FirestorePaths.groupMessages(groupId),
      docId: messageId,
      data: {'isDelivered': true},
    );
  }

  Future<void> markAsRead({
    required String groupId,
    required String messageId,
  }) async {
    await _firestore.updateDocument(
      path: FirestorePaths.groupMessages(groupId),
      docId: messageId,
      data: {'isRead': true, 'isDelivered': true},
    );
  }

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
        data: {'reactions': updatedReactions});
  }

  Future<void> sendGameMessage({
    required String groupId,
    required String messageId,
    required MemberModel sender,
    required String gameId,
    String? gameSlot,
    String? gameAction,
  }) async {
    String? freshRealAvatar = sender.realUserImageUrl;
    bool freshPremiumStatus = sender.isPremium;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sender.userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        freshRealAvatar = userData?['avatarUrl'];
        freshPremiumStatus = userData?['subscriptionType'] == 'premium';
      }
    } catch (e) {
      debugPrint("⚠️ Error fetching live user data for game: $e");
    }
    final updatedSender = sender.copyWith(
        realUserImageUrl: freshRealAvatar, isPremium: freshPremiumStatus);
    final finalAvatar = updatedSender.displayImageUrl ?? '';
    // ✅ تعديل جوهري: حذف createdAt: DateTime.now()
    final message = MessageModel(
      id: messageId,
      senderId: updatedSender.userId,
      senderName: updatedSender.effectiveName,
      senderAvatar: finalAvatar,
      senderRole: updatedSender.role,
      senderIsPremium: updatedSender.isPremium,
      gameId: gameId,
      gameSlot: gameSlot,
      gameAction: gameAction,
      isDelivered: true,
    );
    await _firestore.createDocument(
        path: FirestorePaths.groupMessages(groupId),
        docId: messageId,
        data: message.toMap());
    await _firestore.updateDocument(
      path: FirestorePaths.groups,
      docId: groupId,
      data: {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': '🎮 لعبة',
      },
    );
  }

  // =========================================================
  // ✅ SEND STICKER
  // =========================================================
  Future<void> sendStickerMessage({
    required String groupId,
    required String messageId,
    required MemberModel sender,
    required String stickerUrl,
    String? replyToId,
    String? replyText,
    String? replyToSenderName,
    String? replyToMediaUrl,
  }) async {
    final finalAvatar = sender.displayImageUrl ?? '';
    // ✅ تعديل جوهري: حذف createdAt: DateTime.now()
    final message = MessageModel(
      id: messageId,
      senderId: sender.userId,
      senderName: sender.effectiveName,
      senderAvatar: finalAvatar,
      senderRole: sender.role,
      senderIsPremium: sender.isPremium,
      mediaUrl: stickerUrl,
      mediaType: 'sticker',
      replyToId: replyToId,
      replyText: replyText,
      replyToSenderName: replyToSenderName,
      replyToMediaUrl: replyToMediaUrl,
      isDelivered: true,
    );
    await _firestore.createDocument(
      path: FirestorePaths.groupMessages(groupId),
      docId: messageId,
      data: message.toMap(),
    );
    await _firestore.updateDocument(
      path: FirestorePaths.groups,
      docId: groupId,
      data: {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': '🏷️ ملصق',
      },
    );
  }

  Future<void> deleteMessage({
    required String groupId,
    required String messageId,
  }) async {
    await _firestore.deleteDocument(
        path: FirestorePaths.groupMessages(groupId), docId: messageId);
  }

  Future<MemberModel?> getMember({
    required String groupId,
    required String userId,
  }) async {
    final data = await _firestore.getDocument(
        path: FirestorePaths.groupMembers(groupId), docId: userId);
    if (data == null) return null;
    return MemberModel.fromMap(data);
  }

  Future<List<MessageModel>> getRecentMessages({
    required String groupId,
    int limit = 50,
  }) async {
    final path = FirestorePaths.groupMessages(groupId);
    final query = _firestore.buildQuery(
        path: path, orderBy: 'createdAt', descending: true, limit: limit);
    final snapshot = await _firestore.getCollection(path: path, query: query);
    return snapshot.docs
        .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
        .toList();
  }
}