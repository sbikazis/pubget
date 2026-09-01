import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/private_chat_models.dart';
import '../repositories/private_chat_repository.dart';

final class PrivateChatListProvider extends ChangeNotifier {
  PrivateChatListProvider({required PrivateChatRepository repository})
    : _repository = repository;

  final PrivateChatRepository _repository;
  final List<PrivateChatSummary> _chats = <PrivateChatSummary>[];
  final Map<String, int> _chatIndex = <String, int>{};
  StreamSubscription<Result<List<PrivateChatSummary>>>? _subscription;
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  String? _currentUserId;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _disposed = false;

  List<PrivateChatSummary> get chats => List.unmodifiable(_chats);
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get hasMore => _hasMore;
  String? get currentUserId => _currentUserId;

  Future<void> open(String currentUserId) async {
    if (_currentUserId == currentUserId && _subscription != null) return;
    await _subscription?.cancel();
    _currentUserId = currentUserId;
    _chats.clear();
    _chatIndex.clear();
    _hasMore = true;
    _failure = null;
    _state = LoadingState.loading;
    notifyListeners();
    _subscription = _repository.watchChats().listen(
      _receive,
      onError: (Object error) {
        _failure = NetworkError(error.toString());
        _state = _chats.isEmpty ? LoadingState.offline : LoadingState.loaded;
        _safeNotify();
      },
    );
  }

  Future<void> loadMore() async {
    if (!_hasMore ||
        _loadingMore ||
        _chats.isEmpty ||
        _state == LoadingState.loading) {
      return;
    }
    _loadingMore = true;
    _state = LoadingState.loadingMore;
    notifyListeners();
    final result = await _repository.getOlderChats(before: _chats.last);
    if (_disposed) return;
    result.fold(
      onSuccess: (older) {
        _merge(older);
        _hasMore = older.isNotEmpty;
        _state = _chats.isEmpty ? LoadingState.empty : LoadingState.loaded;
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

  Future<Result<String>> startChat(String otherUserId) async {
    final result = await _repository.startChat(otherUserId);
    return result;
  }

  Future<Result<void>> hideChat(String chatId) async {
    final result = await _repository.deleteChat(chatId);
    if (result.isSuccess) {
      final index = _chatIndex[chatId];
      if (index != null) {
        _chats.removeAt(index);
        _chatIndex.remove(chatId);
        _reindexFrom(index);
        _state = _chats.isEmpty ? LoadingState.empty : LoadingState.loaded;
        notifyListeners();
      }
    }
    return result;
  }

  void _receive(Result<List<PrivateChatSummary>> result) {
    if (_disposed) return;
    result.fold(
      onSuccess: (incoming) {
        _merge(incoming);
        _state = _chats.isEmpty ? LoadingState.empty : LoadingState.loaded;
        _failure = null;
      },
      onFailure: (failure) {
        _failure = failure;
        _state = _chats.isEmpty
            ? (failure is NetworkError
                  ? LoadingState.offline
                  : LoadingState.error)
            : LoadingState.loaded;
      },
    );
    notifyListeners();
  }

  void _merge(Iterable<PrivateChatSummary> incoming) {
    for (final chat in incoming) {
      final index = _chatIndex[chat.id];
      if (index == null) {
        _insertOrdered(chat);
      } else {
        _chats.removeAt(index);
        _chatIndex.remove(chat.id);
        _reindexFrom(index);
        _insertOrdered(chat);
      }
    }
  }

  int _compare(PrivateChatSummary a, PrivateChatSummary b) {
    final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final timestamp = bTime.compareTo(aTime);
    return timestamp != 0 ? timestamp : b.id.compareTo(a.id);
  }

  void _insertOrdered(PrivateChatSummary chat) {
    var low = 0;
    var high = _chats.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (_compare(_chats[middle], chat) <= 0) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    _chats.insert(low, chat);
    _reindexFrom(low);
  }

  void _reindexFrom(int start) {
    for (var index = start; index < _chats.length; index++) {
      _chatIndex[_chats[index].id] = index;
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
