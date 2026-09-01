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
        _items.addAll(page.items);
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
    _activeIndex = index;
    notifyListeners();
  }

  Future<Result<void>> like(String editId, bool like) =>
      _repository.likeEdit(editId: editId, like: like);

  Future<Result<void>> comment(String editId, String text) =>
      _repository.addComment(editId: editId, text: text);

  Future<Result<void>> view({
    required String editId,
    required String sessionId,
    required double percent,
    required double seconds,
  }) => _repository.recordView(
    editId: editId,
    sessionId: sessionId,
    watchPercent: percent,
    watchSeconds: seconds,
  );

  Future<Result<String>> startPlayback(String editId) =>
      _repository.startPlayback(editId);

  Future<Result<Edit>> repost(String editId) => _repository.repostEdit(editId);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
