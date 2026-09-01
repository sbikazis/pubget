import 'dart:typed_data';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/chat_models.dart';
import 'chat_repository.dart';

final class UnavailableChatRepository implements ChatRepository {
  UnavailableChatRepository(this.message);

  final String message;

  FailureResult<T> _fail<T>() => FailureResult<T>(NetworkError(message));

  @override
  Stream<Result<List<ChatMessage>>> watchMessages(
    String groupId, {
    int limit = 40,
  }) => Stream<Result<List<ChatMessage>>>.value(_fail());

  @override
  Future<Result<List<ChatMessage>>> getOlderMessages({
    required String groupId,
    required ChatMessage before,
    int limit = 40,
  }) async => _fail();

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
  }) async => _fail();

  @override
  Future<Result<ChatMessage>> editMessage({
    required String groupId,
    required String messageId,
    required String text,
  }) async => _fail();

  @override
  Future<Result<void>> deleteMessage({
    required String groupId,
    required String messageId,
  }) async => _fail();

  @override
  Future<Result<void>> pinMessage({
    required String groupId,
    required String messageId,
    required bool pinned,
  }) async => _fail();

  @override
  Future<Result<void>> addReaction({
    required String groupId,
    required String messageId,
    required String reaction,
  }) async => _fail();

  @override
  Future<Result<void>> markAsRead({
    required String groupId,
    required List<String> messageIds,
  }) async => _fail();

  @override
  Future<Result<void>> markAsDelivered({
    required String groupId,
    required List<String> messageIds,
  }) async => _fail();

  @override
  Future<Result<void>> updateChatBackground({
    required String groupId,
    required String? backgroundUrl,
  }) async => _fail();

  @override
  Future<Result<ChatMediaUpload>> uploadMedia({
    required String groupId,
    required String mediaId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required void Function(double progress) onProgress,
  }) async => _fail();
}
