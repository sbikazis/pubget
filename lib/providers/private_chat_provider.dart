import 'dart:io';
import 'package:flutter/material.dart';

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
  })  : _firestore = firestoreService,
        _storage = storageService;

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
        "createdAt": DateTime.now(),
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
  // =========================================================

  Future<void> sendTextMessage({
    required String chatId,
    required String messageId,
    required UserModel sender,
    required String text,
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
      senderRole: null as dynamic,
      text: text.trim(),
      createdAt: DateTime.now(),
    );

    await _firestore.createDocument(
      path: FirestorePaths.privateMessages(chatId),
      docId: messageId,
      data: message.toMap(),
    );
  }

  // =========================================================
  // SEND MEDIA MESSAGE
  // =========================================================

  Future<void> sendMediaMessage({
    required String chatId,
    required String messageId,
    required UserModel sender,
    required File file,
    required String mediaType,
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
      senderRole: null as dynamic,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      createdAt: DateTime.now(),
    );

    await _firestore.createDocument(
      path: FirestorePaths.privateMessages(chatId),
      docId: messageId,
      data: message.toMap(),
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
  // GET USER PRIVATE CHATS
  // =========================================================

  Future<List<Map<String, dynamic>>> getUserChats({
    required String userId,
  }) async {
    final query = _firestore.buildQuery(
      path: FirestorePaths.privateChats,
      conditions: [
        QueryCondition(
          field: "userA",
          isEqualTo: userId,
        ),
      ],
    );

    final snapshot = await _firestore.getCollection(
      path: FirestorePaths.privateChats,
      query: query,
    );

    return snapshot.docs.map((doc) {
      return {
        "chatId": doc.id,
        ...doc.data(),
      };
    }).toList();
  }

  // =========================================================
  // GET FANS OF USER
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
            doc.data(),
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