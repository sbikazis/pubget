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
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });
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
      repository.completeNext(Success(_serverMessage(pending.id)));
      await operation;

      expect(provider.messages.single.sendState, ChatSendState.sent);
      expect(provider.messages.single.isOptimistic, isFalse);
    },
  );

  test('completion from an old chat cannot mutate the newly opened chat',
      () async {
    final repository = _FakePrivateChatRepository();
    final provider = PrivateChatProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.open(chatId: 'a', currentUserId: 'alice');
    final send = provider.sendText(
      chatId: 'a',
      senderId: 'alice',
      senderName: 'Alice',
      senderAvatar: '',
      text: 'old chat',
    );
    await provider.open(chatId: 'b', currentUserId: 'alice');
    repository.completeNext(Success(_serverMessage('old')));
    await send;
    expect(provider.chatId, 'b');
    expect(provider.messages, isEmpty);
  });

  test('direct callable success preserves optimistic createdAt', () async {
    final repository = _FakePrivateChatRepository();
    final provider = PrivateChatProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.open(chatId: 'c1', currentUserId: 'alice');
    final send = provider.sendText(
      chatId: 'c1',
      senderId: 'alice',
      senderName: 'Alice',
      senderAvatar: '',
      text: 'keep timestamp',
    );
    final optimisticCreatedAt = provider.messages.single.createdAt;
    final id = provider.messages.single.id;
    repository.completeNext(Success(_serverMessage(id)));
    await send;
    expect(provider.messages.single.createdAt, optimisticCreatedAt);
  });

  test('stale receipt completion cannot drain receipts into a new chat',
      () async {
    final repository = _FakePrivateChatRepository()..holdReceipts = true;
    final provider = PrivateChatProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.open(chatId: 'a', currentUserId: 'alice');
    repository.stream.add(Success(<ChatMessage>[_serverMessage('a-receipt')]));
    await pumpEventQueue();
    await provider.open(chatId: 'b', currentUserId: 'alice');
    repository.stream.add(Success(<ChatMessage>[_serverMessage('b-receipt')]));
    await pumpEventQueue();
    expect(repository.receiptChatIds, orderedEquals(<String>['a', 'b']));
    repository.completeNextReceipt();
    await pumpEventQueue();
    expect(repository.receiptChatIds, orderedEquals(<String>['a', 'b']));
    repository.completeNextReceipt();
  });

  test('a failed media upload remains manually retryable', () async {
    final repository = _FakePrivateChatRepository();
    repository.uploadResults.add(const FailureResult(NetworkError()));
    repository.uploadResults.add(
      const Success(
        ChatMediaUpload(
          mediaUrl: 'https://cdn.example/image.jpg',
          thumbnailUrl: null,
          mediaId: 'media-1',
          type: ChatMessageType.image,
        ),
      ),
    );
    final provider = PrivateChatProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.open(chatId: 'c1', currentUserId: 'alice');
    final first = provider.sendMedia(
      chatId: 'c1',
      senderId: 'alice',
      senderName: 'Alice',
      senderAvatar: '',
      bytes: Uint8List.fromList(<int>[1]),
      fileName: 'image.jpg',
      contentType: 'image/jpeg',
    );
    await first;
    final pending = provider.messages.single;
    expect(pending.sendState, ChatSendState.pending);
    final retry = provider.retry(pending);
    await pumpEventQueue();
    repository.completeNext(Success(_serverMessage(pending.id)));
    await retry;
    expect(provider.messages.single.sendState, ChatSendState.sent);
  });

  test('network failure stays pending; permanent failure can be deleted', () async {
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
    repository.completeNext(
      const FailureResult(NetworkError('chat_network')),
    );
    await operation;
    expect(provider.messages.single.sendState, ChatSendState.pending);

    final permanent = provider.sendText(
      chatId: 'c1',
      senderId: 'alice',
      senderName: 'Alice',
      senderAvatar: '',
      text: 'Remove me',
    );
    repository.completeNext(
      const FailureResult(ValidationError('chat_validation')),
    );
    await permanent;
    final failed = provider.messages.last;
    expect(failed.sendState, ChatSendState.failed);
    provider.removeFailed(failed.id);
    expect(
      provider.messages.any((message) => message.id == failed.id),
      isFalse,
    );
  });

  test(
    'stream merges incrementally and preserves pending local messages',
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
      repository.completeNext(
        const FailureResult(NetworkError('chat_network')),
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
          (message) => message.sendState == ChatSendState.pending,
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
  final pendingCompleters = <Completer<Result<ChatMessage>>>[];
  final pendingReceiptCompleters = <Completer<Result<void>>>[];
  final uploadResults = <Result<ChatMediaUpload>>[];
  final receiptChatIds = <String>[];
  bool holdReceipts = false;

  void completeNext(Result<ChatMessage> result) {
    final next = pendingCompleters.firstWhere((c) => !c.isCompleted);
    next.complete(result);
  }

  void completeNextReceipt() {
    final next = pendingReceiptCompleters.firstWhere((c) => !c.isCompleted);
    next.complete(const Success<void>(null));
  }

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
  }) {
    final completer = Completer<Result<ChatMessage>>();
    pendingCompleters.add(completer);
    return completer.future;
  }

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
  }) {
    receiptChatIds.add(chatId);
    if (!holdReceipts) return Future.value(const Success(null));
    final completer = Completer<Result<void>>();
    pendingReceiptCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<Result<void>> markAsDelivered({
    required String chatId,
    required List<String> messageIds,
  }) {
    receiptChatIds.add(chatId);
    if (!holdReceipts) return Future.value(const Success(null));
    final completer = Completer<Result<void>>();
    pendingReceiptCompleters.add(completer);
    return completer.future;
  }

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
  }) async => uploadResults.isEmpty
      ? const FailureResult(NetworkError())
      : uploadResults.removeAt(0);
}
