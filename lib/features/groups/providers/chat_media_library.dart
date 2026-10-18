import 'package:flutter/foundation.dart';

import '../models/chat_models.dart';
import '../repositories/chat_repository.dart';

enum ChatMediaLibraryState {
  initial,
  loading,
  loaded,
  empty,
  error,
  offline,
}

final class ChatMediaLibrary extends ChangeNotifier {
  ChatMediaLibrary({required ChatRepository repository})
      : _repository = repository;

  final ChatRepository _repository;
  String? _groupId;
  ChatMediaLibraryState _state = ChatMediaLibraryState.initial;
  Object? _error;
  List<ChatMessage> _media = const <ChatMessage>[];
  ChatMessage? _oldest;
  bool _hasMore = true;
  bool _loadingMore = false;

  ChatMediaLibraryState get state => _state;
  Object? get error => _error;
  List<ChatMessage> get media => _media;
  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;

  void _setState(ChatMediaLibraryState value) {
    if (_state == value) return;
    _state = value;
    notifyListeners();
  }

  Future<void> open(String groupId) async {
    _groupId = groupId;
    _media = const <ChatMessage>[];
    _oldest = null;
    _hasMore = true;
    _loadingMore = false;
    _error = null;
    _setState(ChatMediaLibraryState.loading);
    final result = await _repository.getRecentMessages(groupId: groupId);
    if (result.failureOrNull != null) {
      _error = result.failureOrNull;
      _setState(ChatMediaLibraryState.error);
      return;
    }
    final all = result.valueOrNull ?? const <ChatMessage>[];
    final filtered = all
        .where(
          (message) =>
              !message.isDeleted &&
              (message.isMedia ||
                  message.type == ChatMessageType.sticker ||
                  message.type == ChatMessageType.audio),
        )
        .toList(growable: false);
    _media = filtered;
    if (all.isEmpty) {
      _oldest = null;
      _hasMore = false;
      _setState(
        filtered.isEmpty
            ? ChatMediaLibraryState.empty
            : ChatMediaLibraryState.loaded,
      );
      return;
    }
    _oldest = all.last;
    _hasMore = all.length >= 40;
    _setState(
      filtered.isEmpty
          ? ChatMediaLibraryState.empty
          : ChatMediaLibraryState.loaded,
    );
  }

  Future<void> loadMore() async {
    final groupId = _groupId;
    final oldest = _oldest;
    if (groupId == null || oldest == null || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    notifyListeners();
    final result = await _repository.getOlderMessages(
      groupId: groupId,
      before: oldest,
      limit: 40,
    );
    _loadingMore = false;
    if (result.failureOrNull != null) {
      _error = result.failureOrNull;
      notifyListeners();
      return;
    }
    final all = result.valueOrNull ?? const <ChatMessage>[];
    if (all.isEmpty) {
      _hasMore = false;
      notifyListeners();
      return;
    }
    final filtered = all
        .where(
          (message) =>
              !message.isDeleted &&
              (message.isMedia ||
                  message.type == ChatMessageType.sticker ||
                  message.type == ChatMessageType.audio),
        )
        .toList(growable: false);
    if (filtered.isNotEmpty) {
      _media = <ChatMessage>[..._media, ...filtered];
    }
    _oldest = all.last;
    _hasMore = all.length >= 40;
    notifyListeners();
  }

  Future<void> refresh() async {
    final groupId = _groupId;
    if (groupId == null) return;
    await open(groupId);
  }
}
