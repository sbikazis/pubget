import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/edit_models.dart';
import '../repositories/edits_repository.dart';

final class EditsProvider extends ChangeNotifier {
  EditsProvider({
    required EditsRepository repository,
    this.audioId,
    this.animeId,
    this.characterId,
    this.hashtag,
    this.creatorId,
    FeedType feedType = FeedType.forYou,
  }) : _repository = repository,
       _feedType = feedType;
  final EditsRepository _repository;

  /// Axis 15 §15.16 — an optional scope narrows the whole feed to one
  /// context. At most one is expected to be set by a scoped entry point.
  final String? audioId;
  final String? animeId;
  final String? characterId;
  final String? hashtag;
  final String? creatorId;

  FeedType _feedType;
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

  /// Cached immutable view of the visible feed.
  ///
  /// The cache is what makes per-item rebuild scoping possible: a fresh
  /// `List.unmodifiable` on every read would give `context.select` a new
  /// identity each notification, so liking one Reel would rebuild the whole
  /// feed. Identity changes only when the underlying rows actually change, so
  /// `select` can tell "the feed changed" from "this Reel's like state changed".
  List<Edit>? _itemsCache;

  List<Edit> get items => _itemsCache ??= List<Edit>.unmodifiable(
    _items.where((edit) => !_skippedIds.contains(edit.id)),
  );

  /// Call after any mutation of `_items` or `_skippedIds`.
  void _touchItems() {
    _itemsCache = null;
  }
  LoadingState get state => _state;
  Failure? get failure => _failure;
  Failure? get lastActionFailure => _lastActionFailure;
  bool get hasMore => _hasMore;
  int get activeIndex => _activeIndex;
  FeedType get feedType => _feedType;

  /// Switch ranking strategy (For You / Following / Trending). Resets paging
  /// and re-queries the server — the client never re-sorts a cached page.
  void setFeedType(FeedType type) {
    if (_feedType == type) return;
    _feedType = type;
    _items.clear();
    _skippedIds.clear();
    _touchItems();
    _hasMore = true;
    _activeIndex = 0;
    _state = LoadingState.initial;
    _failure = null;
    notifyListeners();
    load(refresh: true);
  }

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
    _touchItems();
    notifyListeners();
  }

  Future<void> load({bool refresh = false, int limit = 5, String? audioId}) async {
    if (_state == LoadingState.loading || _loadingMore) return;
    if (!refresh && _items.isNotEmpty) return;
    _state = refresh ? LoadingState.refreshing : LoadingState.loading;
    _failure = null;
    if (refresh) _skippedIds.clear();
    notifyListeners();
    final result = await _repository.getFeed(
      limit: limit,
      audioId: audioId ?? this.audioId,
      animeId: animeId,
      characterId: characterId,
      hashtag: hashtag,
      creatorId: creatorId,
      feedType: _feedType,
    );
    if (_disposed) return;
    result.fold(
      onSuccess: (page) {
        _items
          ..clear()
          ..addAll(page.items);
        _touchItems();
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

  Future<void> loadMore({String? audioId}) async {
    if (!_hasMore || _loadingMore || _items.isEmpty) return;
    _loadingMore = true;
    _state = LoadingState.loadingMore;
    notifyListeners();
    final result = await _repository.getFeed(
      after: _items.last,
      audioId: audioId ?? this.audioId,
      animeId: animeId,
      characterId: characterId,
      hashtag: hashtag,
      creatorId: creatorId,
      feedType: _feedType,
    );
    if (_disposed) return;
    result.fold(
      onSuccess: (page) {
        final seen = _items.map((edit) => edit.id).toSet();
        _items.addAll(page.items.where((edit) => seen.add(edit.id)));
        _touchItems();
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
    _touchItems();
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

  /// Creator ids the viewer has muted, for immediate UI feedback.
  final Set<String> _mutedCreators = <String>{};

  bool isMuted(String creatorId) => _mutedCreators.contains(creatorId);

  /// Mute or unmute a Reels creator.
  ///
  /// The server owns the durable mute row; this only makes the change visible
  /// immediately. On mute the creator's loaded Reels leave the feed right away
  /// rather than lingering until the next page fetch, and a failed write
  /// re-reads the feed so the screen never keeps a lie on it.
  Future<Result<void>> muteCreator(
    String creatorId, {
    required bool mute,
  }) async {
    if (creatorId.isEmpty) {
      return const Success<void>(null);
    }
    final wasMuted = _mutedCreators.contains(creatorId);
    if (mute == wasMuted) return const Success<void>(null);

    if (mute) {
      _mutedCreators.add(creatorId);
      _items.removeWhere((edit) => edit.creatorId == creatorId);
      _touchItems();
    } else {
      _mutedCreators.remove(creatorId);
    }
    notifyListeners();

    final result = await _repository.muteReelCreator(
      creatorId: creatorId,
      mute: mute,
    );
    if (_disposed) return result;

    if (!result.isSuccess) {
      if (wasMuted) {
        _mutedCreators.add(creatorId);
      } else {
        _mutedCreators.remove(creatorId);
      }
      _lastActionFailure = result.failureOrNull;
      notifyListeners();
      // The removed rows cannot be restored faithfully from local state alone,
      // so re-read instead of guessing.
      await load(refresh: true);
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
