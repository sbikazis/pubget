import 'dart:typed_data';

import '../../../core/errors/result.dart';
import '../models/chat_models.dart';

abstract interface class ChatRepository {
  Stream<Result<List<ChatMessage>>> watchMessages(
    String groupId, {
    int limit = 40,
  });

  Future<Result<List<ChatMessage>>> getOlderMessages({
    required String groupId,
    required ChatMessage before,
    int limit = 40,
  });

  Future<Result<ChatMessage>> sendMessage({
    required String groupId,
    required String messageId,
    required ChatMessageType type,
    String? text,
    String? mediaUrl,
    String? thumbnailUrl,
    String? mediaId,
    String? replyToMessageId,
  });

  Future<Result<ChatMessage>> editMessage({
    required String groupId,
    required String messageId,
    required String text,
  });

  Future<Result<void>> deleteMessage({
    required String groupId,
    required String messageId,
  });

  Future<Result<void>> pinMessage({
    required String groupId,
    required String messageId,
    required bool pinned,
  });

  Future<Result<void>> addReaction({
    required String groupId,
    required String messageId,
    required String reaction,
  });

  Future<Result<void>> markAsRead({
    required String groupId,
    required List<String> messageIds,
  });

  Future<Result<void>> markAsDelivered({
    required String groupId,
    required List<String> messageIds,
  });

  Future<Result<void>> updateChatBackground({
    required String groupId,
    required String? backgroundUrl,
  });

  Future<Result<ChatMediaUpload>> uploadMedia({
    required String groupId,
    required String mediaId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required void Function(double progress) onProgress,
  });
}
