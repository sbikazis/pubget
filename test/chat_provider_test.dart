import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/groups/providers/chat_provider.dart';
import 'package:pubget/features/groups/repositories/chat_repository.dart';
import 'package:pubget/features/groups/services/chat_send_reliability.dart';
import 'package:pubget/features/groups/services/pending_chat_outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

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
      repository.completeNext(Success(_serverMessage(pending.id)));
      await operation;

      expect(provider.messages.single.sendState, ChatSendState.sent);
      expect(provider.messages.single.isOptimistic, isFalse);
    },
  );

  test(
    'send completion from group A cannot mutate newly opened group B',
    () async {
      final repository = _FakeChatRepository();
      final provider = ChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(groupId: 'group-a', currentUserId: 'alice');

      final send = provider.sendText(
        groupId: 'group-a',
        senderId: 'alice',
        senderName: 'Alice',
        senderAvatar: '',
        senderRole: 'member',
        text: 'old session',
      );
      final oldMessageId = provider.messages.single.id;
      await provider.open(groupId: 'group-b', currentUserId: 'alice');

      repository.completeNext(Success(_serverMessage(oldMessageId)));
      await send;
      await pumpEventQueue();

      expect(provider.groupId, 'group-b');
      expect(provider.messages, isEmpty);
    },
  );

  test('stale leave completion cannot detach a newly opened group', () async {
    final repository = _FakeChatRepository(
      cancelDelay: const Duration(milliseconds: 20),
    );
    final provider = ChatProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.open(groupId: 'group-a', currentUserId: 'alice');

    final leaving = provider.leaveGroup();
    await provider.open(groupId: 'group-b', currentUserId: 'alice');
    await leaving;

    expect(provider.groupId, 'group-b');
  });

  test(
    'aggressive retries are capped while manual retry remains possible',
    () async {
      final repository = _FakeChatRepository();
      final network = _TestNetworkService();
      final provider = ChatProvider(repository: repository, network: network);
      addTearDown(provider.dispose);
      addTearDown(network.dispose);
      await provider.open(groupId: 'g1', currentUserId: 'alice');

      final send = provider.sendText(
        groupId: 'g1',
        senderId: 'alice',
        senderName: 'Alice',
        senderAvatar: '',
        senderRole: 'member',
        text: 'retry me',
      );
      repository.completeNext(
        const FailureResult(NetworkError(ChatFailureCodes.network)),
      );
      await send;

      for (
        var attempt = 0;
        attempt < kChatSendMaxAggressiveRetries;
        attempt++
      ) {
        network.pulse();
        for (
          var tick = 0;
          tick < 20 &&
              repository.pendingCompleters.every(
                (completer) => completer.isCompleted,
              );
          tick++
        ) {
          await pumpEventQueue();
        }
        if (repository.pendingCompleters.every(
          (completer) => completer.isCompleted,
        )) {
          break;
        }
        repository.completeNext(
          const FailureResult(NetworkError(ChatFailureCodes.network)),
        );
        await pumpEventQueue();
      }

      expect(repository.sendCalls, kChatSendMaxAggressiveRetries);
      expect(provider.messages.single.sendState, ChatSendState.failed);

      final manual = provider.retry(provider.messages.single);
      expect(
        repository.pendingCompleters.where((c) => !c.isCompleted),
        isNotEmpty,
      );
      repository.completeNext(
        Success(_serverMessage(provider.messages.single.id)),
      );
      await manual;
      expect(provider.messages.single.sendState, ChatSendState.sent);
    },
  );

  test('transient network failure stays pending and auto-retries', () async {
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
    repository.completeNext(
      const FailureResult(NetworkError(ChatFailureCodes.network)),
    );
    await operation;

    final pending = provider.messages.single;
    expect(pending.sendState, ChatSendState.pending);
    expect(pending.failureMessage, isNull);

    // First backoff is ~800ms (+jitter).
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    await pumpEventQueue();
    expect(repository.sendCalls, greaterThanOrEqualTo(2));
    repository.completeNext(Success(_serverMessage(pending.id)));
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(provider.messages.single.sendState, ChatSendState.sent);
  });

  test('permanent permission failure shows failed state', () async {
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
      text: 'blocked',
    );
    repository.completeNext(
      const FailureResult(PermissionError(ChatFailureCodes.permission)),
    );
    await operation;

    expect(provider.messages.single.sendState, ChatSendState.failed);
    expect(
      provider.messages.single.failureMessage,
      ChatFailureCodes.permission,
    );
  });

  test(
    'stream heals false-negative after callable failure (same messageId)',
    () async {
      final repository = _FakeChatRepository();
      final provider = ChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(groupId: 'g1', currentUserId: 'alice');

      final send = provider.sendText(
        groupId: 'g1',
        senderId: 'alice',
        senderName: 'Alice',
        senderAvatar: '',
        senderRole: 'member',
        text: 'race',
      );
      final pendingId = provider.messages.single.id;

      // Listener confirms write before callable returns.
      repository.stream.add(Success(<ChatMessage>[_serverMessage(pendingId)]));
      await pumpEventQueue();
      expect(provider.messages.single.sendState, ChatSendState.sent);

      repository.completeNext(
        const FailureResult(NetworkError(ChatFailureCodes.network)),
      );
      await send;
      await pumpEventQueue();

      expect(provider.messages, hasLength(1));
      expect(provider.messages.single.id, pendingId);
      expect(provider.messages.single.sendState, ChatSendState.sent);
    },
  );

  test(
    'stream merges other messages without dropping pending locals',
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
      repository.completeNext(
        const FailureResult(NetworkError(ChatFailureCodes.network)),
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

  test('rapid multi-send keeps unique ids and independent states', () async {
    final repository = _FakeChatRepository();
    final provider = ChatProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.open(groupId: 'g1', currentUserId: 'alice');

    final ops = <Future<void>>[];
    for (var i = 0; i < 5; i++) {
      ops.add(
        provider.sendText(
          groupId: 'g1',
          senderId: 'alice',
          senderName: 'Alice',
          senderAvatar: '',
          senderRole: 'member',
          text: 'm$i',
        ),
      );
    }
    await pumpEventQueue();
    expect(provider.messages, hasLength(5));
    expect(repository.sendCalls, 5);

    for (final message in provider.messages) {
      repository.completeNext(
        Success(_serverMessage(message.id, text: message.text ?? '')),
      );
    }
    await Future.wait(ops);
    expect(provider.messages.map((m) => m.id).toSet(), hasLength(5));
    expect(
      provider.messages.every((m) => m.sendState == ChatSendState.sent),
      isTrue,
    );
  });

  test('outbox restores pending message after provider reopen', () async {
    final repository = _FakeChatRepository();
    final outbox = PendingChatOutbox();
    final first = ChatProvider(repository: repository, outbox: outbox);
    await first.open(groupId: 'g1', currentUserId: 'alice');
    final send = first.sendText(
      groupId: 'g1',
      senderId: 'alice',
      senderName: 'Alice',
      senderAvatar: '',
      senderRole: 'member',
      text: 'persist me',
    );
    repository.completeNext(
      const FailureResult(NetworkError(ChatFailureCodes.network)),
    );
    await send;
    await pumpEventQueue();
    // Allow outbox upsert to flush.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final pendingId = first.messages.single.id;
    first.dispose();

    final second = ChatProvider(repository: repository, outbox: outbox);
    addTearDown(second.dispose);
    await second.open(groupId: 'g1', currentUserId: 'alice');
    expect(second.messages.any((m) => m.id == pendingId), isTrue);
    expect(
      second.messages.singleWhere((m) => m.id == pendingId).sendState,
      ChatSendState.pending,
    );
  });

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

  test('reply target is attached to the next text send', () async {
    final repository = _FakeChatRepository();
    final provider = ChatProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.open(groupId: 'g1', currentUserId: 'alice');
    repository.stream.add(Success(<ChatMessage>[_serverMessage('target')]));
    await pumpEventQueue();
    provider.setReplyTarget(provider.messages.single);

    final send = provider.sendText(
      groupId: 'g1',
      senderId: 'alice',
      senderName: 'Alice',
      senderAvatar: '',
      senderRole: 'member',
      text: 'reply',
    );
    final pending = provider.messages.last;
    expect(pending.replyToMessageId, 'target');
    repository.completeNext(Success(_serverMessage(pending.id)));
    await send;
  });

  test('manual retry still works for permanent failures', () async {
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
    repository.completeNext(
      const FailureResult(ValidationError(ChatFailureCodes.validation)),
    );
    await operation;
    final failed = provider.messages.single;
    expect(failed.sendState, ChatSendState.failed);

    final retry = provider.retry(failed);
    repository.completeNext(Success(_serverMessage(failed.id)));
    await retry;
    expect(provider.messages.single.sendState, ChatSendState.sent);
  });

  test(
    'media upload progress ticks do not notify ChatProvider listeners',
    () async {
      final repository = _ProgressiveUploadRepository();
      final provider = ChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(groupId: 'g1', currentUserId: 'alice');

      var notifications = 0;
      provider.addListener(() => notifications++);

      final sendFuture = provider.sendMedia(
        groupId: 'g1',
        senderId: 'alice',
        senderName: 'Alice',
        senderAvatar: '',
        senderRole: 'member',
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
        fileName: 'shot.jpg',
        contentType: 'image/jpeg',
      );

      expect(notifications, 1, reason: 'only optimistic insert notifies');
      final revisionAfterInsert = provider.contentRevision;
      final messageId = provider.messages.single.id;
      expect(provider.localPreviewBytes(messageId), isNotNull);
      expect(
        provider.uploadUiListenable(messageId)!.value.phase,
        MediaUploadPhase.uploading,
      );

      repository.emitProgress(0.2);
      repository.emitProgress(0.55);
      repository.emitProgress(0.9);
      expect(
        notifications,
        1,
        reason: 'progress must not call notifyListeners',
      );
      expect(provider.contentRevision, revisionAfterInsert);
      expect(
        provider.uploadUiListenable(messageId)!.value.progress,
        closeTo(0.9, 0.001),
      );

      repository.completeBytesUploaded();
      expect(
        provider.uploadUiListenable(messageId)!.value.phase,
        MediaUploadPhase.processing,
      );
      expect(notifications, 1);

      repository.completeUpload(
        ChatMediaUpload(
          mediaUrl: 'groups/g1/media/${messageId}_medium.jpg',
          thumbnailUrl: 'groups/g1/media/${messageId}_thumb.jpg',
          mediaId: messageId,
          type: ChatMessageType.image,
        ),
      );
      // fold(onSuccess: async ...) is fire-and-forget; wait for sendMessage.
      await Future<void>.delayed(Duration.zero);
      for (var i = 0; i < 20 && repository.pendingCompleters.isEmpty; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(repository.pendingCompleters, isNotEmpty);
      repository.completeNext(
        Success(
          ChatMessage(
            id: messageId,
            senderId: 'alice',
            senderName: 'Alice',
            senderAvatar: '',
            senderRole: 'member',
            type: ChatMessageType.image,
            text: null,
            mediaUrl: 'groups/g1/media/${messageId}_medium.jpg',
            thumbnailUrl: 'groups/g1/media/${messageId}_thumb.jpg',
            mediaId: messageId,
            replyToMessageId: null,
            createdAt: DateTime(2026, 1, 1),
            editedAt: null,
            deletedAt: null,
            pinnedAt: null,
            reactions: const <String, int>{},
            recipientCount: 1,
            deliveredCount: 0,
            readCount: 0,
            isOptimistic: false,
            sendState: ChatSendState.sent,
          ),
        ),
      );
      await sendFuture;

      expect(notifications, greaterThan(1));
      expect(provider.uploadUiListenable(messageId), isNull);
    },
  );
}

ChatMessage _serverMessage(String id, {String text = 'Hello'}) {
  return ChatMessage(
    id: id,
    senderId: 'alice',
    senderName: 'Alice',
    senderAvatar: '',
    senderRole: 'member',
    type: ChatMessageType.text,
    text: text,
    mediaUrl: null,
    thumbnailUrl: null,
    mediaId: null,
    replyToMessageId: null,
    createdAt: DateTime(2026, 1, 1),
    editedAt: null,
    deletedAt: null,
    pinnedAt: null,
    reactions: const <String, int>{},
    recipientCount: 1,
    deliveredCount: 0,
    readCount: 0,
    isOptimistic: false,
    sendState: ChatSendState.sent,
  );
}

ChatMessage _serverMessageAt(String id, DateTime createdAt) {
  return ChatMessage(
    id: id,
    senderId: 'alice',
    senderName: 'Alice',
    senderAvatar: '',
    senderRole: 'member',
    type: ChatMessageType.text,
    text: id,
    mediaUrl: null,
    thumbnailUrl: null,
    mediaId: null,
    replyToMessageId: null,
    createdAt: createdAt,
    editedAt: null,
    deletedAt: null,
    pinnedAt: null,
    reactions: const <String, int>{},
    recipientCount: 1,
    deliveredCount: 0,
    readCount: 0,
    isOptimistic: false,
    sendState: ChatSendState.sent,
  );
}

final class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({this.cancelDelay = Duration.zero}) {
    stream = StreamController<Result<List<ChatMessage>>>.broadcast(
      onCancel: () => Future<void>.delayed(cancelDelay),
    );
  }

  final Duration cancelDelay;
  late final StreamController<Result<List<ChatMessage>>> stream;
  final pendingCompleters = <Completer<Result<ChatMessage>>>[];
  var sendCalls = 0;

  void completeNext(Result<ChatMessage> result) {
    final next = pendingCompleters.firstWhere((c) => !c.isCompleted);
    next.complete(result);
  }

  @override
  Stream<Result<List<ChatMessage>>> watchMessages(
    String groupId, {
    int limit = 40,
  }) => stream.stream;

  @override
  Future<Result<List<ChatMessage>>> getOlderMessages({
    required String groupId,
    required ChatMessage before,
    int limit = 40,
  }) async => const Success(<ChatMessage>[]);

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
  }) async {
    sendCalls += 1;
    final completer = Completer<Result<ChatMessage>>();
    pendingCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<Result<ChatMessage>> editMessage({
    required String groupId,
    required String messageId,
    required String text,
  }) async => Success(_serverMessage(messageId, text: text));

  @override
  Future<Result<void>> deleteMessage({
    required String groupId,
    required String messageId,
  }) async => const Success(null);

  @override
  Future<Result<void>> pinMessage({
    required String groupId,
    required String messageId,
    required bool pinned,
  }) async => const Success(null);

  @override
  Future<Result<void>> addReaction({
    required String groupId,
    required String messageId,
    required String reaction,
  }) async => const Success(null);

  @override
  Future<Result<ChatMessage>> forwardMessage({
    required String sourceGroupId,
    required String messageId,
    String? destinationGroupId,
    String? destinationChatId,
  }) async => Success(_serverMessage(messageId));

  @override
  Future<Result<void>> reportMessage({
    required String groupId,
    required String messageId,
    required String reason,
    String details = '',
  }) async => const Success(null);

  @override
  Future<Result<void>> markAsDelivered({
    required String groupId,
    required List<String> messageIds,
  }) async => const Success(null);

  @override
  Future<Result<void>> markAsRead({
    required String groupId,
    required List<String> messageIds,
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
    void Function()? onBytesUploaded,
  }) async => const FailureResult(NetworkError());
}

/// Lets tests drive upload progress without completing until asked.
final class _ProgressiveUploadRepository extends _FakeChatRepository {
  void Function(double progress)? _onProgress;
  void Function()? _onBytesUploaded;
  Completer<Result<ChatMediaUpload>>? _uploadCompleter;

  void emitProgress(double value) => _onProgress?.call(value);

  void completeBytesUploaded() => _onBytesUploaded?.call();

  void completeUpload(ChatMediaUpload media) {
    final completer = _uploadCompleter;
    if (completer == null || completer.isCompleted) return;
    completer.complete(Success(media));
  }

  @override
  Future<Result<ChatMediaUpload>> uploadMedia({
    required String groupId,
    required String mediaId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required void Function(double progress) onProgress,
    void Function()? onBytesUploaded,
  }) {
    _onProgress = onProgress;
    _onBytesUploaded = onBytesUploaded;
    final completer = Completer<Result<ChatMediaUpload>>();
    _uploadCompleter = completer;
    onProgress(0);
    return completer.future;
  }
}

final class _TestNetworkService extends NetworkService {
  _TestNetworkService() : super(probe: () async => true);

  @override
  bool get isOnline => true;

  void pulse() => notifyListeners();
}
