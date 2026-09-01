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
  PubgetEvent? _event;
  EventResponse? _myResponse;
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _submitting = false;
  bool _loggedResult = false;
  bool _loggedCompleted = false;
  bool _disposed = false;

  PubgetEvent? get event => _event;
  EventResponse? get myResponse => _myResponse;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get submitting => _submitting;
  bool get hasSubmitted => _myResponse != null;

  Future<void> open({required String eventId, required String userId}) async {
    _state = LoadingState.loading;
    notifyListeners();
    _analytics.logEvent('event_viewed', parameters: {'eventId': eventId});
    await _subscription?.cancel();
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
    final response = await _repository.getMyResponse(
      eventId: eventId,
      userId: userId,
    );
    _myResponse = response.valueOrNull;
    _safeNotify();
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

  EventDraft get draft => _draft;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get saving => _saving;

  void start({String? groupId, String? templateId}) {
    var next = EventDraft(groupId: groupId, templateId: templateId);
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
  }

  Future<void> restoreDraft({required String userId, String? groupId}) async {
    final result = await _repository.getMyDrafts(userId: userId);
    final drafts = result.valueOrNull ?? const <PubgetEvent>[];
    PubgetEvent? match;
    for (final draft in drafts) {
      if (groupId == null || draft.groupId == groupId) {
        match = draft;
        break;
      }
    }
    if (match == null) return;
    _draft = EventDraft.fromEvent(match);
    _state = LoadingState.loaded;
    notifyListeners();
  }

  void update(EventDraft draft) {
    _draft = draft;
    notifyListeners();
  }

  Future<Result<String>> saveDraft() async {
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
    final validation = EventValidation.draft(_draft);
    if (validation != null) {
      _failure = ValidationError(validation);
      notifyListeners();
      return FailureResult(ValidationError(validation));
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
}

final class _NoOpAnalytics implements Analytics {
  const _NoOpAnalytics();

  @override
  void logEvent(String name, {Map<String, Object?> parameters = const {}}) {}
}
