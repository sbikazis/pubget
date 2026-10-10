import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/event_lifecycle.dart';
import '../models/event_models.dart';
import '../models/event_type_registry.dart';
import '../repositories/event_repository.dart';

final class EventListProvider extends ChangeNotifier {
  EventListProvider({required EventRepository repository})
    : _repository = repository;

  final EventRepository _repository;
  List<PubgetEvent> _active = const <PubgetEvent>[];
  List<PubgetEvent> _upcoming = const <PubgetEvent>[];
  List<PubgetEvent> _recent = const <PubgetEvent>[];
  List<PubgetEvent> _groupEvents = const <PubgetEvent>[];
  List<PubgetEvent> _mine = const <PubgetEvent>[];
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _disposed = false;

  List<PubgetEvent> get active => _active;
  List<PubgetEvent> get upcoming => _upcoming;
  List<PubgetEvent> get recent => _recent;
  List<PubgetEvent> get groupEvents => _groupEvents;
  List<PubgetEvent> get mine => _mine;
  LoadingState get state => _state;
  Failure? get failure => _failure;

  Future<void> loadHome() async {
    _state = _active.isEmpty ? LoadingState.loading : LoadingState.refreshing;
    notifyListeners();
    final results = await Future.wait([
      _repository.getActiveEvents(),
      _repository.getUpcomingEvents(),
      _repository.getRecentEvents(),
    ]);
    final active = results[0];
    final upcoming = results[1];
    final recent = results[2];
    if (!active.isSuccess) {
      _failure = active.failureOrNull;
      _state = _active.isEmpty ? LoadingState.error : LoadingState.loaded;
      _safeNotify();
      return;
    }
    _active = active.valueOrNull ?? const <PubgetEvent>[];
    _upcoming = upcoming.valueOrNull ?? const <PubgetEvent>[];
    _recent = recent.valueOrNull ?? const <PubgetEvent>[];
    _failure = null;
    _state = LoadingState.loaded;
    _safeNotify();
  }

  bool _loadingMore = false;
  bool _hasMoreActive = true;

  bool get hasMoreActive => _hasMoreActive;
  bool get loadingMore => _loadingMore;

  Future<void> loadMoreActive() async {
    if (_loadingMore || !_hasMoreActive) return;
    final last = _active.isEmpty ? null : _active.last;
    if (last == null) return;
    _loadingMore = true;
    notifyListeners();
    final result = await _repository.getActiveEvents(
      limit: 20,
      after: last,
    );
    result.fold(
      onSuccess: (more) {
        if (more.isEmpty) {
          _hasMoreActive = false;
        } else {
          final merged = <PubgetEvent>[..._active];
          for (final event in more) {
            if (!merged.any((item) => item.id == event.id)) merged.add(event);
          }
          _active = merged;
        }
      },
      onFailure: (_) => _hasMoreActive = false,
    );
    _loadingMore = false;
    _safeNotify();
  }

  Future<void> loadGroup(String groupId) async {
    _state = LoadingState.loading;
    notifyListeners();
    final result = await _repository.getGroupEvents(groupId: groupId);
    result.fold(
      onSuccess: (events) {
        _groupEvents = events;
        _state = events.isEmpty ? LoadingState.empty : LoadingState.loaded;
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

  Future<void> loadMine(String userId) async {
    final result = await _repository.getMyEvents(userId: userId);
    result.fold(onSuccess: (events) => _mine = events, onFailure: (_) {});
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

final class EventProvider extends ChangeNotifier {
  EventProvider({
    required EventRepository repository,
    Analytics analytics = const _NoOpAnalytics(),
  }) : _repository = repository,
       _analytics = analytics;

  final EventRepository _repository;
  final Analytics _analytics;
  StreamSubscription<Result<PubgetEvent>>? _subscription;
  StreamSubscription<Result<List<EventComment>>>? _commentsSubscription;
  PubgetEvent? _event;
  EventResponse? _myResponse;
  String? _myReaction;
  List<EventComment> _comments = const <EventComment>[];
  EventAnalytics? _analyticsData;
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _submitting = false;
  bool _loggedResult = false;
  bool _loggedCompleted = false;
  String? _viewerId;
  bool _disposed = false;

  PubgetEvent? get event => _event;
  EventResponse? get myResponse => _myResponse;
  String? get myReaction => _myReaction;
  List<EventComment> get comments => _comments;
  EventAnalytics? get analyticsData => _analyticsData;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get submitting => _submitting;
  bool get hasSubmitted => _myResponse != null;

  /// Resets per-event state so a reused provider never bleeds data between
  /// events on the details screen.
  void reset() {
    unawaited(_subscription?.cancel());
    unawaited(_commentsSubscription?.cancel());
    _subscription = null;
    _commentsSubscription = null;
    _event = null;
    _myResponse = null;
    _myReaction = null;
    _comments = const <EventComment>[];
    _analyticsData = null;
    _failure = null;
    _state = LoadingState.initial;
    _loggedResult = false;
    _loggedCompleted = false;
    _viewerId = null;
  }

  Future<void> open({required String eventId, required String userId}) async {
    reset();
    _state = LoadingState.loading;
    notifyListeners();
    _analytics.logEvent('event_viewed', parameters: {'eventId': eventId});
    _viewerId = userId;
    _subscription = _repository.watchEvent(eventId).listen((result) {
      if (_disposed) return;
      result.fold(
        onSuccess: (event) {
          _event = event;
          _state = LoadingState.loaded;
          _failure = null;
          if (event.isHistorical && event.result != null && !_loggedResult) {
            _loggedResult = true;
            _analytics.logEvent(
              'event_result_viewed',
              parameters: {'eventId': event.id},
            );
          }
          if (event.status == EventStatus.ended && !_loggedCompleted) {
            _loggedCompleted = true;
            _analytics.logEvent(
              'event_completed',
              parameters: {'eventId': event.id},
            );
          }
        },
        onFailure: (failure) {
          _failure = failure;
          _state = failure is NetworkError
              ? LoadingState.offline
              : (failure is NotFoundError
                    ? LoadingState.empty
                    : LoadingState.error);
        },
      );
      notifyListeners();
    });
    _watchComments(eventId);
    final myResponse = await _repository.getMyResponse(
      eventId: eventId,
      userId: userId,
    );
    final myReaction = await _repository.getMyReaction(
      eventId: eventId,
      userId: userId,
    );
    _myResponse = myResponse.valueOrNull;
    _myReaction = myReaction.valueOrNull;
    _safeNotify();
  }

  void _watchComments(String eventId) {
    unawaited(_commentsSubscription?.cancel());
    _commentsSubscription = _repository.watchComments(eventId).listen((result) {
      if (_disposed) return;
      result.fold(
        onSuccess: (comments) => _comments = comments,
        onFailure: (failure) => _failure = failure,
      );
      _safeNotify();
    });
  }

  Future<Result<void>> addComment(String eventId, String text) async {
    if (_submitting) {
      return const FailureResult(
        ValidationError('An event action is already in progress.'),
      );
    }
    _submitting = true;
    notifyListeners();
    final result = await _repository.addComment(
      eventId: eventId,
      text: text,
    );
    if (result.isSuccess) {
      _analytics.logEvent('event_comment', parameters: {'eventId': eventId});
    } else {
      _failure = result.failureOrNull;
    }
    _submitting = false;
    _safeNotify();
    return result;
  }

  Future<Result<void>> react(String eventId, String reaction) async {
    final result = await _repository.react(
      eventId: eventId,
      reaction: reaction,
    );
    if (result.isSuccess) {
      _analytics.logEvent('event_reacted', parameters: {'eventId': eventId});
      final uid = _viewerId;
      if (uid != null && uid.isNotEmpty) {
        _myReaction = (await _repository.getMyReaction(
          eventId: eventId,
          userId: uid,
        )).valueOrNull;
        _safeNotify();
      }
    } else {
      _failure = result.failureOrNull;
    }
    _safeNotify();
    return result;
  }

  /// §14.6 — files a moderation report against this event.
  Future<Result<void>> report({
    required String eventId,
    required String category,
    String detail = '',
  }) async {
    final result = await _repository.reportEvent(
      eventId: eventId,
      category: category,
      detail: detail,
    );
    if (result.isSuccess) {
      _analytics.logEvent('event_reported', parameters: {'eventId': eventId});
    } else {
      _failure = result.failureOrNull;
    }
    _safeNotify();
    return result;
  }

  Future<Result<EventResult>> resolve({
    required String eventId,
    String? winnerOptionId,
    List<String>? winnerIds,
  }) async {    return _repository.resolve(
      eventId: eventId,
      winnerOptionId: winnerOptionId,
      winnerIds: winnerIds,
    );
  }

  Future<Result<EventAnalytics>> openAnalytics(String eventId) async {
    final result = await _repository.getAnalytics(eventId);
    if (result.isSuccess) {
      _analyticsData = result.valueOrNull;
      _analytics.logEvent(
        'event_analytics_viewed',
        parameters: {'eventId': eventId},
      );
    }
    _safeNotify();
    return result;
  }

  Future<Result<void>> join(String eventId) async {
    if (_submitting) {
      return const FailureResult(
        ValidationError('An event action is already in progress.'),
      );
    }
    _submitting = true;
    notifyListeners();
    final result = await _repository.join(eventId);
    if (result.isSuccess) {
      _analytics.logEvent('event_joined', parameters: {'eventId': eventId});
    } else {
      _failure = result.failureOrNull;
    }
    _submitting = false;
    _safeNotify();
    return result;
  }

  Future<Result<void>> leave(String eventId) async {
    if (_submitting) {
      return const FailureResult(
        ValidationError('An event action is already in progress.'),
      );
    }
    _submitting = true;
    notifyListeners();
    final result = await _repository.leave(eventId);
    if (!result.isSuccess) _failure = result.failureOrNull;
    _submitting = false;
    _safeNotify();
    return result;
  }

  Future<Result<void>> submit({
    required String eventId,
    required Map<String, dynamic> responseData,
  }) async {
    if (_submitting) {
      return const FailureResult(
        ValidationError('Submission already in progress.'),
      );
    }
    _submitting = true;
    notifyListeners();
    final result = await _repository.submit(
      eventId: eventId,
      responseData: responseData,
    );
    result.fold(
      onSuccess: (_) {
        _analytics.logEvent(
          'event_participation',
          parameters: {'eventId': eventId},
        );
        _myResponse = EventResponse(
          eventId: eventId,
          userId: '',
          submittedAt: DateTime.now(),
          responseData: responseData,
        );
      },
      onFailure: (failure) => _failure = failure,
    );
    _submitting = false;
    _safeNotify();
    return result;
  }

  Future<Result<void>> cancel(String eventId) async {
    final result = await _repository.cancel(eventId);
    if (result.isSuccess) {
      _analytics.logEvent('event_cancelled', parameters: {'eventId': eventId});
    }
    return result;
  }

  Future<Result<void>> end(String eventId) => _repository.end(eventId);

  Future<Result<void>> archive(String eventId) => _repository.archive(eventId);

  /// Extends a live event to more groups (or to global) without duplicating it.
  Future<Result<void>> crosspost({
    required String eventId,
    List<String> groupIds = const <String>[],
    bool toGlobal = false,
  }) async {
    final result = await _repository.crosspost(
      eventId: eventId,
      groupIds: groupIds,
      toGlobal: toGlobal,
    );
    if (result.isSuccess) {
      _analytics.logEvent(
        'event_crossposted',
        parameters: {'eventId': eventId, 'toGlobal': toGlobal},
      );
    } else {
      _failure = result.failureOrNull;
      _safeNotify();
    }
    return result;
  }

  void share(String eventId) {
    _analytics.logEvent('event_shared', parameters: {'eventId': eventId});
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    unawaited(_commentsSubscription?.cancel());
    super.dispose();
  }
}

final class EventBuilderProvider extends ChangeNotifier {
  EventBuilderProvider({
    required EventRepository repository,
    Analytics analytics = const _NoOpAnalytics(),
  }) : _repository = repository,
       _analytics = analytics;

  final EventRepository _repository;
  final Analytics _analytics;
  EventDraft _draft = const EventDraft();
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _saving = false;
  bool _disposed = false;
  EventCreationQuota? _quota;
  EventPreview? _preview;
  bool _previewing = false;

  EventDraft get draft => _draft;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get saving => _saving;
  EventCreationQuota? get quota => _quota;

  void start({
    String? groupId,
    String? templateId,
    EventScope scope = EventScope.group,
    List<String> groupIds = const <String>[],
  }) {
    var next = EventDraft(
      groupId: groupId,
      groupIds: groupIds,
      scope: scope,
      templateId: templateId,
    );
    if (templateId != null) {
      final type = EventTypeRegistry.templates[templateId];
      if (type != null) {
        next = next.copyWith(type: type, templateId: templateId);
      }
    }
    final now = DateTime.now();
    _draft = next.copyWith(
      startAt: now,
      endAt: now.add(const Duration(hours: 24)),
    );
    _state = LoadingState.loaded;
    notifyListeners();
    unawaited(_loadQuota());
  }

  Future<void> _loadQuota() async {
    final result = await _repository.getCreationQuota();
    if (_disposed) return;
    if (result.isSuccess) {
      _quota = result.valueOrNull;
      notifyListeners();
    } else {
      _quota = null;
    }
  }

  /// Resolves remaining allowance when offline/unavailable: the server is the
  /// real gatekeeper and will reject an over-limit publish.
  int get remainingAllowance =>
      _quota?.remaining ?? EventLifecycle.unknownQuotaRemaining;

  /// Restores the newest draft for this creator. Optional [groupId] and
  /// [scope] keep a global entry from silently adopting a group draft (and
  /// vice versa).
  Future<void> restoreDraft({
    required String userId,
    String? groupId,
    EventScope? scope,
  }) async {
    final result = await _repository.getMyDrafts(userId: userId);
    final drafts = result.valueOrNull ?? const <PubgetEvent>[];
    PubgetEvent? match;
    for (final draft in drafts) {
      if (groupId != null && draft.groupId != groupId) continue;
      if (scope != null && draft.scope != scope) continue;
      match = draft;
      break;
    }
    if (match == null) return;
    _draft = EventDraft.fromEvent(match);
    _state = LoadingState.loaded;
    notifyListeners();
  }

  void update(EventDraft draft) {
    _draft = draft;
    // Any edit invalidates the last server-side preview.
    _preview = null;
    _failure = null;
    notifyListeners();
  }

  void clearFailure() {
    _failure = null;
    notifyListeners();
  }

  /// Saves the draft when needed, then asks the server for the normalized
  /// preview. A preview must be taken before publish (spec 14.2).
  Future<Result<EventPreview>> preview() async {
    final validation = EventValidation.draft(_draft);
    if (validation != null) {
      _failure = ValidationError(validation);
      notifyListeners();
      return FailureResult(ValidationError(validation));
    }
    if (_draft.eventId == null) {
      final saved = await saveDraft();
      if (saved.valueOrNull == null) {
        return FailureResult(saved.failureOrNull ?? const ValidationError());
      }
    }
    _previewing = true;
    _failure = null;
    notifyListeners();
    final result = await _repository.preview(eventId: _draft.eventId!);
    _previewing = false;
    result.fold(
      onSuccess: (value) => _preview = value,
      onFailure: (failure) {
        _preview = null;
        _failure = failure;
      },
    );
    notifyListeners();
    return result;
  }

  EventPreview? get previewData => _preview;
  bool get previewing => _previewing;

  Future<Result<String>> saveDraft() async {
    final validation = EventValidation.draft(_draft);
    if (validation != null) {
      _failure = ValidationError(validation);
      notifyListeners();
      return FailureResult(ValidationError(validation));
    }
    _saving = true;
    notifyListeners();
    final result = await _repository.saveDraft(_draft);
    result.fold(
      onSuccess: (id) {
        _draft = _draft.copyWith(eventId: id);
      },
      onFailure: (failure) => _failure = failure,
    );
    _saving = false;
    notifyListeners();
    return result;
  }

  Future<Result<PubgetEvent>> publish() async {
    final validation = EventValidation.publish(_draft);
    if (validation != null) {
      _failure = ValidationError(validation);
      notifyListeners();
      return FailureResult(ValidationError(validation));
    }
    if (_quota != null && _quota!.exhausted) {
      _failure = const ValidationError('ev.limitReached');
      notifyListeners();
      return FailureResult(_failure!);
    }
    final start = _draft.startAt ?? DateTime.now();
    final end = _draft.endAt ?? start.add(const Duration(hours: 24));
    final window = EventLifecycle.validateWindow(start, end);
    if (window != null) {
      _failure = ValidationError(window);
      notifyListeners();
      return FailureResult(ValidationError(window));
    }
    final saved = _draft.eventId == null
        ? await saveDraft()
        : Success(_draft.eventId!);
    final id = saved.valueOrNull;
    if (id == null) {
      return FailureResult(saved.failureOrNull ?? const ValidationError());
    }
    _saving = true;
    notifyListeners();
    final published = await _repository.publish(
      eventId: id,
      startAt: start,
      endAt: end,
    );
    _saving = false;
    if (published.isSuccess) {
      _analytics.logEvent(
        'event_created',
        parameters: {'eventId': id, 'type': _draft.type.name},
      );
    } else {
      _failure = published.failureOrNull;
    }
    notifyListeners();
    return published;
  }

  Future<void> abandon() async {
    _analytics.logEvent(
      'event_creation_abandoned',
      parameters: {'type': _draft.type.name},
    );
    if (_draft.eventId != null) {
      await _repository.deleteDraft(_draft.eventId!);
    }
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
