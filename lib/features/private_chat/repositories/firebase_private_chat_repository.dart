import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/storage/media_upload_service.dart';
import '../../../core/storage/r2_storage_service.dart';

final class FirebasePrivateChatRepository implements PrivateChatRepository {
  FirebasePrivateChatRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
    MediaUploadService? mediaUploadService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _storage = storage ?? FirebaseStorage.instance,
       _mediaUploadService = mediaUploadService ?? MediaUploadService();

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final MediaUploadService _mediaUploadService;

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
    final uid = _uid ?? '';
    final isVideo = contentType.startsWith('video/');
    final type = isVideo ? ChatMessageType.video : ChatMessageType.image;
    
    R2UploadResult result;
    if (isVideo) {
      final dir = await getTemporaryDirectory();
      final ext = _extension(fileName, contentType);
      final file = File('${dir.path}/$mediaId.$ext');
      await file.writeAsBytes(bytes);
      result = await _mediaUploadService.uploadReel(userId: uid, video: file);
      await file.delete();
    } else {
      result = await _mediaUploadService.uploadImageBytes(
        userId: uid,
        bytes: bytes,
        extension: _extension(fileName, contentType),
      );
    }
    
    onProgress(0.5);
    try {
      await _chats
          .doc(chatId)
          .collection('media')
          .doc(mediaId)
          .set({
        'mediumPath': result.publicUrl,
        'originalPath': result.publicUrl,
        'status': 'ready',
        'type': type.name,
      }, SetOptions(merge: true));
    } catch (_) {}
    onProgress(1);
    
    return ChatMediaUpload(
      mediaUrl: result.publicUrl,
      thumbnailUrl: result.publicUrl,
      mediaId: mediaId,
      type: type,
    );
  });

  String _extension(String fileName, String contentType) {
    final candidate = fileName.split('.').last.toLowerCase();
    if (candidate.length <= 5 && RegExp(r'^[a-z0-9]+$').hasMatch(candidate)) {
      return candidate;
    }
    return contentType == 'image/png' ? 'png' : 'jpg';
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
