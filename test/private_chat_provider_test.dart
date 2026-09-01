import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/private_chat/models/private_chat_models.dart';
import 'package:pubget/features/private_chat/providers/private_chat_list_provider.dart';
import 'package:pubget/features/private_chat/providers/private_chat_provider.dart';
import 'package:pubget/features/private_chat/repositories/private_chat_repository.dart';

void main() {
  test(
    'optimistic private message remains pending until server confirmation',
    () async {
      final repository = _FakePrivateChatRepository();
      final provider = PrivateChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(chatId: 'c1', currentUserId: 'alice');

      final operation = provider.sendText(
        chatId: 'c1',
        senderId: 'alice',
        senderName: 'Alice',
        senderAvatar: '',
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

  test('failed private send remains visible and can be retried or deleted', () async {
    final repository = _FakePrivateChatRepository();
    final provider = PrivateChatProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.open(chatId: 'c1', currentUserId: 'alice');

    final operation = provider.sendText(
      chatId: 'c1',
      senderId: 'alice',
      senderName: 'Alice',
      senderAvatar: '',
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
      chatId: 'c1',
      senderId: 'alice',
      senderName: 'Alice',
      senderAvatar: '',
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
      final repository = _FakePrivateChatRepository();
      final provider = PrivateChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(chatId: 'c1', currentUserId: 'alice');
      repository.stream.add(Success(<ChatMessage>[_serverMessage('one')]));
      await pumpEventQueue();

      final send = provider.sendText(
        chatId: 'c1',
        senderId: 'alice',
        senderName: 'Alice',
        senderAvatar: '',
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
    final repository = _FakePrivateChatRepository();
    final provider = PrivateChatProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.open(chatId: 'c1', currentUserId: 'alice');
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

  test('ChatMessage parses ISO createdAt from callable payloads', () {
    final message = ChatMessage.fromMap(<String, dynamic>{
      'senderId': 'alice',
      'senderName': 'Alice',
      'senderAvatar': '',
      'senderRole': '',
      'type': 'text',
      'text': 'Hello',
      'createdAt': '2026-09-01T08:00:00.000Z',
      'recipientCount': 1,
      'deliveredCount': 0,
      'readCount': 0,
      'reactions': <String, int>{},
    }, id: 'm1');
    expect(message.createdAt, DateTime.parse('2026-09-01T08:00:00.000Z'));
  });

  test('list unreadCount matches conversations unread for the current user', () async {
    final repository = _FakePrivateChatRepository();
    final list = PrivateChatListProvider(repository: repository);
    addTearDown(list.dispose);
    addTearDown(repository.chats.close);
    await list.open('alice');
    repository.chats.add(
      Success(<PrivateChatSummary>[
        PrivateChatSummary(
          id: '5:alice3:bob',
          participantIds: const <String>['alice', 'bob'],
          userA: 'alice',
          userB: 'bob',
          lastMessageAt: DateTime(2026, 2, 2),
          lastMessageText: 'Are you there?',
          lastMessageSenderId: 'bob',
          createdAt: DateTime(2026, 1, 1),
          participants: const <String, PrivateChatParticipant>{
            'alice': PrivateChatParticipant(displayName: 'Alice', avatarUrl: ''),
            'bob': PrivateChatParticipant(displayName: 'Bob', avatarUrl: ''),
          },
        ),
      ]),
    );
    await pumpEventQueue();
    expect(list.unreadCount, 1);
  });
}

ChatMessage _serverMessage(String id) => ChatMessage.fromMap(<String, dynamic>{
  'senderId': 'bob',
  'senderName': 'Bob',
  'senderAvatar': '',
  'senderRole': '',
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
      'senderRole': '',
      'type': 'text',
      'text': id,
      'createdAt': createdAt,
      'recipientCount': 1,
      'deliveredCount': 1,
      'readCount': 0,
      'reactions': <String, int>{},
    }, id: id);

final class _FakePrivateChatRepository implements PrivateChatRepository {
  final stream = StreamController<Result<List<ChatMessage>>>.broadcast();
  final chats = StreamController<Result<List<PrivateChatSummary>>>.broadcast();
  Completer<Result<ChatMessage>> sendCompleter =
      Completer<Result<ChatMessage>>();

  @override
  Future<Result<String>> startChat(String otherUserId) async =>
      const Success('c1');

  @override
  Stream<Result<List<PrivateChatSummary>>> watchChats({int limit = 20}) =>
      chats.stream;

  @override
  Future<Result<List<PrivateChatSummary>>> getOlderChats({
    required PrivateChatSummary before,
    int limit = 20,
  }) async => const Success(<PrivateChatSummary>[]);

  @override
  Stream<Result<List<ChatMessage>>> watchMessages(
    String chatId, {
    int limit = 40,
  }) => stream.stream;

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
  }) => sendCompleter.future;

  @override
  Future<Result<List<ChatMessage>>> getOlderMessages({
    required String chatId,
    required ChatMessage before,
    int limit = 40,
  }) async => const Success(<ChatMessage>[]);

  @override
  Future<Result<void>> deleteMessage({
    required String chatId,
    required String messageId,
  }) async => const Success(null);

  @override
  Future<Result<void>> markAsRead({
    required String chatId,
    required List<String> messageIds,
  }) async => const Success(null);

  @override
  Future<Result<void>> markAsDelivered({
    required String chatId,
    required List<String> messageIds,
  }) async => const Success(null);

  @override
  Future<Result<void>> deleteChat(String chatId) async => const Success(null);

  @override
  Future<Result<ChatMediaUpload>> uploadMedia({
    required String chatId,
    required String mediaId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required void Function(double progress) onProgress,
  }) async => const FailureResult(NetworkError());
}
