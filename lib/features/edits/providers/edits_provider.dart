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
  final Map<String, int> _likeGeneration = <String, int>{};
  final Map<String, int> _saveGeneration = <String, int>{};
  final Set<String> _skippedIds = <String>{};
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  Failure? _lastActionFailure;
  bool _hasMore = true;
  bool _loadingMore = false;
  int _activeIndex = 0;
  bool _disposed = false;

  List<Edit> get items => List.unmodifiable(
    _items.where((edit) => !_skippedIds.contains(edit.id)),
  );
  LoadingState get state => _state;
  Failure? get failure => _failure;
  Failure? get lastActionFailure => _lastActionFailure;
  bool get hasMore => _hasMore;
  int get activeIndex => _activeIndex;

  Edit displayOf(Edit edit) {
    return edit.copyWith(
      likesCount: edit.likesCount + (_likeDelta[edit.id] ?? 0),
    );
  }

  int likesCountOf(String editId) {
    final edit = _items.cast<Edit?>().firstWhere(
      (item) => item?.id == editId,
      orElse: () => null,
    );
    if (edit == null) return 0;
    return edit.likesCount + (_likeDelta[editId] ?? 0);
  }

  bool isLiked(String editId) => _liked.contains(editId);
  bool isSaved(String editId) => _saved.contains(editId);

  void clearActionFailure() {
    if (_lastActionFailure == null) return;
    _lastActionFailure = null;
    notifyListeners();
  }

  /// Mark a broken/unplayable clip so the feed can advance past it.
  void skipBroken(String editId) {
    if (!_skippedIds.add(editId)) return;
    notifyListeners();
  }

  Future<void> load({bool refresh = false, int limit = 5}) async {
    if (_state == LoadingState.loading || _loadingMore) return;
    if (!refresh && _items.isNotEmpty) return;
    _state = refresh ? LoadingState.refreshing : LoadingState.loading;
    _failure = null;
    if (refresh) _skippedIds.clear();
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

  /// Ensure a freshly published Edit is visible at the front of the feed.
  void promotePublished(Edit edit) {
    if (!edit.isPublished) return;
    final existing = _items.indexWhere((item) => item.id == edit.id);
    if (existing >= 0) {
      _items.removeAt(existing);
    }
    _items.insert(0, edit);
    _skippedIds.remove(edit.id);
    _state = LoadingState.loaded;
    _activeIndex = 0;
    notifyListeners();
  }

  /// Optimistic like — UI updates at 0ms; rolls back if the server rejects.
  Future<Result<void>> like(String editId, bool like) async {
    final wasLiked = _liked.contains(editId);
    if (like == wasLiked) return const Success<void>(null);

    final previousDelta = _likeDelta[editId] ?? 0;
    final generation = (_likeGeneration[editId] ?? 0) + 1;
    _likeGeneration[editId] = generation;

    if (like) {
      _liked.add(editId);
      _likeDelta[editId] = previousDelta + 1;
    } else {
      _liked.remove(editId);
      _likeDelta[editId] = previousDelta - 1;
    }
    _lastActionFailure = null;
    notifyListeners();

    final result = await _repository.likeEdit(editId: editId, like: like);
    if (_disposed) return result;
    if (_likeGeneration[editId] != generation) return result;

    if (!result.isSuccess) {
      if (wasLiked) {
        _liked.add(editId);
      } else {
        _liked.remove(editId);
      }
      _likeDelta[editId] = previousDelta;
      _lastActionFailure = result.failureOrNull;
      notifyListeners();
    }
    return result;
  }

  /// Optimistic save — same pattern as like.
  Future<Result<void>> save(String editId, {required bool save}) async {
    final wasSaved = _saved.contains(editId);
    if (save == wasSaved) return const Success<void>(null);

    final generation = (_saveGeneration[editId] ?? 0) + 1;
    _saveGeneration[editId] = generation;

    if (save) {
      _saved.add(editId);
    } else {
      _saved.remove(editId);
    }
    _lastActionFailure = null;
    notifyListeners();

    final result = await _repository.recordSignal(
      editId: editId,
      type: save ? 'save' : 'unsave',
    );
    if (_disposed) return result;
    if (_saveGeneration[editId] != generation) return result;

    if (!result.isSuccess) {
      if (wasSaved) {
        _saved.add(editId);
      } else {
        _saved.remove(editId);
      }
      _lastActionFailure = result.failureOrNull;
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
