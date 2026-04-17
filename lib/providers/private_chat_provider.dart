import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:async/async.dart';
import 'package:rxdart/rxdart.dart';

import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/fan_model.dart';

import '../services/firebase/firestore_service.dart';
import '../services/firebase/storage_service.dart';

import '../core/constants/firestore_paths.dart';
import '../core/constants/limits.dart';

class PrivateChatProvider extends ChangeNotifier {
  final FirestoreService _firestore;
  final StorageService _storage;

  PrivateChatProvider({
    required FirestoreService firestoreService,
    required StorageService storageService,
  }) : _firestore = firestoreService,
        _storage = storageService;

  // =========================================================
  // ✅ تحديث وقت القراءة للطرفين (تصفير عداد الخاص)
  // =========================================================
  Future<void> updatePrivateLastRead({
    required String chatId,
    required String userId,
  }) async {
    final chatDoc = await _firestore.getDocument(
      path: FirestorePaths.privateChats,
      docId: chatId,
    );

    if (chatDoc == null) return;

    final String fieldName =
        chatDoc['userA'] == userId ? 'lastReadUserA' : 'lastReadUserB';

    await _firestore.updateDocument(
      path: FirestorePaths.privateChats,
      docId: chatId,
      data: {
        fieldName: FieldValue.serverTimestamp(),
      },
    );
  }

  // =========================================================
  // ✅ مراقبة الرسائل غير المقروءة بشكل حي (Real-time Stream)
  // التعديل: تبسيط الاستعلام لضمان استجابة Firestore الفورية
  // =========================================================
  Stream<int> streamPrivateUnreadCount({
    required String chatId,
    required String userId,
  }) {
    final path = FirestorePaths.privateMessages(chatId);

    return _firestore
        .streamDocument(path: FirestorePaths.privateChats, docId: chatId)
        .switchMap((chatSnap) {
      if (!chatSnap.exists) return Stream.value(0);

      final data = chatSnap.data() as Map<String, dynamic>;
      final isUserA = data['userA'] == userId;
      final Timestamp? lastRead =
          isUserA ? data['lastReadUserA'] : data['lastReadUserB'];

      // إذا لم يقرأ أبداً نستخدم تاريخاً قديماً جداً
      final compareDate = lastRead ?? Timestamp.fromDate(DateTime(2000));

      final query = _firestore.buildQuery(
        path: path,
        conditions: [
          // تم تبسيط الاستعلام هنا لضمان عمل الـ Index بشكل صحيح مع createdAt
          QueryCondition(field: 'createdAt', isGreaterThan: compareDate),
        ],
      );

      return _firestore
          .streamCollection(path: path, query: query)
          .map((snap) {
            // نقوم بفلترة رسائل المستخدم نفسه برمجياً لضمان عدم تعطل الـ Query
            return snap.docs.where((doc) => doc.data()['senderId'] != userId).length;
          });
    }).distinct();
  }

  // =========================================================
  // ✅ مراقبة "إجمالي" الرسائل غير المقروءة لكل الدردشات الخاصة
  // =========================================================
  Stream<int> streamAllPrivateUnreadCount(String userId) {
    final queryA = _firestore.buildQuery(
      path: FirestorePaths.privateChats,
      conditions: [QueryCondition(field: "userA", isEqualTo: userId)],
    );
    final queryB = _firestore.buildQuery(
      path: FirestorePaths.privateChats,
      conditions: [QueryCondition(field: "userB", isEqualTo: userId)],
    );

    return StreamGroup.merge([
      _firestore.streamCollection(path: FirestorePaths.privateChats, query: queryA),
      _firestore.streamCollection(path: FirestorePaths.privateChats, query: queryB),
    ]).switchMap((snapshot) {
      if (snapshot.docs.isEmpty) return Stream.value(0);

      final List<Stream<int>> unreadStreams = snapshot.docs.map((doc) {
        return streamPrivateUnreadCount(chatId: doc.id, userId: userId);
      }).toList();

      return Rx.combineLatestList(unreadStreams).map((counts) {
        return counts.fold<int>(0, (sum, count) => sum + count);
      });
    }).distinct();
  }

  // =========================================================
  // CREATE CHAT IF NOT EXISTS
  // =========================================================
  Future<void> createPrivateChat({
    required String chatId,
    required String userA,
    required String userB,
  }) async {
    final existing = await _firestore.getDocument(
      path: FirestorePaths.privateChats,
      docId: chatId,
    );

    if (existing != null) return;

    await _firestore.createDocument(
      path: FirestorePaths.privateChats,
      docId: chatId,
      data: {
        "userA": userA,
        "userB": userB,
        "createdAt": FieldValue.serverTimestamp(),
        "lastMessageAt": FieldValue.serverTimestamp(), // مضاف للفرز والتنبيه
        "lastReadUserA": null,
        "lastReadUserB": null,
      },
    );
  }

  // =========================================================
  // STREAM PRIVATE MESSAGES
  // =========================================================
  Stream<List<MessageModel>> streamMessages({
    required String chatId,
  }) {
    final path = FirestorePaths.privateMessages(chatId);

    final query = _firestore.buildQuery(
      path: path,
      orderBy: "createdAt",
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
  // ✅ التعديل: تحديث وثيقة الدردشة الأساسية لإطلاق الـ Stream
  // =========================================================
  Future<void> sendTextMessage({
    required String chatId,
    required String messageId,
    required UserModel sender,
    required String text,
    String? replyToId,
    String? replyText,
  }) async {
    if (text.trim().isEmpty) return;

    if (text.length > Limits.maxMessageLength) {
      throw Exception("Message too long");
    }

    final message = MessageModel(
      id: messageId,
      senderId: sender.id,
      senderName: sender.username,
      senderAvatar: sender.avatarUrl,
      senderRole: null,
      text: text.trim(),
      replyToId: replyToId,
      replyText: replyText,
      createdAt: DateTime.now(),
    );

    // 1. إنشاء رسالة جديدة
    await _firestore.createDocument(
      path: FirestorePaths.privateMessages(chatId),
      docId: messageId,
      data: message.toMap(),
    );

    // 2. تحديث الوثيقة الأم (الشرارة) لتنبيه الطرف الآخر فوراً
    await _firestore.updateDocument(
      path: FirestorePaths.privateChats,
      docId: chatId,
      data: {
        "lastMessageAt": FieldValue.serverTimestamp(),
        "lastMessageText": text.trim(), // مفيد للمعاينة في القائمة
      },
    );
  }

  // =========================================================
  // SEND MEDIA MESSAGE
  // ✅ التعديل: تحديث وثيقة الدردشة الأساسية لإطلاق الـ Stream
  // =========================================================
  Future<void> sendMediaMessage({
    required String chatId,
    required String messageId,
    required UserModel sender,
    required File file,
    required String mediaType,
    String? replyToId,
    String? replyText,
  }) async {
    final mediaUrl = await _storage.uploadPrivateChatMedia(
      chatId: chatId,
      messageId: messageId,
      file: file,
    );

    final message = MessageModel(
      id: messageId,
      senderId: sender.id,
      senderName: sender.username,
      senderAvatar: sender.avatarUrl,
      senderRole: null,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      replyToId: replyToId,
      replyText: replyText,
      createdAt: DateTime.now(),
    );

    // 1. إنشاء رسالة الميديا
    await _firestore.createDocument(
      path: FirestorePaths.privateMessages(chatId),
      docId: messageId,
      data: message.toMap(),
    );

    // 2. تحديث الوثيقة الأم لتنبيه الطرف الآخر
    await _firestore.updateDocument(
      path: FirestorePaths.privateChats,
      docId: chatId,
      data: {
        "lastMessageAt": FieldValue.serverTimestamp(),
        "lastMessageText": mediaType == 'image' ? '📷 صورة' : '🎥 فيديو',
      },
    );
  }

  // =========================================================
  // ✅ إضافة: معالجة التفاعلات (Reactions) في الدردشة الخاصة
  // =========================================================
  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final path = FirestorePaths.privateMessages(chatId);
    
    final messageData = await _firestore.getDocument(
      path: path,
      docId: messageId,
    );

    if (messageData == null) return;

    final Map<String, String> currentReactions = messageData['reactions'] != null 
        ? Map<String, String>.from(messageData['reactions']) 
        : {};

    // إذا كان المستخدم قد تفاعل بنفس الإيموجي سابقاً، نقوم بإزالته (Toggle)
    if (currentReactions[userId] == emoji) {
      currentReactions.remove(userId);
    } else {
      currentReactions[userId] = emoji;
    }

    await _firestore.updateDocument(
      path: path,
      docId: messageId,
      data: {'reactions': currentReactions},
    );
  }

  // =========================================================
  // DELETE MESSAGE
  // =========================================================
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    await _firestore.deleteDocument(
      path: FirestorePaths.privateMessages(chatId),
      docId: messageId,
    );
  }

  // =========================================================
  // GET USER CHATS
  // =========================================================
  Future<List<Map<String, dynamic>>> getUserChats({
    required String userId,
  }) async {
    final queryA = _firestore.buildQuery(
      path: FirestorePaths.privateChats,
      conditions: [
        QueryCondition(
          field: "userA",
          isEqualTo: userId,
        ),
      ],
    );

    final queryB = _firestore.buildQuery(
      path: FirestorePaths.privateChats,
      conditions: [
        QueryCondition(
          field: "userB",
          isEqualTo: userId,
        ),
      ],
    );

    final results = await Future.wait([
      _firestore.getCollection(path: FirestorePaths.privateChats, query: queryA),
      _firestore.getCollection(path: FirestorePaths.privateChats, query: queryB),
    ]);

    final allDocs = [...results[0].docs, ...results[1].docs];

    // ترتيب المحادثات حسب آخر رسالة
    allDocs.sort((a, b) {
      final aTime = (a.data()['lastMessageAt'] as Timestamp?) ?? Timestamp.now();
      final bTime = (b.data()['lastMessageAt'] as Timestamp?) ?? Timestamp.now();
      return bTime.compareTo(aTime);
    });

    return allDocs.map((doc) {
      return {
        "chatId": doc.id,
        ...doc.data() as Map<String, dynamic>,
      };
    }).toList();
  }

  // =========================================================
  // GET AVAILABLE PRIVATE CHATS
  // =========================================================
  Future<List<Map<String, dynamic>>> getAvailablePrivateChats({
    required String userId,
  }) async {
    final fanOfQuery = _firestore.buildQuery(
      path: FirestorePaths.fans,
      conditions: [
        QueryCondition(field: "fanUserId", isEqualTo: userId),
      ],
    );

    final myFansQuery = _firestore.buildQuery(
      path: FirestorePaths.fans,
      conditions: [
        QueryCondition(field: "targetUserId", isEqualTo: userId),
      ],
    );

    final results = await Future.wait([
      _firestore.getCollection(path: FirestorePaths.fans, query: fanOfQuery),
      _firestore.getCollection(path: FirestorePaths.fans, query: myFansQuery),
      getUserChats(userId: userId),
    ]);

    final fanOfDocs = (results[0] as QuerySnapshot).docs;
    final myFansDocs = (results[1] as QuerySnapshot).docs;
    final existingChats = results[2] as List<Map<String, dynamic>>;

    final Set<String> eligibleUserIds = {};

    for (var doc in fanOfDocs) {
      final data = doc.data() as Map<String, dynamic>;
      eligibleUserIds.add(data['targetUserId']);
    }

    for (var doc in myFansDocs) {
      final data = doc.data() as Map<String, dynamic>;
      eligibleUserIds.add(data['fanUserId']);
    }

    final List<Map<String, dynamic>> finalAvailableChats = [];

    final Map<String, Map<String, dynamic>> chatMap = {};
    for (var chat in existingChats) {
      final otherId = chat['userA'] == userId ? chat['userB'] : chat['userA'];
      chatMap[otherId] = chat;
    }

    for (String otherUserId in eligibleUserIds) {
      if (chatMap.containsKey(otherUserId)) {
        finalAvailableChats.add(chatMap[otherUserId]!);
      }
    }

    return finalAvailableChats;
  }

  // =========================================================
  // GET USER FANS
  // =========================================================
  Future<List<FanModel>> getUserFans({
    required String userId,
  }) async {
    final query = _firestore.buildQuery(
      path: FirestorePaths.fans,
      conditions: [
        QueryCondition(
          field: "targetUserId",
          isEqualTo: userId,
        ),
      ],
    );

    final snapshot = await _firestore.getCollection(
      path: FirestorePaths.fans,
      query: query,
    );

    return snapshot.docs
        .map(
          (doc) => FanModel.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  // =========================================================
  // GET USER BY ID
  // =========================================================
  Future<UserModel?> getUserById(String userId) async {
    final data = await _firestore.getDocument(
      path: FirestorePaths.users,
      docId: userId,
    );

    if (data == null) return null;

    return UserModel.fromMap(
      data,
      userId,
    );
  }
}