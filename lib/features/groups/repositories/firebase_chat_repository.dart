import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/chat_models.dart';
import 'chat_repository.dart';

final class FirebaseChatRepository implements ChatRepository {
  FirebaseChatRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> _messages(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('messages');

  @override
  Stream<Result<List<ChatMessage>>> watchMessages(
    String groupId, {
    int limit = 40,
  }) {
    return _messages(groupId)
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
    required String groupId,
    required ChatMessage before,
    int limit = 40,
  }) => _guard(() async {
    final timestamp = before.createdAt;
    if (timestamp == null) return const <ChatMessage>[];
    final snapshot = await _messages(groupId)
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
    required String groupId,
    required String messageId,
    required ChatMessageType type,
    String? text,
    String? mediaUrl,
    String? thumbnailUrl,
    String? mediaId,
    String? replyToMessageId,
  }) => _guard(() async {
    final result = await _functions
        .httpsCallable('sendGroupMessage')
        .call(<String, dynamic>{
          'groupId': groupId,
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
  Future<Result<ChatMessage>> editMessage({
    required String groupId,
    required String messageId,
    required String text,
  }) => _guard(() async {
    final result = await _functions.httpsCallable('editGroupMessage').call(
      <String, dynamic>{
        'groupId': groupId,
        'messageId': messageId,
        'text': text,
      },
    );
    return ChatMessage.fromMap(
      Map<String, dynamic>.from(result.data['message'] as Map),
      id: messageId,
    );
  });

  @override
  Future<Result<void>> deleteMessage({
    required String groupId,
    required String messageId,
  }) =>
      _call('deleteGroupMessage', {'groupId': groupId, 'messageId': messageId});

  @override
  Future<Result<void>> pinMessage({
    required String groupId,
    required String messageId,
    required bool pinned,
  }) => _call('pinGroupMessage', {
    'groupId': groupId,
    'messageId': messageId,
    'pinned': pinned,
  });

  @override
  Future<Result<void>> addReaction({
    required String groupId,
    required String messageId,
    required String reaction,
  }) => _call('addGroupMessageReaction', {
    'groupId': groupId,
    'messageId': messageId,
    'reaction': reaction,
  });

  @override
  Future<Result<void>> markAsRead({
    required String groupId,
    required List<String> messageIds,
  }) => _call('markGroupMessagesRead', {
    'groupId': groupId,
    'messageIds': messageIds,
  });

  @override
  Future<Result<void>> markAsDelivered({
    required String groupId,
    required List<String> messageIds,
  }) => _call('markGroupMessagesDelivered', {
    'groupId': groupId,
    'messageIds': messageIds,
  });

  @override
  Future<Result<void>> updateChatBackground({
    required String groupId,
    required String? backgroundUrl,
  }) => _call('updateGroupChatBackground', {
    'groupId': groupId,
    'backgroundUrl': ?backgroundUrl,
  });

  @override
  Future<Result<ChatMediaUpload>> uploadMedia({
    required String groupId,
    required String mediaId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required void Function(double progress) onProgress,
  }) => _guard(() async {
    final extension = _extension(fileName, contentType);
    final type = contentType.startsWith('video/')
        ? ChatMessageType.video
        : ChatMessageType.image;
    final path = 'groups/$groupId/media/${mediaId}_original.$extension';
    final reference = _storage.ref(path);
    final task = reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: <String, String>{
          'uploadedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
          'mediaId': mediaId,
          'pipeline': 'pubget-chat-v1',
        },
      ),
    );
    task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });
    await task;
    onProgress(1);
    final mediaSnapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('media')
        .doc(mediaId)
        .snapshots()
        .firstWhere(
          (snapshot) =>
              snapshot.data()?['status'] == 'ready' ||
              snapshot.data()?['status'] == 'failed',
        )
        .timeout(const Duration(minutes: 3));
    final data = mediaSnapshot.data() ?? const <String, dynamic>{};
    if (data['status'] != 'ready') {
      throw StateError('Media processing failed.');
    }
    return ChatMediaUpload(
      mediaUrl: (data['mediumPath'] ?? data['originalPath']) as String,
      thumbnailUrl: data['thumbnailPath'] as String?,
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
      'unauthenticated' || 'permission-denied' => PermissionError(
        error.message ?? 'This chat action is not allowed.',
      ),
      'not-found' => NotFoundError(error.message ?? 'Message not found.'),
      'unavailable' || 'deadline-exceeded' || 'resource-exhausted' =>
        NetworkError(error.message ?? 'Check your connection and try again.'),
      _ => ValidationError(error.message ?? 'Chat action failed.'),
    };
  }
  if (error is FirebaseException &&
      (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
    return NetworkError(
      error.message ?? 'Check your connection and try again.',
    );
  }
  return UnknownError(error.toString());
}
