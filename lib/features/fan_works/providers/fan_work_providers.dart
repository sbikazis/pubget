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
  bool _disposed = false;

  List<FanWork> get items => List<FanWork>.unmodifiable(_items);
  List<FanWork> get drafts => _drafts;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get hasMore => _hasMore;
  bool get offlineCached => _offlineCached;
  FanWorkType? get type => _type;
  String? get animeId => _animeId;

  Future<void> load({
    FanWorkType? type,
    String? animeId,
    bool refresh = false,
  }) async {
    final typeChanged = type != _type || animeId != _animeId;
    if (typeChanged || refresh) {
      _type = type;
      _animeId = animeId;
      _items.clear();
      _seenIds.clear();
      _hasMore = true;
    }
    _state = _items.isEmpty ? LoadingState.loading : LoadingState.refreshing;
    _failure = null;
    _offlineCached = false;
    notifyListeners();
    final result = await _repository.getPublicFeed(
      type: _type,
      animeId: _animeId,
    );
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
    final result = await _repository.getPublicFeed(
      type: _type,
      animeId: _animeId,
      after: _items.last,
    );
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
  bool _acting = false;
  bool _disposed = false;

  FanWork? get work => _work;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get liked => _liked;
  bool get bookmarked => _bookmarked;
  bool get acting => _acting;

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
    _liked = liked.valueOrNull ?? false;
    _bookmarked = bookmarked.valueOrNull ?? false;
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
      final result = await _repository.bookmark(
        workId: workId,
        bookmark: next,
      );
      if (result.isSuccess) _bookmarked = next;
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

  Future<Result<void>> uploadImage({
    required List<int> bytes,
    required String contentType,
    required FanWorkMediaRole role,
    String caption = '',
  }) async {
    final mediaError = FanWorkLifecycle.mediaError(
      contentType: contentType,
      size: bytes.length,
    );
    if (mediaError != null) {
      _fieldError = mediaError;
      notifyListeners();
      return FailureResult(ValidationError(mediaError));
    }
    _uploading = true;
    _failure = null;
    notifyListeners();
    var workId = _draft.workId;
    if (workId == null || workId.isEmpty) {
      final saved = await _repository.saveDraft(_draft);
      if (!saved.isSuccess) {
        _uploading = false;
        _failure = saved.failureOrNull;
        _draftSavedLocally = true;
        _safeNotify();
        return FailureResult(_failure ?? const UnknownError());
      }
      workId = saved.valueOrNull;
      _draft = _draft.copyWith(workId: workId);
    }
    final ticket = await _repository.startMediaUpload(
      workId: workId!,
      contentType: contentType,
    );
    if (!ticket.isSuccess) {
      _uploading = false;
      _failure = ticket.failureOrNull;
      _draftSavedLocally = true;
      _safeNotify();
      return FailureResult(_failure ?? const UnknownError());
    }
    final upload = ticket.valueOrNull!;
    final bytesResult = await _repository.uploadMediaBytes(
      ticket: upload,
      bytes: bytes,
      contentType: contentType,
    );
    if (!bytesResult.isSuccess) {
      _uploading = false;
      _failure = bytesResult.failureOrNull ??
          const NetworkError(FanWorkStrings.uploadFailed);
      _draftSavedLocally = true;
      _safeNotify();
      return bytesResult;
    }
    final confirmed = await _repository.confirmMedia(
      workId: workId,
      mediaId: upload.mediaId,
      path: upload.path,
      role: role,
      caption: caption,
    );
    if (confirmed.isSuccess) {
      if (role == FanWorkMediaRole.page) {
        _draft = _draft.copyWith(
          pageIds: [..._draft.pageIds, upload.mediaId],
          pageCaptions: {..._draft.pageCaptions, upload.mediaId: caption},
        );
      } else if (role == FanWorkMediaRole.image ||
          role == FanWorkMediaRole.extra) {
        _draft = _draft.copyWith(imageIds: [..._draft.imageIds, upload.mediaId]);
      }
      await _persistLocal();
      final refreshed = await _repository.getWork(workId);
      _loaded = refreshed.valueOrNull ?? _loaded;
    } else {
      _failure = confirmed.failureOrNull;
      _draftSavedLocally = true;
    }
    _uploading = false;
    _safeNotify();
    return confirmed;
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

  Map<String, dynamic> _localMap() => _draft.toCallableMap();

  void _restoreLocal(Map<String, dynamic> data) {
    _draft = FanWorkDraft(
      workId: data['workId'] as String?,
      type: fanWorkTypeFrom(data['type']),
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      tags: (data['tags'] as List<Object?>?)?.whereType<String>().toList() ??
          const <String>[],
      animeId: data['animeId'] as String? ?? '',
      animeTitle: data['animeTitle'] as String? ?? '',
      characterIds:
          (data['characterIds'] as List<Object?>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      body: data['body'] as String? ?? '',
      name: data['name'] as String? ?? '',
      personality: data['personality'] as String? ?? '',
      abilities: data['abilities'] as String? ?? '',
      background: data['background'] as String? ?? '',
      lore: data['lore'] as String? ?? '',
      pageIds:
          (data['pageIds'] as List<Object?>?)?.whereType<String>().toList() ??
          const <String>[],
      imageIds:
          (data['imageIds'] as List<Object?>?)?.whereType<String>().toList() ??
          const <String>[],
    );
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
