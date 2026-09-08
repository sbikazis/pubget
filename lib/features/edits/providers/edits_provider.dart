import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/edit_models.dart';
import '../repositories/edits_repository.dart';

final class EditsProvider extends ChangeNotifier {
  EditsProvider({required EditsRepository repository})
    : _repository = repository;
  final EditsRepository _repository;
  final List<Edit> _items = <Edit>[];
  final Set<String> _liked = <String>{};
  final Set<String> _saved = <String>{};
  final Map<String, int> _likeDelta = <String, int>{};
  final Set<String> _pendingActions = <String>{};
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _hasMore = true;
  bool _loadingMore = false;
  int _activeIndex = 0;
  bool _disposed = false;

  List<Edit> get items => List.unmodifiable(_items);
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get hasMore => _hasMore;
  int get activeIndex => _activeIndex;

  Edit displayOf(Edit edit) {
    return edit.copyWith(
      likesCount: edit.likesCount + (_likeDelta[edit.id] ?? 0),
    );
  }

  bool isLiked(String editId) => _liked.contains(editId);
  bool isSaved(String editId) => _saved.contains(editId);

  Future<void> load({bool refresh = false, int limit = 5}) async {
    if (_state == LoadingState.loading || _loadingMore) return;
    if (!refresh && _items.isNotEmpty) return;
    _state = refresh ? LoadingState.refreshing : LoadingState.loading;
    _failure = null;
    notifyListeners();
    final result = await _repository.getFeed(limit: limit);
    if (_disposed) return;
    result.fold(
      onSuccess: (page) {
        _items
          ..clear()
          ..addAll(page.items);
        _hasMore = page.hasMore;
        _state = _items.isEmpty ? LoadingState.empty : LoadingState.loaded;
      },
      onFailure: (failure) {
        _failure = failure;
        _state = _items.isNotEmpty ? LoadingState.offline : LoadingState.error;
      },
    );
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore || _items.isEmpty) return;
    _loadingMore = true;
    _state = LoadingState.loadingMore;
    notifyListeners();
    final result = await _repository.getFeed(after: _items.last);
    if (_disposed) return;
    result.fold(
      onSuccess: (page) {
        final seen = _items.map((edit) => edit.id).toSet();
        _items.addAll(page.items.where((edit) => seen.add(edit.id)));
        _hasMore = page.hasMore;
        _state = LoadingState.loaded;
      },
      onFailure: (failure) {
        _failure = failure;
        _state = LoadingState.loaded;
      },
    );
    _loadingMore = false;
    notifyListeners();
  }

  void setActiveIndex(int index) {
    if (_activeIndex == index) return;
    _activeIndex = index;
  }

  Future<Result<void>> like(String editId, bool like) async {
    final key = 'like:$editId';
    if (!_pendingActions.add(key)) {
      return const Success<void>(null);
    }
    final result = await _repository.likeEdit(editId: editId, like: like);
    _pendingActions.remove(key);
    if (_disposed) return result;
    if (result.isSuccess) {
      final wasLiked = _liked.contains(editId);
      if (like && !wasLiked) {
        _liked.add(editId);
        _likeDelta[editId] = (_likeDelta[editId] ?? 0) + 1;
      } else if (!like && wasLiked) {
        _liked.remove(editId);
        _likeDelta[editId] = (_likeDelta[editId] ?? 0) - 1;
      }
      notifyListeners();
    }
    return result;
  }

  Future<Result<void>> save(String editId, {required bool save}) async {
    final key = 'save:$editId';
    if (!_pendingActions.add(key)) {
      return const Success<void>(null);
    }
    final result = await _repository.recordSignal(
      editId: editId,
      type: save ? 'save' : 'unsave',
    );
    _pendingActions.remove(key);
    if (_disposed) return result;
    if (result.isSuccess) {
      if (save) {
        _saved.add(editId);
      } else {
        _saved.remove(editId);
      }
      notifyListeners();
    }
    return result;
  }

  Future<Result<void>> share(String editId) {
    return _repository.recordSignal(editId: editId, type: 'share');
  }

  Future<Result<void>> report(String editId) {
    return _repository.recordSignal(editId: editId, type: 'negative');
  }

  Future<Result<void>> comment(
    String editId,
    String text, {
    String? replyToCommentId,
    String kind = 'text',
    List<String> mentions = const <String>[],
  }) => _repository.addComment(
    editId: editId,
    text: text,
    replyToCommentId: replyToCommentId,
    kind: kind,
    mentions: mentions,
  );

  Future<Result<void>> view({
    required String editId,
    required String sessionId,
    required double percent,
    required double seconds,
    String eventType = 'progress',
  }) => _repository.recordView(
    editId: editId,
    sessionId: sessionId,
    watchPercent: percent,
    watchSeconds: seconds,
    eventType: eventType,
  );

  Future<Result<void>> impression({
    required String editId,
    required String sessionId,
  }) => _repository.recordImpression(editId: editId, sessionId: sessionId);

  Future<Result<String>> startPlayback(String editId) =>
      _repository.startPlayback(editId);

  Future<Result<Edit>> repost(String editId) => _repository.repostEdit(editId);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
