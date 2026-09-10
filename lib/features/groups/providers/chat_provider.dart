import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/network/network_service.dart';
import '../models/chat_models.dart';
import '../repositories/chat_repository.dart';
import '../services/chat_send_reliability.dart';
import '../services/pending_chat_outbox.dart';

final class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required ChatRepository repository,
    PendingChatOutbox? outbox,
    NetworkService? network,
  }) : _repository = repository,
       _outbox = outbox ?? PendingChatOutbox(),
       _network = network {
    _network?.addListener(_onNetworkChanged);
  }

  final ChatRepository _repository;
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
  StreamSubscription<Result<List<ChatMessage>>>? _subscription;
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  String? _groupId;
  String? _currentUserId;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _disposed = false;
  bool _readInFlight = false;
  ChatMessage? _replyTarget;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  Map<String, double> get uploadProgress => Map.unmodifiable(_uploadProgress);
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get hasMore => _hasMore;
  String? get groupId => _groupId;
  ChatMessage? get replyTarget => _replyTarget;

  void setReplyTarget(ChatMessage? message) {
    final next = message == null || message.isDeleted ? null : message;
    if (_replyTarget?.id == next?.id) return;
    _replyTarget = next;
    notifyListeners();
  }

  void clearReplyTarget() => setReplyTarget(null);

  ChatMessage? messageById(String? id) {
    if (id == null) return null;
    final index = _messageIndex[id];
    if (index == null) return null;
    return _messages[index];
  }

  Future<void> open({
    required String groupId,
    required String currentUserId,
  }) async {
    if (_groupId == groupId && _currentUserId == currentUserId) return;
    await _subscription?.cancel();
    _cancelAllAutoRetries();
    _groupId = groupId;
    _currentUserId = currentUserId;
    _messages.clear();
    _messageIndex.clear();
    _deliveredMessageIds.clear();
    _readMessageIds.clear();
    _hasMore = true;
    _failure = null;
    _state = LoadingState.loading;
    notifyListeners();
    _subscription = _repository
        .watchMessages(groupId)
        .listen(
          _receive,
          onError: (Object error) {
            _failure = NetworkError(error.toString());
            _state = _messages.isEmpty
                ? LoadingState.offline
                : LoadingState.loaded;
            _safeNotify();
          },
        );
    await _restoreOutbox(groupId);
  }

  Future<void> loadMore() async {
    final groupId = _groupId;
    if (groupId == null ||
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
      groupId: groupId,
      before: _messages.first,
    );
    if (_disposed) return;
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
    required String groupId,
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String senderRole,
    required String text,
    String? replyToMessageId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final replyId = replyToMessageId ?? _replyTarget?.id;
    final replyPreview = _previewFor(_replyTarget);
    final pending = ChatMessage.optimistic(
      id: _newId(),
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      senderRole: senderRole,
      type: ChatMessageType.text,
      text: trimmed,
      replyToMessageId: replyId,
      replyPreview: replyPreview,
    );
    // Drop reply chrome in the same notify as the optimistic bubble.
    _replyTarget = null;
    _upsert(pending);
    unawaited(_persistPending(pending));
    final result = await _repository.sendMessage(
      groupId: groupId,
      messageId: pending.id,
      type: ChatMessageType.text,
      text: trimmed,
      replyToMessageId: replyId,
    );
    _finishSend(pending.id, result);
  }

  Future<void> sendSticker({
    required String groupId,
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String senderRole,
    required String stickerKey,
    String? replyToMessageId,
  }) async {
    final replyId = replyToMessageId ?? _replyTarget?.id;
    final replyPreview = _previewFor(_replyTarget);
    final pending = ChatMessage.optimistic(
      id: _newId(),
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      senderRole: senderRole,
      type: ChatMessageType.sticker,
      text: null,
      stickerKey: stickerKey,
      stickerCreatorId: 'pubget',
      stickerCreatorName: 'Pubget',
      replyToMessageId: replyId,
      replyPreview: replyPreview,
    );
    _replyTarget = null;
    _upsert(pending);
    unawaited(_persistPending(pending));
    final result = await _repository.sendMessage(
      groupId: groupId,
      messageId: pending.id,
      type: ChatMessageType.sticker,
      stickerKey: stickerKey,
      stickerCreatorId: 'pubget',
      stickerCreatorName: 'Pubget',
      replyToMessageId: replyId,
    );
    _finishSend(pending.id, result);
  }

  Future<void> sendCustomSticker({
    required String groupId,
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String senderRole,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String stickerCreatorId,
    required String stickerCreatorName,
  }) async {
    final mediaId = _newId();
    final pending = ChatMessage.optimistic(
      id: mediaId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      senderRole: senderRole,
      type: ChatMessageType.sticker,
      text: null,
      mediaId: mediaId,
      stickerCreatorId: stickerCreatorId,
      stickerCreatorName: stickerCreatorName,
      replyToMessageId: _replyTarget?.id,
      replyPreview: _previewFor(_replyTarget),
    );
    _pendingUploads[mediaId] = _PendingMediaUpload(
      groupId: groupId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      senderRole: senderRole,
      forceType: ChatMessageType.sticker,
      stickerCreatorId: stickerCreatorId,
      stickerCreatorName: stickerCreatorName,
    );
    _upsert(pending);
    await _performMediaUpload(mediaId);
  }

  Future<void> sendMedia({
    required String groupId,
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String senderRole,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final mediaId = _newId();
    final type = chatMediaTypeFor(contentType: contentType, fileName: fileName);
    final pending = ChatMessage.optimistic(
      id: mediaId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      senderRole: senderRole,
      type: type,
      text: null,
      mediaId: mediaId,
      replyToMessageId: _replyTarget?.id,
      replyPreview: _previewFor(_replyTarget),
    );
    _pendingUploads[mediaId] = _PendingMediaUpload(
      groupId: groupId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      senderRole: senderRole,
    );
    _upsert(pending);
    await _performMediaUpload(mediaId);
  }

  Future<void> _performMediaUpload(String mediaId) async {
    final payload = _pendingUploads[mediaId];
    if (payload == null) return;
    _uploadProgress[mediaId] = 0;
    notifyListeners();
    final upload = await _repository.uploadMedia(
      groupId: payload.groupId,
      mediaId: mediaId,
      bytes: payload.bytes,
      fileName: payload.fileName,
      contentType: payload.contentType,
      onProgress: (progress) {
        _uploadProgress[mediaId] = progress;
        _safeNotify();
      },
    );
    _uploadProgress.remove(mediaId);
    if (_disposed) return;
    upload.fold(
      onSuccess: (media) async {
        final type = payload.forceType ?? media.type;
        final pending = ChatMessage.optimistic(
          id: mediaId,
          senderId: payload.senderId,
          senderName: payload.senderName,
          senderAvatar: payload.senderAvatar,
          senderRole: payload.senderRole,
          type: type,
          text: null,
          mediaUrl: media.mediaUrl,
          thumbnailUrl: media.thumbnailUrl,
          mediaId: media.mediaId,
          stickerCreatorId: payload.stickerCreatorId,
          stickerCreatorName: payload.stickerCreatorName,
          replyToMessageId: _replyTarget?.id,
          replyPreview: _previewFor(_replyTarget),
        );
        _upsert(pending);
        unawaited(_persistPending(pending));
        final result = await _repository.sendMessage(
          groupId: payload.groupId,
          messageId: mediaId,
          type: type,
          mediaUrl: media.mediaUrl,
          thumbnailUrl: media.thumbnailUrl,
          mediaId: media.mediaId,
          replyToMessageId: pending.replyToMessageId,
          stickerCreatorId: payload.stickerCreatorId,
          stickerCreatorName: payload.stickerCreatorName,
        );
        if (result.isSuccess) clearReplyTarget();
        _finishSend(mediaId, result);
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
            _scheduleAutoRetry(mediaId);
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
    _autoRetryAttempt[message.id] = 0;
    if (_pendingUploads.containsKey(message.id) &&
        (message.mediaUrl == null || message.mediaUrl!.isEmpty)) {
      _upsert(message.copyWith(
        sendState: ChatSendState.pending,
        clearFailureMessage: true,
      ));
      await _performMediaUpload(message.id);
      return;
    }
    _upsert(message.copyWith(
      sendState: ChatSendState.pending,
      clearFailureMessage: true,
    ));
    unawaited(_persistPending(message));
    final result = await _repository.sendMessage(
      groupId: _groupId ?? '',
      messageId: message.id,
      type: message.type,
      text: message.text,
      mediaUrl: message.mediaUrl,
      thumbnailUrl: message.thumbnailUrl,
      mediaId: message.mediaId,
      replyToMessageId: message.replyToMessageId,
      stickerKey: message.stickerKey,
      stickerCreatorId: message.stickerCreatorId,
      stickerCreatorName: message.stickerCreatorName,
    );
    _finishSend(message.id, result);
  }

  Future<Result<ChatMessage>> forwardMessage({
    required String messageId,
    String? destinationGroupId,
    String? destinationChatId,
  }) async {
    final groupId = _groupId;
    if (groupId == null) {
      return const FailureResult(UnknownError());
    }
    return _repository.forwardMessage(
      sourceGroupId: groupId,
      messageId: messageId,
      destinationGroupId: destinationGroupId,
      destinationChatId: destinationChatId,
    );
  }

  Future<Result<void>> reportMessage({
    required String messageId,
    required String reason,
    String details = '',
  }) async {
    final groupId = _groupId;
    if (groupId == null) {
      return const FailureResult(UnknownError());
    }
    return _repository.reportMessage(
      groupId: groupId,
      messageId: messageId,
      reason: reason,
      details: details,
    );
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
    final groupId = _groupId;
    if (groupId != null) {
      unawaited(_outbox.remove(groupId, messageId));
    }
    notifyListeners();
  }

  Future<Result<void>> deleteMessage(String messageId) async {
    final groupId = _groupId;
    if (groupId == null) return const FailureResult(UnknownError());
    final result = await _repository.deleteMessage(
      groupId: groupId,
      messageId: messageId,
    );
    if (result.isSuccess) _removeOrMarkDeleted(messageId);
    return result;
  }

  Future<Result<ChatMessage>> editMessage({
    required String messageId,
    required String text,
  }) async {
    final groupId = _groupId;
    if (groupId == null) {
      return const FailureResult(UnknownError());
    }
    final result = await _repository.editMessage(
      groupId: groupId,
      messageId: messageId,
      text: text,
    );
    result.fold(onSuccess: _upsert, onFailure: (_) {});
    return result;
  }

  Future<Result<void>> pinMessage(String messageId, bool pinned) {
    final groupId = _groupId;
    if (groupId == null) {
      return Future.value(const FailureResult(UnknownError()));
    }
    return _repository.pinMessage(
      groupId: groupId,
      messageId: messageId,
      pinned: pinned,
    );
  }

  Future<Result<void>> addReaction(String messageId, String reaction) {
    final groupId = _groupId;
    if (groupId == null) {
      return Future.value(const FailureResult(UnknownError()));
    }
    return _repository.addReaction(
      groupId: groupId,
      messageId: messageId,
      reaction: reaction,
    );
  }

  Future<void> markAsRead(List<ChatMessage> visibleMessages) async {
    final groupId = _groupId;
    final uid = _currentUserId;
    if (groupId == null || uid == null || _readInFlight) return;
    final ids = visibleMessages
        .where(
          (message) =>
              message.senderId != uid &&
              !message.isOptimistic &&
              !_readMessageIds.contains(message.id),
        )
        .map((message) => message.id)
        .take(50)
        .toList(growable: false);
    if (ids.isEmpty) return;
    _readInFlight = true;
    final result = await _repository.markAsRead(
      groupId: groupId,
      messageIds: ids,
    );
    _readInFlight = false;
    if (result.isSuccess) {
      _readMessageIds.addAll(ids);
      _deliveredMessageIds.addAll(ids);
    } else {
      _failure = result.failureOrNull;
      _safeNotify();
    }
  }

  Future<Result<void>> updateBackground(String? backgroundUrl) {
    final groupId = _groupId;
    if (groupId == null) {
      return Future.value(const FailureResult(UnknownError()));
    }
    return _repository.updateChatBackground(
      groupId: groupId,
      backgroundUrl: backgroundUrl,
    );
  }

  void _receive(Result<List<ChatMessage>> result) {
    if (_disposed) return;
    result.fold(
      onSuccess: (incoming) {
        _merge(incoming);
        unawaited(_markDelivered(incoming));
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
      // Server documents always reconcile by messageId (heal false failures).
      if (!message.isOptimistic) {
        if (local.sendState == ChatSendState.pending ||
            local.sendState == ChatSendState.failed ||
            local.isOptimistic) {
          _cancelAutoRetry(message.id);
          final groupId = _groupId;
          if (groupId != null) {
            unawaited(_outbox.remove(groupId, message.id));
          }
        }
        // Keep local createdAt so serverTimestamp reconcile does not reshuffle
        // the bubble and yank the scroll position.
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

  void _finishSend(String id, Result<ChatMessage> result) {
    if (_disposed) return;
    result.fold(
      onSuccess: (message) {
        _cancelAutoRetry(id);
        final groupId = _groupId;
        if (groupId != null) {
          unawaited(_outbox.remove(groupId, id));
        }
        final index = _messageIndex[id];
        final local = index != null ? _messages[index] : null;
        final reconciled = local?.createdAt != null
            ? message.copyWith(
                createdAt: local!.createdAt,
                sendState: ChatSendState.sent,
              )
            : message.copyWith(sendState: ChatSendState.sent);
        _upsert(reconciled);
      },
      onFailure: (failure) {
        final index = _messageIndex[id];
        if (index == null) return;
        final current = _messages[index];
        // Stream already confirmed this messageId — ignore transport false-negatives.
        if (!current.isOptimistic && current.sendState == ChatSendState.sent) {
          _cancelAutoRetry(id);
          final groupId = _groupId;
          if (groupId != null) {
            unawaited(_outbox.remove(groupId, id));
          }
          return;
        }
        if (isTransientChatFailure(failure)) {
          _messages[index] = current.copyWith(
            sendState: ChatSendState.pending,
            clearFailureMessage: true,
          );
          notifyListeners();
          unawaited(_persistPending(_messages[index]));
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

  Future<void> _restoreOutbox(String groupId) async {
    try {
      final pending = await _outbox.load(groupId);
      if (_disposed || _groupId != groupId) return;
      for (final message in pending) {
        if (_messageIndex.containsKey(message.id)) continue;
        _upsert(message.copyWith(sendState: ChatSendState.pending));
        _scheduleAutoRetry(message.id);
      }
    } catch (_) {
      // Outbox is best-effort; never block chat open.
    }
  }

  Future<void> _persistPending(ChatMessage message) async {
    try {
      final groupId = _groupId;
      if (groupId == null) return;
      await _outbox.upsert(groupId, message);
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
        _autoRetryAttempt[message.id] = 0;
        _cancelAutoRetry(message.id);
        unawaited(_autoRetrySend(message.id));
      } else if (!_autoRetryTimers.containsKey(message.id) &&
          !_autoRetryInFlight.contains(message.id)) {
        _scheduleAutoRetry(message.id);
      }
    }
  }

  void _scheduleAutoRetry(String id) {
    if (_disposed) return;
    _autoRetryTimers.remove(id)?.cancel();
    final attempt = _autoRetryAttempt[id] ?? 0;
    final delay = chatSendBackoffDelay(attempt);
    _autoRetryAttempt[id] = attempt + 1;
    _autoRetryTimers[id] = Timer(delay, () {
      _autoRetryTimers.remove(id);
      unawaited(_autoRetrySend(id));
    });
  }

  Future<void> _autoRetrySend(String id) async {
    if (_disposed || _autoRetryInFlight.contains(id)) return;
    final index = _messageIndex[id];
    if (index == null) return;
    final message = _messages[index];
    if (message.sendState != ChatSendState.pending || message.isDeleted) {
      return;
    }
    if (!message.isOptimistic && message.sendState == ChatSendState.sent) {
      return;
    }
    _autoRetryInFlight.add(id);
    try {
      if (_pendingUploads.containsKey(id) &&
          (message.mediaUrl == null || message.mediaUrl!.isEmpty)) {
        await _performMediaUpload(id);
        return;
      }
      final result = await _repository.sendMessage(
        groupId: _groupId ?? '',
        messageId: message.id,
        type: message.type,
        text: message.text,
        mediaUrl: message.mediaUrl,
        thumbnailUrl: message.thumbnailUrl,
        mediaId: message.mediaId,
        replyToMessageId: message.replyToMessageId,
        stickerKey: message.stickerKey,
        stickerCreatorId: message.stickerCreatorId,
        stickerCreatorName: message.stickerCreatorName,
      );
      _finishSend(id, result);
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

  String? _previewFor(ChatMessage? message) {
    if (message == null) return null;
    if (message.isDeleted) return 'Original message unavailable';
    if (message.type == ChatMessageType.text &&
        (message.text ?? '').trim().isNotEmpty) {
      return message.text!.trim();
    }
    if (message.isCatalogSticker) return '[sticker]';
    return '[${message.type.name}]';
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_messages.length}';

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _markDelivered(List<ChatMessage> incoming) async {
    final groupId = _groupId;
    final uid = _currentUserId;
    if (groupId == null || uid == null) return;
    final ids = incoming
        .where(
          (message) =>
              message.senderId != uid &&
              !message.isOptimistic &&
              !_deliveredMessageIds.contains(message.id),
        )
        .map((message) => message.id)
        .take(50)
        .toList(growable: false);
    if (ids.isEmpty) return;
    final result = await _repository.markAsDelivered(
      groupId: groupId,
      messageIds: ids,
    );
    if (result.isSuccess) _deliveredMessageIds.addAll(ids);
  }

  @override
  void dispose() {
    _disposed = true;
    _network?.removeListener(_onNetworkChanged);
    _cancelAllAutoRetries();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

final class _PendingMediaUpload {
  const _PendingMediaUpload({
    required this.groupId,
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.senderRole,
    this.forceType,
    this.stickerCreatorId,
    this.stickerCreatorName,
  });

  final String groupId;
  final Uint8List bytes;
  final String fileName;
  final String contentType;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String senderRole;
  final ChatMessageType? forceType;
  final String? stickerCreatorId;
  final String? stickerCreatorName;
}
