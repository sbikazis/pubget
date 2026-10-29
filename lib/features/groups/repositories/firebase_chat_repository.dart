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

final class FirebaseChatRepository implements ChatRepository {
  FirebaseChatRepository({
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
    String? stickerKey,
    String? stickerCreatorId,
    String? stickerCreatorName,
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
          'stickerKey': ?stickerKey,
          'stickerCreatorId': ?stickerCreatorId,
          'stickerCreatorName': ?stickerCreatorName,
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
  Future<Result<ChatMessage>> forwardMessage({
    required String sourceGroupId,
    required String messageId,
    String? destinationGroupId,
    String? destinationChatId,
  }) => _guard(() async {
    final result = await _functions
        .httpsCallable('forwardGroupMessage')
        .call(<String, dynamic>{
          'sourceGroupId': sourceGroupId,
          'messageId': messageId,
          'destinationGroupId': ?destinationGroupId,
          'destinationChatId': ?destinationChatId,
        });
    return ChatMessage.fromMap(
      Map<String, dynamic>.from(result.data['message'] as Map),
      id: result.data['messageId'] as String,
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
    final type = chatMediaTypeFor(contentType: contentType, fileName: fileName);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    R2UploadResult result;
    if (type == ChatMediaType.video) {
      // Save to temp file for video
      final dir = await getTemporaryDirectory();
      final ext = _extension(fileName, contentType);
      final file = File('${dir.path}/$mediaId.$ext');
      await file.writeAsBytes(bytes);
      result = await _mediaUploadService.uploadReel(userId: uid, video: file);
      await file.delete();
    } else if (type == ChatMediaType.audio) {
      final dir = await getTemporaryDirectory();
      final ext = _extension(fileName, contentType);
      final file = File('${dir.path}/$mediaId.$ext');
      await file.writeAsBytes(bytes);
      result = await _mediaUploadService.uploadAudio(userId: uid, audio: file);
      await file.delete();
    } else {
      result = await _mediaUploadService.uploadImageBytes(
        userId: uid,
        bytes: bytes,
        extension: _extension(fileName, contentType),
      );
    }
    
    onProgress(0.5);
    onBytesUploaded?.call();
    
    // Try to update media doc if exists
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
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
    if (contentType.startsWith('audio/')) return 'm4a';
    if (contentType == 'image/gif') return 'gif';
    if (contentType == 'image/png') return 'png';
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
      'unauthenticated' || 'permission-denied' => const PermissionError(
        ChatFailureCodes.permission,
      ),
      'not-found' => const NotFoundError(ChatFailureCodes.notFound),
      'unavailable' || 'deadline-exceeded' || 'resource-exhausted' =>
        const NetworkError(ChatFailureCodes.network),
      'invalid-argument' || 'failed-precondition' || 'already-exists' =>
        const ValidationError(ChatFailureCodes.validation),
      _ => ValidationError(error.message ?? ChatFailureCodes.unknown),
    };
  }
  if (error is FirebaseException &&
      (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
    return const NetworkError(ChatFailureCodes.network);
  }
  return UnknownError(error.toString());
}
