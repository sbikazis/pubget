import 'dart:typed_data';

import '../../../core/errors/result.dart';
import '../../groups/models/chat_models.dart';
import '../models/private_chat_models.dart';

abstract interface class PrivateChatRepository {
  Future<Result<String>> startChat(String otherUserId);

  Stream<Result<List<PrivateChatSummary>>> watchChats({int limit = 20});

  Future<Result<List<PrivateChatSummary>>> getOlderChats({
    required PrivateChatSummary before,
    int limit = 20,
  });

  Stream<Result<List<ChatMessage>>> watchMessages(
    String chatId, {
    int limit = 40,
  });

  Future<Result<List<ChatMessage>>> getOlderMessages({
    required String chatId,
    required ChatMessage before,
    int limit = 40,
  });

  Future<Result<ChatMessage>> sendMessage({
    required String chatId,
    required String messageId,
    required ChatMessageType type,
    String? text,
    String? mediaUrl,
    String? thumbnailUrl,
    String? mediaId,
    String? replyToMessageId,
  });

  Future<Result<void>> deleteMessage({
    required String chatId,
    required String messageId,
  });

  Future<Result<void>> markAsRead({
    required String chatId,
    required List<String> messageIds,
  });

  Future<Result<void>> markAsDelivered({
    required String chatId,
    required List<String> messageIds,
  });

  Future<Result<void>> deleteChat(String chatId);

  Future<Result<ChatMediaUpload>> uploadMedia({
    required String chatId,
    required String mediaId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required void Function(double progress) onProgress,
  });
}
