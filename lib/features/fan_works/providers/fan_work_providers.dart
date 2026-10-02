import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/fan_work_lifecycle.dart';
import '../models/fan_work_models.dart';
import '../repositories/fan_work_repository.dart';
import '../repositories/memory_fan_work_draft_store.dart';

final class FanWorkFeedProvider extends ChangeNotifier {
  FanWorkFeedProvider({required FanWorkRepository repository})
    : _repository = repository;

  final FanWorkRepository _repository;
  final List<FanWork> _items = <FanWork>[];
  final Set<String> _seenIds = <String>{};
  List<FanWork> _drafts = const <FanWork>[];
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _offlineCached = false;
  FanWorkType? _type;
  String? _animeId;
  String? _characterId;
  bool _disposed = false;

  List<FanWork> get items => List<FanWork>.unmodifiable(_items);
  List<FanWork> get drafts => _drafts;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get hasMore => _hasMore;
  bool get offlineCached => _offlineCached;
  FanWorkType? get type => _type;
  String? get animeId => _animeId;
  String? get characterId => _characterId;

  Future<void> load({
    FanWorkType? type,
    String? animeId,
    String? characterId,
    bool refresh = false,
  }) async {
    final typeChanged =
        type != _type || animeId != _animeId || characterId != _characterId;
    if (typeChanged || refresh) {
      _type = type;
      _animeId = animeId;
      _characterId = characterId;
      _items.clear();
      _seenIds.clear();
      _hasMore = true;
    }
    _state = _items.isEmpty ? LoadingState.loading : LoadingState.refreshing;
    _failure = null;
    _offlineCached = false;
    notifyListeners();
    final result = await _fetchFeed();
    result.fold(
      onSuccess: (page) {
        _replacePage(page);
        _state = _items.isEmpty ? LoadingState.empty : LoadingState.loaded;
        _failure = null;
      },
      onFailure: (failure) {
        _failure = failure;
        if (_items.isNotEmpty && failure is NetworkError) {
          _offlineCached = true;
          _state = LoadingState.loaded;
        } else {
          _state = failure is NetworkError
              ? LoadingState.offline
              : LoadingState.error;
        }
      },
    );
    _safeNotify();
  }

  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore || _items.isEmpty) return;
    _loadingMore = true;
    _state = LoadingState.loadingMore;
    notifyListeners();
    final result = await _fetchFeed(after: _items.last);
    result.fold(
      onSuccess: (page) {
        _appendPage(page);
        _state = LoadingState.loaded;
        _failure = null;
      },
      onFailure: (failure) {
        _failure = failure;
        _state = _items.isEmpty ? LoadingState.error : LoadingState.loaded;
      },
    );
    _loadingMore = false;
    _safeNotify();
  }

  Future<void> retryNextPage() => loadMore();

  Future<void> loadDrafts(String userId) async {
    final result = await _repository.getMyDrafts(userId: userId);
    result.fold(onSuccess: (drafts) => _drafts = drafts, onFailure: (_) {});
    _safeNotify();
  }

  Future<Result<FanWorkListPage>> _fetchFeed({FanWork? after}) {
    final characterId = _characterId;
    final repository = _repository;
    if (characterId != null &&
        characterId.isNotEmpty &&
        repository is CharacterFanWorkRepository) {
      return (repository as CharacterFanWorkRepository).getCharacterFeed(
        characterId,
        after: after,
      );
    }
    return repository.getPublicFeed(
      type: _type,
      animeId: _animeId,
      after: after,
    );
  }

  void _replacePage(FanWorkListPage page) {
    _items
      ..clear()
      ..addAll(page.items);
    _seenIds
      ..clear()
      ..addAll(page.items.map((work) => work.id));
    _hasMore = page.hasMore;
  }

  void _appendPage(FanWorkListPage page) {
    if (page.items.isEmpty) {
      _hasMore = false;
      return;
    }
    for (final work in page.items) {
      if (_seenIds.add(work.id)) {
        _items.add(work);
      }
    }
    _hasMore = page.hasMore;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final class FanWorkDetailsProvider extends ChangeNotifier {
  FanWorkDetailsProvider({
    required FanWorkRepository repository,
    Analytics analytics = const _NoOpAnalytics(),
  }) : _repository = repository,
       _analytics = analytics;

  final FanWorkRepository _repository;
  final Analytics _analytics;
  StreamSubscription<Result<FanWork>>? _subscription;
  FanWork? _work;
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _liked = false;
  bool _bookmarked = false;
  int? _myRating;
  bool _acting = false;
  bool _disposed = false;
  final List<FanWorkComment> _comments = <FanWorkComment>[];
  bool _commentsLoading = false;
  bool _commentsLoadingMore = false;
  bool _commentsHasMore = false;
  Failure? _commentsFailure;
  FanWorkComment? _replyTo;

  final List<FanWorkRevision> _revisions = <FanWorkRevision>[];
  bool _revisionsLoading = false;
  bool _revisionsLoaded = false;
  Failure? _revisionsFailure;

  FanWork? get work => _work;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get liked => _liked;
  bool get bookmarked => _bookmarked;
  int? get myRating => _myRating;
  bool get acting => _acting;
  List<FanWorkComment> get comments =>
      List<FanWorkComment>.unmodifiable(_comments);
  bool get commentsLoading => _commentsLoading;
  bool get commentsLoadingMore => _commentsLoadingMore;
  bool get commentsHasMore => _commentsHasMore;
  Failure? get commentsFailure => _commentsFailure;
  FanWorkComment? get replyTo => _replyTo;
  List<FanWorkRevision> get revisions =>
      List<FanWorkRevision>.unmodifiable(_revisions);
  bool get revisionsLoading => _revisionsLoading;
  bool get revisionsLoaded => _revisionsLoaded;
  Failure? get revisionsFailure => _revisionsFailure;

  Future<void> open({required String workId, required String userId}) async {
    _state = LoadingState.loading;
    notifyListeners();
    _analytics.logEvent('fan_work_open', parameters: {'workId': workId});
    await _subscription?.cancel();
    final liked = await _repository.hasLiked(workId: workId, userId: userId);
    final bookmarked = await _repository.hasBookmarked(
      workId: workId,
      userId: userId,
    );
    final rating = await _repository.myRating(workId: workId, userId: userId);
    _liked = liked.valueOrNull ?? false;
    _bookmarked = bookmarked.valueOrNull ?? false;
    _myRating = rating.valueOrNull;
    await loadComments(workId);
    _subscription = _repository.watchWork(workId).listen((result) {
      if (_disposed) return;
      result.fold(
        onSuccess: (work) {
          _work = work;
          _state = LoadingState.loaded;
          _failure = null;
        },
        onFailure: (failure) {
          _failure = failure;
          _state = failure is NotFoundError
              ? LoadingState.empty
              : failure is NetworkError
              ? LoadingState.offline
              : LoadingState.error;
        },
      );
      _safeNotify();
    });
  }

  Future<Result<void>> toggleLike(String workId) {
    return _act(() async {
      final next = !_liked;
      final result = await _repository.like(workId: workId, like: next);
      if (result.isSuccess) _liked = next;
      return result;
    });
  }

  Future<Result<void>> toggleBookmark(String workId) {
    return _act(() async {
      final next = !_bookmarked;
      final result = await _repository.bookmark(workId: workId, bookmark: next);
      if (result.isSuccess) _bookmarked = next;
      return result;
    });
  }

  Future<Result<void>> rate({required String workId, required int rating}) {
    return _act(() async {
      final result = await _repository.rate(workId: workId, rating: rating);
      if (result.isSuccess) {
        _myRating = rating;
        _analytics.logEvent(
          'fan_work_rated',
          parameters: {'workId': workId, 'rating': rating},
        );
      }
      return result;
    });
  }

  Future<Result<void>> report({
    required String workId,
    required FanWorkReportReason reason,
    String details = '',
  }) {
    return _act(() async {
      final result = await _repository.report(
        workId: workId,
        reason: reason,
        details: details,
      );
      if (result.isSuccess) {
        _analytics.logEvent(
          'fan_work_reported',
          parameters: {'workId': workId, 'reason': reason.name},
        );
      }
      return result;
    });
  }

  Future<Result<void>> archive(String workId) {
    return _act(() => _repository.archive(workId));
  }

  Future<Result<void>> requestRemoval({
    required String workId,
    String details = '',
  }) {
    return _act(() async {
      final result = await _repository.requestRemoval(
        workId: workId,
        details: details,
      );
      if (result.isSuccess) {
        _analytics.logEvent(
          'fan_work_removal_requested',
          parameters: {'workId': workId},
        );
      }
      return result;
    });
  }

  Future<Result<void>> revisePublished({
    required String workId,
    String? title,
    String? description,
    FanWorkCopyright? copyright,
  }) {
    return _act(() async {
      final result = await _repository.revisePublished(
        workId: workId,
        title: title,
        description: description,
        copyright: copyright,
      );
      if (result.isSuccess) {
        _analytics.logEvent('fan_work_revised', parameters: {'workId': workId});
      }
      return result;
    });
  }

  void setReplyTo(FanWorkComment? comment) {
    _replyTo = comment;
    _safeNotify();
  }

  Future<void> loadComments(String workId, {bool more = false}) async {
    if (more) {
      if (_commentsLoadingMore || !_commentsHasMore || _comments.isEmpty) {
        return;
      }
      _commentsLoadingMore = true;
    } else {
      _commentsLoading = true;
      _commentsFailure = null;
    }
    _safeNotify();
    final result = await _repository.getComments(
      workId,
      after: more ? _comments.last : null,
    );
    if (_disposed) return;
    result.fold(
      onSuccess: (items) {
        if (more) {
          _comments.addAll(items);
        } else {
          _comments
            ..clear()
            ..addAll(items);
        }
        _commentsHasMore = items.length >= 30;
        _commentsLoading = false;
        _commentsLoadingMore = false;
        _commentsFailure = null;
      },
      onFailure: (failure) {
        _commentsFailure = failure;
        _commentsLoading = false;
        _commentsLoadingMore = false;
      },
    );
    _safeNotify();
  }

  Future<Result<void>> loadRevisions(String workId) async {
    _revisionsLoading = true;
    _revisionsFailure = null;
    _safeNotify();
    final result = await _repository.getRevisions(workId);
    if (_disposed) return const Success<void>(null);
    result.fold(
      onSuccess: (revisions) {
        _revisions
          ..clear()
          ..addAll(revisions);
        _revisionsLoaded = true;
        _revisionsLoading = false;
      },
      onFailure: (failure) {
        _revisionsFailure = failure;
        _revisionsLoading = false;
      },
    );
    _safeNotify();
    return _revisionsLoaded
        ? const Success<void>(null)
        : FailureResult(_revisionsFailure ?? const UnknownError());
  }

  Future<Result<void>> addComment({
    required String workId,
    required String text,
  }) {
    return _act(() async {
      final result = await _repository.addComment(
        workId: workId,
        text: text,
        replyToCommentId: _replyTo?.id,
        eventId: '${workId}_${DateTime.now().microsecondsSinceEpoch}',
      );
      if (result.isSuccess) {
        _replyTo = null;
        _analytics.logEvent(
          'fan_work_commented',
          parameters: {'workId': workId},
        );
        await loadComments(workId);
      }
      return result;
    });
  }

  Future<Result<void>> commentAction({
    required String workId,
    required String commentId,
    required String action,
  }) {
    return _act(() async {
      final result = await _repository.commentAction(
        workId: workId,
        commentId: commentId,
        action: action,
      );
      if (result.isSuccess) {
        if (action == 'delete') {
          _comments.removeWhere((comment) => comment.id == commentId);
        }
        await loadComments(workId);
      }
      return result;
    });
  }

  Future<Result<T>> _act<T>(Future<Result<T>> Function() action) async {
    _acting = true;
    _safeNotify();
    final result = await action();
    _acting = false;
    _safeNotify();
    return result;
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

enum FanWorkEditorStep { type, details, content, preview }

/// Drives the in-app reader for a document-backed work.
///
/// The provider owns the signed grant, so a `pdfrx` controller only ever sees a
/// URL that stops working a few minutes later. It also tracks progress so a
/// reader who closes the app resumes on the page they left.
final class FanWorkReaderProvider extends ChangeNotifier {
  FanWorkReaderProvider({required FanWorkRepository repository})
    : _repository = repository;

  final FanWorkRepository _repository;

  FanWorkDocumentAccess? _access;
  FanWorkReadingProgress _progress = const FanWorkReadingProgress();
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  String? _userId;
  String? _workId;
  bool _disposed = false;

  /// The work itself, loaded alongside the grant.
  ///
  /// The reader needs it to tell a document-backed work from a pre-rebuild one:
  /// a legacy manga is a list of page images and a legacy story is prose, and
  /// neither has a PDF for the document reader to open. Deciding that from the
  /// grant alone is not possible, because a legacy work has no grant at all.
  FanWork? _work;

  FanWorkDocumentAccess? get access => _access;

  FanWork? get work => _work;

  /// How this work should actually be rendered.
  FanWorkReaderShape get shape {
    final content = _work?.content;
    if (content == null) return FanWorkReaderShape.unknown;
    if (content.hasDocument) return FanWorkReaderShape.document;
    if (content.pages.isNotEmpty) return FanWorkReaderShape.legacyPages;
    if (content.body.trim().isNotEmpty ||
        content.chapters.isNotEmpty ||
        content.lore.trim().isNotEmpty) {
      return FanWorkReaderShape.legacyProse;
    }
    return FanWorkReaderShape.unknown;
  }

  /// The URL a reader controller can consume right now.
  String? get url => _access?.url;
  FanWorkReadingProgress get progress => _progress;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  int? get pageCount => _access?.pageCount ?? _progress.pageCount;
  int get page => _progress.page;
  bool get completed => _progress.completed;
  bool get canResume => _progress.isStarted;

  Future<void> open({
    required String workId,
    required String userId,
    int? pageCount,
  }) async {
    _workId = workId;
    _userId = userId;
    _state = LoadingState.loading;
    _failure = null;
    notifyListeners();
    final stored = await _repository.getReadingProgress(
      workId: workId,
      userId: userId,
    );
    if (_disposed) return;
    _progress = stored.valueOrNull ?? const FanWorkReadingProgress();

    // The work is loaded first: if it turns out to be a legacy row there is no
    // grant to mint, and asking for one would surface a confusing "not found"
    // for a work that reads perfectly well.
    final work = await _repository.getWork(workId);
    if (_disposed) return;
    final loaded = work.valueOrNull;
    if (loaded == null) {
      _work = null;
      _access = null;
      _failure = work.failureOrNull;
      _state = work.failureOrNull is NetworkError
          ? LoadingState.offline
          : LoadingState.error;
      _safeNotify();
      return;
    }
    _work = loaded;
    if (!loaded.content.hasDocument) {
      _access = null;
      _failure = null;
      _state = LoadingState.loaded;
      _safeNotify();
      return;
    }

    final access = await _repository.getDocumentAccess(workId: workId);
    if (_disposed) return;
    access.fold(
      onSuccess: (grant) {
        _access = grant;
        _state = LoadingState.loaded;
        _failure = null;
      },
      onFailure: (failure) {
        _access = null;
        _failure = failure;
        _state = failure is NetworkError
            ? LoadingState.offline
            : LoadingState.error;
      },
    );
    _safeNotify();
  }

  /// Re-mints the grant. Called when the reader reports the old URL is dead,
  /// which is the expected outcome once the 3-minute window closes.
  Future<Result<FanWorkDocumentAccess>> refresh() async {
    final workId = _workId;
    if (workId == null || workId.isEmpty) {
      return const FailureResult(ValidationError(FanWorkStrings.missing));
    }
    final access = await _repository.getDocumentAccess(workId: workId);
    access.fold(
      onSuccess: (grant) {
        _access = grant;
        _state = LoadingState.loaded;
        _failure = null;
      },
      onFailure: (failure) => _failure = failure,
    );
    _safeNotify();
    return access;
  }

  Future<Result<void>> recordPage(int page) async {
    final workId = _workId;
    final userId = _userId;
    if (workId == null || userId == null) {
      return const FailureResult(ValidationError(FanWorkStrings.missing));
    }
    final total = pageCount ?? _progress.pageCount;
    // Progress only ever moves forward: a shortened re-upload must not drag a
    // reader back to the start.
    final nextPage = page < _progress.page ? _progress.page : page;
    final ratio = total > 0 ? (nextPage / total).clamp(0.0, 1.0) : 0.0;
    _progress = FanWorkReadingProgress(
      page: nextPage,
      pageCount: total,
      progress: ratio < _progress.progress ? _progress.progress : ratio,
      completed: _progress.completed,
      updatedAt: DateTime.now().toUtc(),
    );
    _safeNotify();
    return _repository.saveReadingProgress(workId: workId, progress: _progress);
  }

  Future<Result<void>> markAsRead() async {
    final workId = _workId;
    if (workId == null) {
      return const FailureResult(ValidationError(FanWorkStrings.missing));
    }
    final total = pageCount ?? _progress.pageCount;
    final result = await _repository.markAsRead(workId: workId);
    if (result.isSuccess) {
      _progress = FanWorkReadingProgress(
        page: _progress.page,
        pageCount: total,
        progress: 1,
        completed: true,
        updatedAt: DateTime.now().toUtc(),
      );
      _safeNotify();
    }
    return result;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final class _PendingFanWorkUpload {
  _PendingFanWorkUpload({
    required List<int> bytes,
    required this.contentType,
    required this.role,
    required this.caption,
    this.characterId = '',
    this.pageCount,
  }) : bytes = List<int>.of(bytes);

  final List<int> bytes;
  final String contentType;
  final FanWorkMediaRole role;
  final String caption;

  /// Set for a cast portrait so the server knows which entry to attach to.
  final String characterId;

  /// Set for a PDF document, so a card can show "N pages" without downloading.
  final int? pageCount;

  FanWorkUploadTicket? ticket;
  bool bytesUploaded = false;
}

final class FanWorkEditorProvider extends ChangeNotifier {
  FanWorkEditorProvider({
    required FanWorkRepository repository,
    FanWorkDraftStore? draftStore,
    Analytics analytics = const _NoOpAnalytics(),
  }) : _repository = repository,
       _draftStore = draftStore ?? MemoryFanWorkDraftStore(),
       _analytics = analytics;

  final FanWorkRepository _repository;
  final FanWorkDraftStore _draftStore;
  final Analytics _analytics;

  FanWorkEditorStep _step = FanWorkEditorStep.type;
  FanWorkDraft _draft = const FanWorkDraft(type: FanWorkType.drawing);
  FanWork? _loaded;
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  String? _fieldError;
  bool _saving = false;
  bool _publishing = false;
  bool _uploading = false;
  bool _uploadCancellable = false;
  double _uploadProgress = 0;
  Failure? _uploadFailure;
  _PendingFanWorkUpload? _pendingUpload;
  bool _draftSavedLocally = false;
  bool _disposed = false;

  FanWorkEditorStep get step => _step;
  FanWorkDraft get draft => _draft;
  FanWork? get loaded => _loaded;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  String? get fieldError => _fieldError;
  bool get saving => _saving;
  bool get publishing => _publishing;
  bool get uploading => _uploading;
  bool get uploadCancellable => _uploadCancellable;
  double get uploadProgress => _uploadProgress;
  int get uploadPercent => (_uploadProgress * 100).round();
  bool get uploadFailed => _uploadFailure != null;
  bool get uploadCanceled => _uploadFailure is CancelledError;
  bool get canRetryUpload => _pendingUpload != null && !_uploading;
  bool get draftSavedLocally => _draftSavedLocally;
  bool get busy => _saving || _publishing || _uploading;

  String get _localKey => _draft.workId ?? 'new';

  Future<void> start({String? workId, FanWorkType? type}) async {
    _state = LoadingState.loading;
    _failure = null;
    notifyListeners();
    _analytics.logEvent('fan_work_create_started');
    if (type != null) {
      _draft = FanWorkDraft(type: type);
      _step = FanWorkEditorStep.details;
      _analytics.logEvent(
        'fan_work_type_selected',
        parameters: {'type': type.name},
      );
    }
    if (workId != null && workId.isNotEmpty) {
      final result = await _repository.getWork(workId);
      if (!result.isSuccess) {
        _failure = result.failureOrNull;
        _state = _failure is NetworkError
            ? LoadingState.offline
            : LoadingState.error;
        _safeNotify();
        return;
      }
      _loaded = result.valueOrNull;
      if (_loaded != null) {
        _draft = FanWorkDraft.fromWork(_loaded!);
        _step = FanWorkEditorStep.details;
      }
    } else {
      final local = await _draftStore.read(_localKey);
      if (local != null) {
        _restoreLocal(local);
        _draftSavedLocally = true;
      }
    }
    _state = LoadingState.loaded;
    _safeNotify();
  }

  void selectType(FanWorkType type) {
    _draft = _draft.copyWith(type: type);
    _step = FanWorkEditorStep.details;
    _analytics.logEvent(
      'fan_work_type_selected',
      parameters: {'type': type.name},
    );
    unawaited(_persistLocal());
    notifyListeners();
  }

  void goTo(FanWorkEditorStep step) {
    _step = step;
    notifyListeners();
  }

  void updateDraft(FanWorkDraft draft) {
    _draft = draft;
    _fieldError = null;
    unawaited(_persistLocal());
    notifyListeners();
  }

  Future<Result<String>> saveDraft() async {
    _saving = true;
    _failure = null;
    notifyListeners();
    await _persistLocal();
    final result = await _repository.saveDraft(_draft);
    result.fold(
      onSuccess: (workId) {
        _draft = _draft.copyWith(workId: workId);
        _draftSavedLocally = true;
        _analytics.logEvent(
          'fan_work_draft_saved',
          parameters: {'workId': workId, 'type': _draft.type.name},
        );
        unawaited(_draftStore.write(workId, _localMap()));
        if (_localKey == 'new') unawaited(_draftStore.delete('new'));
      },
      onFailure: (failure) {
        _failure = failure;
        _draftSavedLocally = true;
      },
    );
    _saving = false;
    _safeNotify();
    return result;
  }

  /// Validates against the type's allowed roles before a byte leaves the
  /// device, so a PDF offered as an artwork slot fails with the same message
  /// the server would return.
  Future<Result<void>> uploadMedia({
    required List<int> bytes,
    required String contentType,
    required FanWorkMediaRole role,
    String caption = '',
    String characterId = '',
    int? pageCount,
  }) async {
    final mediaError = FanWorkLifecycle.uploadError(
      type: _draft.type,
      role: role,
      contentType: contentType,
      sizeBytes: bytes.length,
    );
    if (mediaError != null) {
      _fieldError = mediaError;
      notifyListeners();
      return FailureResult(ValidationError(mediaError));
    }
    if (_uploading) {
      return FailureResult(
        const ValidationError(FanWorkStrings.uploadAlreadyRunning),
      );
    }
    final pending = _PendingFanWorkUpload(
      bytes: bytes,
      contentType: contentType,
      role: role,
      caption: caption,
      characterId: characterId,
      pageCount: pageCount,
    );
    _pendingUpload = pending;
    return _runUpload(pending);
  }

  Future<Result<void>> retryUpload() {
    final pending = _pendingUpload;
    if (pending == null) {
      return Future<Result<void>>.value(
        const FailureResult(
          ValidationError(FanWorkStrings.uploadNothingToRetry),
        ),
      );
    }
    if (_uploading) {
      return Future<Result<void>>.value(
        const FailureResult(
          ValidationError(FanWorkStrings.uploadAlreadyRunning),
        ),
      );
    }
    return _runUpload(pending);
  }

  Future<Result<void>> cancelUpload() {
    if (!_uploadCancellable) return Future.value(const Success<void>(null));
    return _repository.cancelMediaUpload();
  }

  Future<Result<void>> _runUpload(_PendingFanWorkUpload pending) async {
    _uploading = true;
    _uploadCancellable = false;
    _uploadProgress = 0;
    _uploadFailure = null;
    _fieldError = null;
    _safeNotify();
    var workId = _draft.workId;
    if (workId == null || workId.isEmpty) {
      final saved = await _repository.saveDraft(_draft);
      if (!saved.isSuccess) {
        return _failedUpload(saved.failureOrNull);
      }
      workId = saved.valueOrNull;
      _draft = _draft.copyWith(workId: workId);
    }
    final resolvedWorkId = workId!;
    var upload = pending.ticket;
    if (upload == null) {
      final ticket = await _repository.startMediaUpload(
        workId: resolvedWorkId,
        role: pending.role,
        contentType: pending.contentType,
      );
      if (!ticket.isSuccess) {
        return _failedUpload(ticket.failureOrNull);
      }
      upload = ticket.valueOrNull!;
      pending.ticket = upload;
    }
    // Bound once so the closure below cannot see a re-assigned nullable local.
    final grant = upload;
    if (!pending.bytesUploaded) {
      _uploadCancellable = true;
      final bytesResult = await _repository.uploadMediaBytes(
        ticket: grant,
        bytes: pending.bytes,
        contentType: pending.contentType,
        onProgress: _setUploadProgress,
      );
      _uploadCancellable = false;
      if (!bytesResult.isSuccess) {
        return _failedUpload(bytesResult.failureOrNull);
      }
      pending.bytesUploaded = true;
    } else {
      _setUploadProgress(1);
    }
    final confirmed = await _repository.confirmMedia(
      workId: resolvedWorkId,
      mediaId: grant.mediaId,
      path: grant.path,
      role: pending.role,
      caption: pending.caption,
      characterId: pending.characterId,
      pageCount: pending.pageCount,
    );
    if (!confirmed.isSuccess) {
      return _failedUpload(confirmed.failureOrNull);
    }
    // A cast portrait lives inside the draft's own character list, so the local
    // copy has to learn about it; every other slot is written by the server and
    // picked up from the refreshed document below.
    if (pending.role == FanWorkMediaRole.characterPortrait &&
        pending.characterId.isNotEmpty) {
      _draft = _draft.copyWith(
        characters: _draft.characters
            .map(
              (entry) => entry.id == pending.characterId
                  ? entry.copyWith(
                      imagePath: grant.path,
                      imageMediaId: grant.mediaId,
                    )
                  : entry,
            )
            .toList(growable: false),
      );
    }
    _pendingUpload = null;
    _uploadProgress = 1;
    _uploadFailure = null;
    await _persistLocal();
    final refreshed = await _repository.getWork(resolvedWorkId);
    _loaded = refreshed.valueOrNull ?? _loaded;
    _uploading = false;
    _safeNotify();
    return confirmed;
  }

  void _setUploadProgress(double value) {
    if (!value.isFinite) return;
    final next = value.clamp(0.0, 1.0).toDouble();
    if ((next - _uploadProgress).abs() < 0.001) return;
    _uploadProgress = next;
    _safeNotify();
  }

  Result<void> _failedUpload(Failure? failure) {
    final resolved = failure ?? const NetworkError(FanWorkStrings.uploadFailed);
    _uploadFailure = resolved;
    _draftSavedLocally = true;
    _uploading = false;
    _uploadCancellable = false;
    _safeNotify();
    return FailureResult(resolved);
  }

  Future<Result<FanWork>> publish() async {
    _publishing = true;
    _failure = null;
    _fieldError = null;
    notifyListeners();
    await _persistLocal();
    var workId = _draft.workId;
    final saved = await _repository.saveDraft(_draft);
    if (!saved.isSuccess) {
      _publishing = false;
      _failure = saved.failureOrNull;
      _draftSavedLocally = true;
      _safeNotify();
      return FailureResult(_failure ?? const UnknownError());
    }
    workId = saved.valueOrNull;
    _draft = _draft.copyWith(workId: workId);
    final current = await _repository.getWork(workId!);
    final work = current.valueOrNull;
    if (work != null) {
      final error = FanWorkLifecycle.publishError(work);
      if (error != null) {
        _publishing = false;
        _fieldError = error;
        _draftSavedLocally = true;
        _safeNotify();
        return FailureResult(ValidationError(error));
      }
    }
    final published = await _repository.publish(workId);
    published.fold(
      onSuccess: (value) {
        _loaded = value;
        _analytics.logEvent(
          'fan_work_published',
          parameters: {'workId': workId, 'type': _draft.type.name},
        );
        unawaited(_draftStore.delete(_localKey));
        if (workId != null) unawaited(_draftStore.delete(workId));
      },
      onFailure: (failure) {
        _failure = failure is ValidationError
            ? failure
            : NetworkError(failure.message);
        _draftSavedLocally = true;
      },
    );
    _publishing = false;
    _safeNotify();
    return published;
  }

  Future<Result<void>> deleteDraft() async {
    final workId = _draft.workId;
    if (workId == null || workId.isEmpty) {
      await _draftStore.delete(_localKey);
      return const Success<void>(null);
    }
    final result = await _repository.deleteDraft(workId);
    if (result.isSuccess) {
      await _draftStore.delete(workId);
      await _draftStore.delete('new');
    }
    return result;
  }

  Future<void> _persistLocal() async {
    _draftSavedLocally = true;
    await _draftStore.write(_localKey, _localMap());
  }

  /// The local draft uses [FanWorkDraft.toLocalMap], whose keys differ from the
  /// callable payload (`categoryId` vs `category`), so it must never be written
  /// with [FanWorkDraft.toCallableMap].
  Map<String, dynamic> _localMap() => _draft.toLocalMap();

  void _restoreLocal(Map<String, dynamic> data) {
    _draft = FanWorkDraft.fromLocalMap(data);
    if (_draft.type != FanWorkType.drawing || _draft.title.isNotEmpty) {
      _step = FanWorkEditorStep.details;
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final class _NoOpAnalytics implements Analytics {
  const _NoOpAnalytics();

  @override
  void logEvent(String name, {Map<String, Object?> parameters = const {}}) {}
}

final class FanWorkAnalyticsProvider extends ChangeNotifier {
  FanWorkAnalyticsProvider({required FanWorkRepository repository})
    : _repository = repository;

  final FanWorkRepository _repository;
  FanWorkAnalytics? _analytics;
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  String? _creatorId;
  bool _disposed = false;

  FanWorkAnalytics? get analytics => _analytics;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  String? get creatorId => _creatorId;

  Future<void> load(String creatorId) async {
    _creatorId = creatorId;
    _state = LoadingState.loading;
    _failure = null;
    notifyListeners();
    final result = await _repository.getAnalytics(creatorId);
    if (_disposed) return;
    result.fold(
      onSuccess: (analytics) {
        _analytics = analytics;
        _state = LoadingState.loaded;
        _failure = null;
      },
      onFailure: (failure) {
        _failure = failure;
        _state = failure is NetworkError
            ? LoadingState.offline
            : LoadingState.error;
      },
    );
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
