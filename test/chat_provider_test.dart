import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/groups/providers/chat_provider.dart';
import 'package:pubget/features/groups/repositories/chat_repository.dart';

void main() {
  test(
    'optimistic message remains pending until server confirmation',
    () async {
      final repository = _FakeChatRepository();
      final provider = ChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(groupId: 'g1', currentUserId: 'alice');

      final operation = provider.sendText(
        groupId: 'g1',
        senderId: 'alice',
        senderName: 'Alice',
        senderAvatar: '',
        senderRole: 'member',
        text: 'Hello',
      );

      expect(provider.messages.single.sendState, ChatSendState.pending);
      final pending = provider.messages.single;
      repository.sendCompleter.complete(Success(_serverMessage(pending.id)));
      await operation;

      expect(provider.messages.single.sendState, ChatSendState.sent);
      expect(provider.messages.single.isOptimistic, isFalse);
    },
  );

  test('failed send remains visible and can be retried or deleted', () async {
    final repository = _FakeChatRepository();
    final provider = ChatProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.open(groupId: 'g1', currentUserId: 'alice');

    final operation = provider.sendText(
      groupId: 'g1',
      senderId: 'alice',
      senderName: 'Alice',
      senderAvatar: '',
      senderRole: 'member',
      text: 'Keep me',
    );
    repository.sendCompleter.complete(
      const FailureResult(NetworkError('offline')),
    );
    await operation;

    final failed = provider.messages.single;
    expect(failed.sendState, ChatSendState.failed);
    expect(failed.failureMessage, 'offline');

    repository.sendCompleter = Completer<Result<ChatMessage>>();
    final retry = provider.retry(failed);
    repository.sendCompleter.complete(Success(_serverMessage(failed.id)));
    await retry;
    expect(provider.messages.single.sendState, ChatSendState.sent);

    repository.sendCompleter = Completer<Result<ChatMessage>>();
    final second = provider.sendText(
      groupId: 'g1',
      senderId: 'alice',
      senderName: 'Alice',
      senderAvatar: '',
      senderRole: 'member',
      text: 'Remove me',
    );
    repository.sendCompleter.complete(
      const FailureResult(NetworkError('offline')),
    );
    await second;
    final failedAgain = provider.messages.last;
    provider.removeFailed(failedAgain.id);
    expect(
      provider.messages.any((message) => message.id == failedAgain.id),
      isFalse,
    );
  });

  test(
    'stream merges incrementally and preserves failed local messages',
    () async {
      final repository = _FakeChatRepository();
      final provider = ChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(groupId: 'g1', currentUserId: 'alice');
      repository.stream.add(Success(<ChatMessage>[_serverMessage('one')]));
      await pumpEventQueue();

      final send = provider.sendText(
        groupId: 'g1',
        senderId: 'alice',
        senderName: 'Alice',
        senderAvatar: '',
        senderRole: 'member',
        text: 'offline',
      );
      repository.sendCompleter.complete(
        const FailureResult(NetworkError('offline')),
      );
      await send;
      repository.stream.add(
        Success(<ChatMessage>[_serverMessage('one'), _serverMessage('two')]),
      );
      await pumpEventQueue();

      expect(provider.messages.map((message) => message.id), contains('one'));
      expect(provider.messages.map((message) => message.id), contains('two'));
      expect(
        provider.messages.where(
          (message) => message.sendState == ChatSendState.failed,
        ),
        hasLength(1),
      );
    },
  );

  test('equal timestamps use message id as deterministic order', () async {
    final repository = _FakeChatRepository();
    final provider = ChatProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.open(groupId: 'g1', currentUserId: 'alice');
    final timestamp = DateTime(2026);
    repository.stream.add(
      Success(<ChatMessage>[
        _serverMessageAt('c', timestamp),
        _serverMessageAt('a', timestamp),
        _serverMessageAt('b', timestamp),
      ]),
    );
    await pumpEventQueue();
    expect(
      provider.messages.map((message) => message.id),
      orderedEquals(<String>['a', 'b', 'c']),
    );
  });
}

ChatMessage _serverMessage(String id) => ChatMessage.fromMap(<String, dynamic>{
  'senderId': 'bob',
  'senderName': 'Bob',
  'senderAvatar': '',
  'senderRole': 'member',
  'type': 'text',
  'text': id,
  'createdAt': DateTime(2026, 1, id == 'two' ? 2 : 1),
  'recipientCount': 1,
  'deliveredCount': 1,
  'readCount': 0,
  'reactions': <String, int>{},
}, id: id);

ChatMessage _serverMessageAt(String id, DateTime createdAt) =>
    ChatMessage.fromMap(<String, dynamic>{
      'senderId': 'bob',
      'senderName': 'Bob',
      'senderAvatar': '',
      'senderRole': 'member',
      'type': 'text',
      'text': id,
      'createdAt': createdAt,
      'recipientCount': 1,
      'deliveredCount': 1,
      'readCount': 0,
      'reactions': <String, int>{},
    }, id: id);

final class _FakeChatRepository implements ChatRepository {
  final stream = StreamController<Result<List<ChatMessage>>>.broadcast();
  Completer<Result<ChatMessage>> sendCompleter =
      Completer<Result<ChatMessage>>();

  @override
  Stream<Result<List<ChatMessage>>> watchMessages(
    String groupId, {
    int limit = 40,
  }) => stream.stream;

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
  }) => sendCompleter.future;

  @override
  Future<Result<List<ChatMessage>>> getOlderMessages({
    required String groupId,
    required ChatMessage before,
    int limit = 40,
  }) async => const Success(<ChatMessage>[]);

  @override
  Future<Result<void>> addReaction({
    required String groupId,
    required String messageId,
    required String reaction,
  }) async => const Success(null);

  @override
  Future<Result<void>> deleteMessage({
    required String groupId,
    required String messageId,
  }) async => const Success(null);

  @override
  Future<Result<ChatMessage>> editMessage({
    required String groupId,
    required String messageId,
    required String text,
  }) async => Success(_serverMessage(messageId));

  @override
  Future<Result<void>> markAsRead({
    required String groupId,
    required List<String> messageIds,
  }) async => const Success(null);

  @override
  Future<Result<void>> markAsDelivered({
    required String groupId,
    required List<String> messageIds,
  }) async => const Success(null);

  @override
  Future<Result<void>> pinMessage({
    required String groupId,
    required String messageId,
    required bool pinned,
  }) async => const Success(null);

  @override
  Future<Result<void>> updateChatBackground({
    required String groupId,
    required String? backgroundUrl,
  }) async => const Success(null);

  @override
  Future<Result<ChatMediaUpload>> uploadMedia({
    required String groupId,
    required String mediaId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required void Function(double progress) onProgress,
  }) async => const FailureResult(NetworkError());
}
