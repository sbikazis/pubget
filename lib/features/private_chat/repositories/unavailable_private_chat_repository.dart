import 'dart:typed_data';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../groups/models/chat_models.dart';
import '../models/private_chat_models.dart';
import 'private_chat_repository.dart';

final class UnavailablePrivateChatRepository implements PrivateChatRepository {
  UnavailablePrivateChatRepository(this.message);

  final String message;

  FailureResult<T> _fail<T>() => FailureResult<T>(NetworkError(message));

  @override
  Future<Result<String>> startChat(String otherUserId) async => _fail();

  @override
  Stream<Result<List<PrivateChatSummary>>> watchChats({int limit = 20}) =>
      Stream<Result<List<PrivateChatSummary>>>.value(_fail());

  @override
  Future<Result<List<PrivateChatSummary>>> getOlderChats({
    required PrivateChatSummary before,
    int limit = 20,
  }) async => _fail();

  @override
  Stream<Result<List<ChatMessage>>> watchMessages(
    String chatId, {
    int limit = 40,
  }) => Stream<Result<List<ChatMessage>>>.value(_fail());

  @override
  Future<Result<List<ChatMessage>>> getOlderMessages({
    required String chatId,
    required ChatMessage before,
    int limit = 40,
  }) async => _fail();

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
  }) async => _fail();

  @override
  Future<Result<void>> deleteMessage({
    required String chatId,
    required String messageId,
  }) async => _fail();

  @override
  Future<Result<void>> markAsRead({
    required String chatId,
    required List<String> messageIds,
  }) async => _fail();

  @override
  Future<Result<void>> markAsDelivered({
    required String chatId,
    required List<String> messageIds,
  }) async => _fail();

  @override
  Future<Result<void>> deleteChat(String chatId) async => _fail();

  @override
  Future<Result<ChatMediaUpload>> uploadMedia({
    required String chatId,
    required String mediaId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required void Function(double progress) onProgress,
  }) async => _fail();
}
