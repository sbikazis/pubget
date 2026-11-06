import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/media/media_kind.dart';
import '../../../core/media/media_repository_factory.dart';
import '../../../core/media/r2_media_storage_provider.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../groups/models/chat_models.dart';
import '../../groups/services/chat_send_reliability.dart';
import '../models/private_chat_models.dart';
import 'private_chat_repository.dart';

final class FirebasePrivateChatRepository implements PrivateChatRepository {
  FirebasePrivateChatRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    R2MediaStorageProvider? mediaStorage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _mediaStorage = mediaStorage;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  R2MediaStorageProvider? _mediaStorage;

  R2MediaStorageProvider get _mediaStorageProvider =>
      _mediaStorage ??= createR2MediaStorageProvider();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('privateChats');

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _chats.doc(chatId).collection('messages');

  Query<Map<String, dynamic>> _listQuery(String uid) => _chats
      .where('participantIds', arrayContains: uid)
      .orderBy('lastMessageAt', descending: true)
      .orderBy(FieldPath.documentId, descending: true);

  List<PrivateChatSummary> _summaries(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String uid,
  ) {
    return snapshot.docs
        .map((doc) => PrivateChatSummary.fromMap(doc.data(), id: doc.id))
        .where((chat) => !chat.isHiddenFor(uid))
        .toList(growable: false);
  }

  @override
  Future<Result<String>> startChat(String otherUserId) => _guard(() async {
    final result = await _functions.httpsCallable('startPrivateChat').call(
      <String, dynamic>{'otherUserId': otherUserId},
    );
    return result.data['chatId'] as String;
  });

  @override
  Stream<Result<List<PrivateChatSummary>>> watchChats({int limit = 20}) {
    final uid = _uid;
    if (uid == null) {
      return Stream<Result<List<PrivateChatSummary>>>.value(
        const FailureResult<List<PrivateChatSummary>>(
          PermissionError('Sign in to view private chats.'),
        ),
      );
    }
    return _listQuery(uid)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              Success<List<PrivateChatSummary>>(_summaries(snapshot, uid)),
        )
        .handleError(
          (Object error) =>
              FailureResult<List<PrivateChatSummary>>(_chatFailure(error)),
        );
  }

  @override
  Future<Result<List<PrivateChatSummary>>> getOlderChats({
    required PrivateChatSummary before,
    int limit = 20,
  }) => _guard(() async {
    final uid = _uid;
    if (uid == null) return const <PrivateChatSummary>[];
    final timestamp = before.lastMessageAt;
    if (timestamp == null) return const <PrivateChatSummary>[];
    final snapshot = await _listQuery(uid)
        .startAfter(<Object>[Timestamp.fromDate(timestamp), before.id])
        .limit(limit)
        .get();
    return _summaries(snapshot, uid);
  });

  @override
  Stream<Result<List<ChatMessage>>> watchMessages(
    String chatId, {
    int limit = 40,
  }) {
    return _messages(chatId)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => Success<List<ChatMessage>>(
            snapshot.docs
                .map((doc) => ChatMessage.fromMap(doc.data(), id: doc.id))
                .toList(growable: false),
          ),
        )
        .handleError(
          (Object error) =>
              FailureResult<List<ChatMessage>>(_chatFailure(error)),
        );
  }

  @override
  Future<Result<List<ChatMessage>>> getOlderMessages({
    required String chatId,
    required ChatMessage before,
    int limit = 40,
  }) => _guard(() async {
    final timestamp = before.createdAt;
    if (timestamp == null) return const <ChatMessage>[];
    final snapshot = await _messages(chatId)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .startAfter(<Object>[Timestamp.fromDate(timestamp), before.id])
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => ChatMessage.fromMap(doc.data(), id: doc.id))
        .toList(growable: false);
  });

  @override
  Future<Result<ChatMessage>> sendMessage({
    required String chatId,
    required String messageId,
    required ChatMessageType type,
    String? text,
    String? mediaUrl,
    String? thumbnailUrl,
    String? mediaId,
    String? replyToMessageId,
  }) => _guard(() async {
    final result = await _functions
        .httpsCallable('sendPrivateMessage')
        .call(<String, dynamic>{
          'chatId': chatId,
          'messageId': messageId,
          'type': type.name,
          'text': ?text,
          'mediaId': ?mediaId,
          'replyToMessageId': ?replyToMessageId,
        });
    return ChatMessage.fromMap(
      Map<String, dynamic>.from(result.data['message'] as Map),
      id: result.data['messageId'] as String,
    );
  });

  @override
  Future<Result<void>> deleteMessage({
    required String chatId,
    required String messageId,
  }) =>
      _call('deletePrivateMessage', {'chatId': chatId, 'messageId': messageId});

  @override
  Future<Result<void>> markAsRead({
    required String chatId,
    required List<String> messageIds,
  }) => _call('markPrivateMessagesRead', {
    'chatId': chatId,
    'messageIds': messageIds,
  });

  @override
  Future<Result<void>> markAsDelivered({
    required String chatId,
    required List<String> messageIds,
  }) => _call('markPrivateMessagesDelivered', {
    'chatId': chatId,
    'messageIds': messageIds,
  });

  @override
  Future<Result<void>> deleteChat(String chatId) =>
      _call('deletePrivateChat', {'chatId': chatId});

  @override
  Future<Result<ChatMediaUpload>> uploadMedia({
    required String chatId,
    required String mediaId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required void Function(double progress) onProgress,
  }) => _guard(() async {
    final uid = _uid;
    if (uid == null || bytes.isEmpty) {
      throw const PermissionError('Sign in before sending media.');
    }
    final type = contentType.startsWith('video/')
        ? ChatMessageType.video
        : contentType.startsWith('audio/')
            ? ChatMessageType.audio
            : ChatMessageType.image;
    final kind = type == ChatMessageType.video
        ? MediaKind.reels
        : type == ChatMessageType.audio
            ? MediaKind.audio
            : MediaKind.image;
    final extension = _extension(fileName, contentType);
    final path = await _mediaStorageProvider.upload(
      ownerUid: uid,
      kind: kind,
      bytes: bytes,
      contentType: contentType,
      extension: extension,
      scopeType: 'privateChats',
      scopeId: chatId,
      onProgress: onProgress,
    );

    final mediaRef = _chats.doc(chatId).collection('media').doc(mediaId);
    await mediaRef.set({
      'mediaId': mediaId,
      'uploaderId': uid,
      'mediaType': type == ChatMessageType.video
          ? 'video'
          : type == ChatMessageType.audio
              ? 'audio'
              : 'image',
      'originalPath': path,
      'thumbnailPath': type == ChatMessageType.image ? path : null,
      'mediumPath': type == ChatMessageType.image ? path : null,
      'status': 'ready',
      'contentType': contentType,
      'sizeBytes': bytes.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
    onProgress(1);

    return ChatMediaUpload(
      mediaUrl: path,
      thumbnailUrl: type == ChatMessageType.image ? path : null,
      mediaId: mediaId,
      type: type,
    );
  });

  String _extension(String fileName, String contentType) {
    if (contentType == 'video/quicktime') return 'mov';
    if (contentType == 'video/webm') return 'webm';
    if (contentType.startsWith('video/')) return 'mp4';
    if (contentType == 'audio/mpeg') return 'mp3';
    if (contentType == 'audio/aac') return 'aac';
    if (contentType == 'audio/ogg') return 'ogg';
    if (contentType == 'audio/mp4') return 'm4a';
    if (contentType == 'image/png') return 'png';
    if (contentType == 'image/webp') return 'webp';
    if (contentType == 'image/gif') return 'gif';
    return 'jpg';
  }
  Future<Result<void>> _call(String name, Map<String, dynamic> data) =>
      _guard(() async {
        await _functions.httpsCallable(name).call(data);
      });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success<T>(await action());
    } on Object catch (error) {
      return FailureResult<T>(_chatFailure(error));
    }
  }
}

Failure _chatFailure(Object error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' ||
      'permission-denied' => const PermissionError(ChatFailureCodes.permission),
      'not-found' => const NotFoundError(ChatFailureCodes.notFound),
      'unavailable' ||
      'deadline-exceeded' ||
      'resource-exhausted' => const NetworkError(ChatFailureCodes.network),
      'invalid-argument' ||
      'failed-precondition' ||
      'already-exists' => const ValidationError(ChatFailureCodes.validation),
      _ => UnknownError(error.message ?? ChatFailureCodes.unknown),
    };
  }
  if (error is FirebaseException &&
      (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
    return const NetworkError(ChatFailureCodes.network);
  }
  return UnknownError(error.toString());
}
