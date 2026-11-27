import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/media/media_kind.dart';
import '../../../core/media/media_repository_factory.dart';
import '../../../core/media/r2_media_storage_provider.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/chat_models.dart';
import '../services/chat_send_reliability.dart';
import 'chat_repository.dart';
import 'group_worker_client.dart';

final class FirebaseChatRepository implements ChatRepository {
  FirebaseChatRepository({
    FirebaseFirestore? firestore,
    // Kept for source compatibility with existing wiring; chat writes now go
    // through the authenticated Worker because Firebase Functions cannot run
    // on this project without billing.
    FirebaseFunctions? functions,
    GroupWorkerClient? workerClient,
    R2MediaStorageProvider? mediaStorage,
  }) : _firestoreOverride = firestore,
       _workerClient = workerClient ?? HttpGroupWorkerClient.forFirebase(),
       _mediaStorage = mediaStorage;

  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;
  final GroupWorkerClient _workerClient;
  R2MediaStorageProvider? _mediaStorage;

  R2MediaStorageProvider get _mediaStorageProvider =>
      _mediaStorage ??= createR2MediaStorageProvider();

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
  Future<Result<List<ChatMessage>>> getRecentMessages({
    required String groupId,
    int limit = 40,
  }) => _guard(() async {
    final snapshot = await _messages(groupId)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => ChatMessage.fromMap(doc.data(), id: doc.id))
        .toList(growable: false);
  });

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
    String? stickerKey,
    String? stickerCreatorId,
    String? stickerCreatorName,
  }) => _guard(() async {
    final result = await _workerClient.post(
      '/callables/sendGroupMessage',
      <String, dynamic>{
        'groupId': groupId,
        'messageId': messageId,
        'type': type.name,
        'text': ?text,
        'mediaId': ?mediaId,
        'replyToMessageId': ?replyToMessageId,
        'stickerKey': ?stickerKey,
        'stickerCreatorId': ?stickerCreatorId,
        'stickerCreatorName': ?stickerCreatorName,
      },
    );
    return ChatMessage.fromMap(
      Map<String, dynamic>.from(result['message'] as Map),
      id: result['messageId'] as String,
    );
  });

  @override
  Future<Result<ChatMessage>> editMessage({
    required String groupId,
    required String messageId,
    required String text,
  }) => _guard(() async {
    final result = await _workerClient.post(
      '/callables/editGroupMessage',
      <String, dynamic>{
        'groupId': groupId,
        'messageId': messageId,
        'text': text,
      },
    );
    return ChatMessage.fromMap(
      Map<String, dynamic>.from(result['message'] as Map),
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
  Future<Result<ChatMessage>> forwardMessage({
    required String sourceGroupId,
    required String messageId,
    String? destinationGroupId,
    String? destinationChatId,
  }) => _guard(() async {
    final result = await _workerClient.post(
      '/callables/forwardGroupMessage',
      <String, dynamic>{
        'sourceGroupId': sourceGroupId,
        'messageId': messageId,
        'destinationGroupId': ?destinationGroupId,
        'destinationChatId': ?destinationChatId,
      },
    );
    return ChatMessage.fromMap(
      Map<String, dynamic>.from(result['message'] as Map),
      id: result['messageId'] as String,
    );
  });

  @override
  Future<Result<void>> reportMessage({
    required String groupId,
    required String messageId,
    required String reason,
    String details = '',
  }) => _call('reportGroupMessage', {
    'groupId': groupId,
    'messageId': messageId,
    'reason': reason,
    'details': details,
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
    void Function()? onBytesUploaded,
  }) => _guard(() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || bytes.isEmpty) {
      throw const PermissionError('Sign in before sending media.');
    }
    final type = chatMediaTypeFor(contentType: contentType, fileName: fileName);
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
      scopeType: 'groups',
      scopeId: groupId,
      onProgress: onProgress,
    );
    onBytesUploaded?.call();

    // R2 is the source of truth for bytes. Chat media metadata remains in
    // Firestore, where existing group-member rules control who can read it.
    // Until an image/video transformation service is configured, original
    // objects are used as the display rendition; video bubbles use a poster
    // placeholder and open the original stream in the viewer.
    final mediaRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('media')
        .doc(mediaId);
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
      'mediaBackend': 'r2',
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

  @override
  Future<Result<ChatMediaUpload?>> findReadyMedia({
    required String groupId,
    required String mediaId,
  }) => _guard(() async {
    final snapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('media')
        .doc(mediaId)
        .get();
    final data = snapshot.data();
    if (data == null || data['status'] != 'ready') return null;
    return ChatMediaUpload(
      mediaUrl: (data['mediumPath'] ?? data['originalPath']) as String,
      thumbnailUrl: data['thumbnailPath'] as String?,
      mediaId: mediaId,
      type: switch (data['mediaType']) {
        'video' => ChatMessageType.video,
        'audio' => ChatMessageType.audio,
        _ => ChatMessageType.image,
      },
      width: (data['width'] as num?)?.toInt(),
      height: (data['height'] as num?)?.toInt(),
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
        await _workerClient.post('/callables/$name', data);
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
  if (error is GroupWorkerException) {
    return switch (error.statusCode) {
      401 || 403 => const PermissionError(ChatFailureCodes.permission),
      404 => const NotFoundError(ChatFailureCodes.notFound),
      409 => const TransactionConflictError(ChatFailureCodes.serviceUnavailable),
      429 => const RateLimitedError(ChatFailureCodes.rateLimited),
      >= 500 => const UnavailableError(ChatFailureCodes.serviceUnavailable),
      >= 400 => const ValidationError(ChatFailureCodes.validation),
      _ => const UnknownError(ChatFailureCodes.unknown),
    };
  }
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' ||
      'permission-denied' => const PermissionError(ChatFailureCodes.permission),
      'not-found' => const NotFoundError(ChatFailureCodes.notFound),
      // A callable answered: this is a service outage, never proof that the
      // device lost its connection. Showing "No internet" here was issue #200.
      'unavailable' ||
      'internal' ||
      'aborted' ||
      'data-loss' => const UnavailableError(
        ChatFailureCodes.serviceUnavailable,
      ),
      'deadline-exceeded' => const TimeoutError(ChatFailureCodes.timeout),
      'resource-exhausted' => const RateLimitedError(ChatFailureCodes.rateLimited),
      'invalid-argument' ||
      'failed-precondition' ||
      'already-exists' => const ValidationError(ChatFailureCodes.validation),
      _ => const UnavailableError(ChatFailureCodes.serviceUnavailable),
    };
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'network-request-failed' ||
      'network-error' => const NetworkError(ChatFailureCodes.network),
      'unavailable' ||
      'internal' ||
      'aborted' ||
      'data-loss' => const UnavailableError(
        ChatFailureCodes.serviceUnavailable,
      ),
      'deadline-exceeded' => const TimeoutError(ChatFailureCodes.timeout),
      _ => const UnavailableError(ChatFailureCodes.serviceUnavailable),
    };
  }
  return const UnknownError(ChatFailureCodes.unknown);
}
