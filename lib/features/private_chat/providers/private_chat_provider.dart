import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/network/network_service.dart';
import '../../groups/models/chat_models.dart';
import '../../groups/services/chat_send_reliability.dart';
import '../../groups/services/pending_chat_outbox.dart';
import '../repositories/private_chat_repository.dart';

final class PrivateChatProvider extends ChangeNotifier {
  PrivateChatProvider({
    required PrivateChatRepository repository,
    PendingChatOutbox? outbox,
    NetworkService? network,
  }) : _repository = repository,
       _outbox = outbox ?? PendingChatOutbox(),
       _network = network {
    _network?.addListener(_onNetworkChanged);
  }

  final PrivateChatRepository _repository;
  final PendingChatOutbox _outbox;
  final NetworkService? _network;
  final List<ChatMessage> _messages = <ChatMessage>[];
  final Map<String, int> _messageIndex = <String, int>{};
  final Map<String, double> _uploadProgress = <String, double>{};
  final Map<String, _PendingMediaUpload> _pendingUploads =
      <String, _PendingMediaUpload>{};
  final Set<String> _deliveredMessageIds = <String>{};
  final Set<String> _readMessageIds = <String>{};
  final Map<String, int> _autoRetryAttempt = <String, int>{};
  final Map<String, Timer> _autoRetryTimers = <String, Timer>{};
  final Set<String> _autoRetryInFlight = <String>{};
  final Set<String> _pendingDeliveredIds = <String>{};
  final Set<String> _pendingReadIds = <String>{};
  StreamSubscription<Result<List<ChatMessage>>>? _subscription;
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  String? _chatId;
  String? _currentUserId;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _disposed = false;
  bool _pageActive = false;
  bool _receiptInFlight = false;
  Timer? _receiptRetryTimer;
  int _receiptRetryAttempt = 0;
  int _sessionGeneration = 0;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  Map<String, double> get uploadProgress => Map.unmodifiable(_uploadProgress);
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get hasMore => _hasMore;
  String? get chatId => _chatId;

  Future<void> open({
    required String chatId,
    required String currentUserId,
  }) async {
    if (_chatId == chatId && _currentUserId == currentUserId && _pageActive) {
      return;
    }
    final generation = ++_sessionGeneration;
    await _subscription?.cancel();
    if (_disposed || _sessionGeneration != generation) return;
    _cancelAllAutoRetries();
    _pendingDeliveredIds.clear();
    _pendingReadIds.clear();
    _receiptInFlight = false;
    _receiptRetryAttempt = 0;
    _chatId = chatId;
    _currentUserId = currentUserId;
    _pageActive = true;
    _messages.clear();
    _messageIndex.clear();
    _deliveredMessageIds.clear();
    _readMessageIds.clear();
    _hasMore = true;
    _loadingMore = false;
    _failure = null;
    _state = LoadingState.loading;
    notifyListeners();
    final subscription = _repository
        .watchMessages(chatId)
        .listen(
          (result) => _receive(result, chatId: chatId, generation: generation),
          onError: (Object error) {
            if (!_isCurrent(chatId, generation)) return;
            _failure = NetworkError(error.toString());
            _state = _messages.isEmpty
                ? LoadingState.offline
                : LoadingState.loaded;
            _safeNotify();
          },
        );
    _subscription = subscription;
    await _restoreOutbox(chatId, generation);
  }

  /// Detaches the live page session while retaining durable pending sends.
  Future<void> leaveChat() async {
    ++_sessionGeneration;
    _pageActive = false;
    _receiptRetryTimer?.cancel();
    _receiptRetryTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _cancelAllAutoRetries();
    _pendingDeliveredIds.clear();
    _pendingReadIds.clear();
    _receiptInFlight = false;
    _receiptRetryAttempt = 0;
  }

  Future<void> loadMore() async {
    final chatId = _chatId;
    final generation = _sessionGeneration;
    if (chatId == null ||
        !_hasMore ||
        _loadingMore ||
        _messages.isEmpty ||
        _state == LoadingState.loading) {
      return;
    }
    _loadingMore = true;
    _state = LoadingState.loadingMore;
    notifyListeners();
    final result = await _repository.getOlderMessages(
      chatId: chatId,
      before: _messages.first,
    );
    if (_disposed || !_isCurrent(chatId, generation)) return;
    result.fold(
      onSuccess: (older) {
        _merge(older);
        _hasMore = older.isNotEmpty;
        _state = _messages.isEmpty ? LoadingState.empty : LoadingState.loaded;
      },
      onFailure: (failure) {
        _failure = failure;
        _state = failure is NetworkError
            ? LoadingState.offline
            : LoadingState.error;
      },
    );
    _loadingMore = false;
    notifyListeners();
  }

  Future<void> sendText({
    required String chatId,
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String text,
    String? replyToMessageId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final generation = _sessionGeneration;
    if (!_isCurrent(chatId, generation)) return;
    final pending = ChatMessage.optimistic(
      id: _newId(),
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      senderRole: '',
      type: ChatMessageType.text,
      text: trimmed,
      replyToMessageId: replyToMessageId,
    );
    _upsert(pending);
    unawaited(_persistPending(chatId, pending));
    final result = await _repository.sendMessage(
      chatId: chatId,
      messageId: pending.id,
      type: ChatMessageType.text,
      text: trimmed,
      replyToMessageId: replyToMessageId,
    );
    _finishSend(pending.id, result, chatId: chatId, generation: generation);
  }

  Future<void> sendMedia({
    required String chatId,
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final mediaId = _newId();
    final generation = _sessionGeneration;
    if (!_isCurrent(chatId, generation)) return;
    final type = contentType.startsWith('video/')
        ? ChatMessageType.video
        : ChatMessageType.image;
    final pending = ChatMessage.optimistic(
      id: mediaId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      senderRole: '',
      type: type,
      text: null,
      mediaId: mediaId,
    );
    _pendingUploads[mediaId] = _PendingMediaUpload(
      chatId: chatId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      generation: generation,
    );
    _upsert(pending);
    await _performMediaUpload(mediaId, generation: generation);
  }

  Future<void> _performMediaUpload(
    String mediaId, {
    required int generation,
  }) async {
    final payload = _pendingUploads[mediaId];
    if (payload == null) return;
    if (!_isCurrent(payload.chatId, generation)) return;
    _uploadProgress[mediaId] = 0;
    notifyListeners();
    final upload = await _repository.uploadMedia(
      chatId: payload.chatId,
      mediaId: mediaId,
      bytes: payload.bytes,
      fileName: payload.fileName,
      contentType: payload.contentType,
      onProgress: (progress) {
        if (!_isCurrent(payload.chatId, generation)) return;
        _uploadProgress[mediaId] = progress;
        _safeNotify();
      },
    );
    _uploadProgress.remove(mediaId);
    if (_disposed || !_isCurrent(payload.chatId, generation)) return;
    upload.fold(
      onSuccess: (media) async {
        final pending = ChatMessage.optimistic(
          id: mediaId,
          senderId: payload.senderId,
          senderName: payload.senderName,
          senderAvatar: payload.senderAvatar,
          senderRole: '',
          type: media.type,
          text: null,
          mediaUrl: media.mediaUrl,
          thumbnailUrl: media.thumbnailUrl,
          mediaId: media.mediaId,
        );
        _upsert(pending);
        unawaited(_persistPending(payload.chatId, pending));
        final result = await _repository.sendMessage(
          chatId: payload.chatId,
          messageId: mediaId,
          type: media.type,
          mediaUrl: media.mediaUrl,
          thumbnailUrl: media.thumbnailUrl,
          mediaId: media.mediaId,
        );
        _finishSend(
          mediaId,
          result,
          chatId: payload.chatId,
          generation: generation,
        );
        if (result.isSuccess) _pendingUploads.remove(mediaId);
      },
      onFailure: (failure) {
        final index = _messages.indexWhere((item) => item.id == mediaId);
        if (index != -1) {
          if (isTransientChatFailure(failure)) {
            _messages[index] = _messages[index].copyWith(
              sendState: ChatSendState.pending,
              clearFailureMessage: true,
            );
            if ((_autoRetryAttempt[mediaId] ?? 0) <
                kChatSendMaxAggressiveRetries) {
              _scheduleAutoRetry(mediaId);
            } else {
              _messages[index] = _messages[index].copyWith(
                sendState: ChatSendState.failed,
                failureMessage: chatFailureCode(failure),
              );
            }
          } else {
            _messages[index] = _messages[index].copyWith(
              sendState: ChatSendState.failed,
              failureMessage: chatFailureCode(failure),
            );
          }
        }
        _failure = failure;
        _safeNotify();
      },
    );
    notifyListeners();
  }

  Future<void> retry(ChatMessage message) async {
    if (message.isDeleted) return;
    if (message.sendState != ChatSendState.failed &&
        message.sendState != ChatSendState.pending) {
      return;
    }
    final chatId = _chatId;
    final generation = _sessionGeneration;
    if (chatId == null || !_isCurrent(chatId, generation)) return;
    _autoRetryAttempt[message.id] = 0;
    if (_pendingUploads.containsKey(message.id) &&
        (message.mediaUrl == null || message.mediaUrl!.isEmpty)) {
      _upsert(
        message.copyWith(
          sendState: ChatSendState.pending,
          clearFailureMessage: true,
        ),
      );
      await _performMediaUpload(message.id, generation: generation);
      return;
    }
    _upsert(
      message.copyWith(
        sendState: ChatSendState.pending,
        clearFailureMessage: true,
      ),
    );
    unawaited(_persistPending(chatId, message));
    final result = await _repository.sendMessage(
      chatId: chatId,
      messageId: message.id,
      type: message.type,
      text: message.text,
      mediaUrl: message.mediaUrl,
      thumbnailUrl: message.thumbnailUrl,
      mediaId: message.mediaId,
      replyToMessageId: message.replyToMessageId,
    );
    _finishSend(message.id, result, chatId: chatId, generation: generation);
  }

  void removeFailed(String messageId) {
    final index = _messageIndex[messageId];
    if (index == null || _messages[index].sendState != ChatSendState.failed) {
      return;
    }
    _cancelAutoRetry(messageId);
    _messages.removeAt(index);
    _messageIndex.remove(messageId);
    _reindexFrom(index);
    _pendingUploads.remove(messageId);
    final chatId = _chatId;
    if (chatId != null) {
      unawaited(_outbox.remove(chatId, messageId));
    }
    notifyListeners();
  }

  Future<Result<void>> deleteMessage(String messageId) async {
    final chatId = _chatId;
    final generation = _sessionGeneration;
    if (chatId == null) return const FailureResult(UnknownError());
    final result = await _repository.deleteMessage(
      chatId: chatId,
      messageId: messageId,
    );
    if (result.isSuccess && _isCurrent(chatId, generation)) {
      _removeOrMarkDeleted(messageId);
    }
    return result;
  }

  Future<void> markAsRead(List<ChatMessage> visibleMessages) async {
    final chatId = _chatId;
    final uid = _currentUserId;
    if (!_pageActive || chatId == null || uid == null) return;
    _pendingReadIds.addAll(
      visibleMessages
          .where(
            (message) =>
                message.senderId != uid &&
                !message.isOptimistic &&
                !_readMessageIds.contains(message.id),
          )
          .map((message) => message.id)
          .toList(),
    );
    _drainReceipts();
  }

  Future<Result<void>> hideChat() async {
    final chatId = _chatId;
    if (chatId == null) return const FailureResult(UnknownError());
    return _repository.deleteChat(chatId);
  }

  void _receive(
    Result<List<ChatMessage>> result, {
    required String chatId,
    required int generation,
  }) {
    if (_disposed || !_isCurrent(chatId, generation)) return;
    result.fold(
      onSuccess: (incoming) {
        _merge(incoming);
        unawaited(_markDeliveredForSession(
          incoming,
          chatId: chatId,
          generation: generation,
        ));
        _state = _messages.isEmpty ? LoadingState.empty : LoadingState.loaded;
        _failure = null;
        _kickPendingRetries();
      },
      onFailure: (failure) {
        _failure = failure;
        _state = _messages.isEmpty
            ? (failure is NetworkError
                  ? LoadingState.offline
                  : LoadingState.error)
            : LoadingState.loaded;
      },
    );
    notifyListeners();
  }

  void _merge(Iterable<ChatMessage> incoming) {
    for (final message in incoming) {
      final index = _messageIndex[message.id];
      if (index == null) {
        _insertOrdered(message);
        continue;
      }
      final local = _messages[index];
      if (!message.isOptimistic) {
        if (local.sendState == ChatSendState.pending ||
            local.sendState == ChatSendState.failed ||
            local.isOptimistic) {
          _cancelAutoRetry(message.id);
          final chatId = _chatId;
          if (chatId != null) {
            unawaited(_outbox.remove(chatId, message.id));
          }
        }
        final reconciled = local.createdAt != null
            ? message.copyWith(
                createdAt: local.createdAt,
                sendState: ChatSendState.sent,
              )
            : message.copyWith(sendState: ChatSendState.sent);
        _replaceOrdered(index, reconciled);
        continue;
      }
      if (local.sendState != ChatSendState.failed) {
        _replaceOrdered(index, message);
      }
    }
  }

  void _upsert(ChatMessage message) {
    final index = _messageIndex[message.id];
    if (index == null) {
      _insertOrdered(message);
    } else {
      _replaceOrdered(index, message);
    }
    notifyListeners();
  }

  int _compareMessages(ChatMessage a, ChatMessage b) {
    final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final timestamp = aTime.compareTo(bTime);
    return timestamp != 0 ? timestamp : a.id.compareTo(b.id);
  }

  void _insertOrdered(ChatMessage message) {
    var low = 0;
    var high = _messages.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (_compareMessages(_messages[middle], message) <= 0) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    _messages.insert(low, message);
    _reindexFrom(low);
  }

  void _replaceOrdered(int index, ChatMessage message) {
    final current = _messages[index];
    if (_compareMessages(current, message) == 0) {
      _messages[index] = message;
      return;
    }
    _messages.removeAt(index);
    _messageIndex.remove(current.id);
    _reindexFrom(index);
    _insertOrdered(message);
  }

  void _reindexFrom(int start) {
    for (var index = start; index < _messages.length; index++) {
      _messageIndex[_messages[index].id] = index;
    }
  }

  void _finishSend(
    String id,
    Result<ChatMessage> result, {
    required String chatId,
    required int generation,
  }) {
    if (_disposed || !_isCurrent(chatId, generation)) return;
    result.fold(
      onSuccess: (message) {
        _cancelAutoRetry(id);
        unawaited(_outbox.remove(chatId, id));
        final index = _messageIndex[id];
        final localCreatedAt =
            index == null ? null : _messages[index].createdAt;
        _upsert(
          localCreatedAt == null
              ? message
              : message.copyWith(
                  createdAt: localCreatedAt,
                  sendState: ChatSendState.sent,
                ),
        );
      },
      onFailure: (failure) {
        final index = _messageIndex[id];
        if (index == null) return;
        final current = _messages[index];
        if (!current.isOptimistic && current.sendState == ChatSendState.sent) {
          _cancelAutoRetry(id);
          final chatId = _chatId;
          if (chatId != null) {
            unawaited(_outbox.remove(chatId, id));
          }
          return;
        }
        if (isTransientChatFailure(failure) &&
            (_autoRetryAttempt[id] ?? 0) < kChatSendMaxAggressiveRetries) {
          _messages[index] = current.copyWith(
            sendState: ChatSendState.pending,
            clearFailureMessage: true,
          );
          notifyListeners();
           unawaited(_persistPending(chatId, _messages[index]));
           _scheduleAutoRetry(id);
          return;
        }
        _cancelAutoRetry(id);
        _messages[index] = current.copyWith(
          sendState: ChatSendState.failed,
          failureMessage: chatFailureCode(failure),
        );
        _failure = failure;
        notifyListeners();
      },
    );
  }

  Future<void> _restoreOutbox(String chatId, int generation) async {
    try {
      final pending = await _outbox.load(chatId);
      if (_disposed || !_isCurrent(chatId, generation)) return;
      for (final message in pending) {
        if (_messageIndex.containsKey(message.id)) continue;
        _upsert(message.copyWith(sendState: ChatSendState.pending));
        _scheduleAutoRetry(message.id);
      }
    } catch (_) {
      // Outbox is best-effort; never block chat open.
    }
  }

  Future<void> _persistPending(String chatId, ChatMessage message) async {
    try {
      await _outbox.upsert(chatId, message);
    } catch (_) {}
  }

  void _onNetworkChanged() {
    if (_network?.isOnline == true) {
      _kickPendingRetries(forceImmediate: true);
    }
  }

  void _kickPendingRetries({bool forceImmediate = false}) {
    for (final message in _messages) {
      if (message.sendState != ChatSendState.pending || message.isDeleted) {
        continue;
      }
      if (forceImmediate) {
        if ((_autoRetryAttempt[message.id] ?? 0) >=
            kChatSendMaxAggressiveRetries) {
          continue;
        }
        final attempt = _autoRetryAttempt[message.id] ?? 0;
        _cancelAutoRetry(message.id);
        _autoRetryAttempt[message.id] = attempt + 1;
        final chatId = _chatId;
        if (chatId != null) {
          unawaited(_autoRetrySend(
            message.id,
            chatId: chatId,
            generation: _sessionGeneration,
          ));
        }
      } else if (!_autoRetryTimers.containsKey(message.id) &&
          !_autoRetryInFlight.contains(message.id)) {
        _scheduleAutoRetry(message.id);
      }
    }
  }

  void _scheduleAutoRetry(String id) {
    if (_disposed || (_autoRetryAttempt[id] ?? 0) >= kChatSendMaxAggressiveRetries) {
      return;
    }
    final generation = _sessionGeneration;
    final chatId = _chatId;
    if (chatId == null) return;
    _autoRetryTimers.remove(id)?.cancel();
    final attempt = _autoRetryAttempt[id] ?? 0;
    final delay = chatSendBackoffDelay(attempt);
    _autoRetryAttempt[id] = attempt + 1;
    _autoRetryTimers[id] = Timer(delay, () {
      _autoRetryTimers.remove(id);
      unawaited(_autoRetrySend(id, chatId: chatId, generation: generation));
    });
  }

  Future<void> _autoRetrySend(
    String id, {
    required String chatId,
    required int generation,
  }) async {
    if (_disposed ||
        !_isCurrent(chatId, generation) ||
        _autoRetryInFlight.contains(id)) {
      return;
    }
    final index = _messageIndex[id];
    if (index == null) return;
    final message = _messages[index];
    if (message.sendState != ChatSendState.pending || message.isDeleted) {
      return;
    }
    _autoRetryInFlight.add(id);
    try {
      if (_pendingUploads.containsKey(id) &&
          (message.mediaUrl == null || message.mediaUrl!.isEmpty)) {
        await _performMediaUpload(id, generation: generation);
        return;
      }
      final result = await _repository.sendMessage(
        chatId: chatId,
        messageId: message.id,
        type: message.type,
        text: message.text,
        mediaUrl: message.mediaUrl,
        thumbnailUrl: message.thumbnailUrl,
        mediaId: message.mediaId,
        replyToMessageId: message.replyToMessageId,
      );
      _finishSend(id, result, chatId: chatId, generation: generation);
    } finally {
      _autoRetryInFlight.remove(id);
    }
  }

  void _cancelAutoRetry(String id) {
    _autoRetryTimers.remove(id)?.cancel();
    _autoRetryAttempt.remove(id);
    _autoRetryInFlight.remove(id);
  }

  void _cancelAllAutoRetries() {
    for (final timer in _autoRetryTimers.values) {
      timer.cancel();
    }
    _autoRetryTimers.clear();
    _autoRetryAttempt.clear();
    _autoRetryInFlight.clear();
  }

  void _removeOrMarkDeleted(String messageId) {
    final index = _messageIndex[messageId];
    if (index != null) {
      _messages[index] = _messages[index].copyWith(
        sendState: ChatSendState.sent,
        deletedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_messages.length}';

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _markDeliveredForSession(
    List<ChatMessage> incoming, {
    required String? chatId,
    required int generation,
  }) async {
    if (!_pageActive || chatId == null || !_isCurrent(chatId, generation)) {
      return;
    }
    final uid = _currentUserId;
    if (uid == null) return;
    _pendingDeliveredIds.addAll(
      incoming
          .where(
            (message) =>
                message.senderId != uid &&
                !message.isOptimistic &&
                !_deliveredMessageIds.contains(message.id),
          )
          .map((message) => message.id)
          .toList(),
    );
    _drainReceipts(chatId: chatId, generation: generation);
  }

  void _drainReceipts({String? chatId, int? generation}) {
    final activeChatId = chatId ?? _chatId;
    final activeGeneration = generation ?? _sessionGeneration;
    if (!_pageActive ||
        _receiptInFlight ||
        activeChatId == null ||
        !_isCurrent(activeChatId, activeGeneration)) {
      return;
    }
    final receiptChatId = activeChatId;
    final readIds = _pendingReadIds
        .where((id) => !_readMessageIds.contains(id))
        .take(50)
        .toList(growable: false);
    final deliveredIds = _pendingDeliveredIds
        .where((id) => !_deliveredMessageIds.contains(id))
        .take(50)
        .toList(growable: false);
    if (readIds.isEmpty && deliveredIds.isEmpty) return;
    _receiptInFlight = true;
    unawaited(() async {
      final read = readIds.isEmpty
          ? const Success<void>(null)
          : await _repository.markAsRead(
              chatId: receiptChatId,
              messageIds: readIds,
            );
      if (!_isCurrent(receiptChatId, activeGeneration)) {
        return;
      }
      if (read.isSuccess) {
        _readMessageIds.addAll(readIds);
        _deliveredMessageIds.addAll(readIds);
        _pendingReadIds.removeAll(readIds);
        // mark-as-read also records delivery on the server; do not issue a
        // second delivery callable for the same batch.
        _pendingDeliveredIds.removeAll(readIds);
      }
      final delivered = deliveredIds.isEmpty
          ? const Success<void>(null)
          : await _repository.markAsDelivered(
              chatId: receiptChatId,
              messageIds: deliveredIds,
            );
      if (delivered.isSuccess) {
        _deliveredMessageIds.addAll(deliveredIds);
        _pendingDeliveredIds.removeAll(deliveredIds);
      }
      if (!_isCurrent(receiptChatId, activeGeneration)) {
        return;
      }
      if (!read.isSuccess || !delivered.isSuccess) {
        _failure = (!read.isSuccess
            ? read.failureOrNull
            : delivered.failureOrNull);
        if (_receiptRetryAttempt++ < 3 && _pageActive) {
          _receiptRetryTimer?.cancel();
          _receiptRetryTimer = Timer(
            chatSendBackoffDelay(_receiptRetryAttempt),
            () => _drainReceipts(
              chatId: receiptChatId,
              generation: activeGeneration,
            ),
          );
        }
        _safeNotify();
      } else {
        _receiptRetryAttempt = 0;
      }
      _receiptInFlight = false;
      if (_isCurrent(receiptChatId, activeGeneration)) {
        _drainReceipts(
          chatId: receiptChatId,
          generation: activeGeneration,
        );
      }
    }());
  }

  @override
  void dispose() {
    _disposed = true;
    _pageActive = false;
    _network?.removeListener(_onNetworkChanged);
    _cancelAllAutoRetries();
    _receiptRetryTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  bool _isCurrent(String chatId, int generation) =>
      !_disposed &&
      _pageActive &&
      _chatId == chatId &&
      _sessionGeneration == generation;
}

final class _PendingMediaUpload {
  const _PendingMediaUpload({
    required this.chatId,
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.generation,
  });

  final String chatId;
  final Uint8List bytes;
  final String fileName;
  final String contentType;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final int generation;
}
