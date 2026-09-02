import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../engine/game_engine.dart';
import '../models/game_errors.dart';
import '../models/game_lifecycle.dart';
import '../models/game_models.dart';
import '../repositories/game_repository.dart';

final class GameListProvider extends ChangeNotifier {
  GameListProvider({required GameRepository repository})
    : _repository = repository;

  final GameRepository _repository;
  List<PubgetGame> _active = const <PubgetGame>[];
  List<PubgetGame> _waiting = const <PubgetGame>[];
  List<PubgetGame> _groupGames = const <PubgetGame>[];
  List<PubgetGame> _mine = const <PubgetGame>[];
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _disposed = false;

  List<PubgetGame> get active => _active;
  List<PubgetGame> get waiting => _waiting;
  List<PubgetGame> get groupGames => _groupGames;
  List<PubgetGame> get mine => _mine;
  LoadingState get state => _state;
  Failure? get failure => _failure;

  Future<void> loadHome() async {
    _state = _active.isEmpty && _waiting.isEmpty
        ? LoadingState.loading
        : LoadingState.refreshing;
    notifyListeners();
    final results = await Future.wait([
      _repository.getActiveGames(),
      _repository.getWaitingGames(),
    ]);
    final active = results[0];
    final waiting = results[1];
    if (!active.isSuccess) {
      _failure = active.failureOrNull;
      _state = _active.isEmpty ? LoadingState.error : LoadingState.loaded;
      _safeNotify();
      return;
    }
    _active = active.valueOrNull ?? const <PubgetGame>[];
    _waiting = waiting.valueOrNull ?? const <PubgetGame>[];
    _failure = null;
    _state = LoadingState.loaded;
    _safeNotify();
  }

  Future<void> loadGroup(String groupId) async {
    _state = LoadingState.loading;
    notifyListeners();
    final result = await _repository.getGroupGames(groupId: groupId);
    result.fold(
      onSuccess: (games) {
        _groupGames = games;
        _state = games.isEmpty ? LoadingState.empty : LoadingState.loaded;
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
    final result = await _repository.getMyGames(userId: userId);
    result.fold(onSuccess: (games) => _mine = games, onFailure: (_) {});
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

final class GameProvider extends ChangeNotifier {
  GameProvider({
    required GameRepository repository,
    Analytics analytics = const _NoOpAnalytics(),
  }) : _repository = repository,
       _analytics = analytics;

  final GameRepository _repository;
  final Analytics _analytics;
  StreamSubscription<Result<PubgetGame>>? _gameSub;
  StreamSubscription<Result<List<GameParticipant>>>? _peopleSub;
  PubgetGame? _game;
  List<GameParticipant> _participants = const <GameParticipant>[];
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _busy = false;
  String? _actionFeedback;
  bool _loggedCompleted = false;
  bool _disposed = false;

  PubgetGame? get game => _game;
  List<GameParticipant> get participants => _participants;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get busy => _busy;
  String? get actionFeedback => _actionFeedback;

  bool isParticipant(String userId) => _participants.any(
    (item) => item.userId == userId && item.isActive,
  );

  Future<void> open(String gameId) async {
    _state = LoadingState.loading;
    notifyListeners();
    await _gameSub?.cancel();
    await _peopleSub?.cancel();
    _gameSub = _repository.watchGame(gameId).listen((result) {
      if (_disposed) return;
      result.fold(
        onSuccess: (game) {
          _game = game;
          _state = LoadingState.loaded;
          _failure = null;
          if (game.status == GameStatus.completed && !_loggedCompleted) {
            _loggedCompleted = true;
            _analytics.logEvent(
              'game_completed',
              parameters: {'gameId': game.id, 'type': game.type.name},
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
    _peopleSub = _repository.watchParticipants(gameId).listen((result) {
      if (_disposed) return;
      result.fold(
        onSuccess: (people) => _participants = people,
        onFailure: (_) {},
      );
      notifyListeners();
    });
  }

  Future<Result<void>> join(String gameId) => _run(
    () => _repository.join(gameId),
    onSuccess: () {
      _analytics.logEvent('game_joined', parameters: {'gameId': gameId});
      if (_game?.type == GameType.mafia) {
        _analytics.logEvent('mafia_game_joined', parameters: {'gameId': gameId});
      }
    },
  );

  Future<Result<void>> leave(String gameId) =>
      _run(() => _repository.leave(gameId));

  Future<Result<void>> start(String gameId) => _run(
    () => _repository.start(gameId),
    onSuccess: () {
      _analytics.logEvent(
        'game_started',
        parameters: {'gameId': gameId},
      );
      if (_game?.type == GameType.mafia) {
        _analytics.logEvent(
          'mafia_game_started',
          parameters: {'gameId': gameId},
        );
      }
    },
  );

  Future<Result<void>> pause(String gameId) =>
      _run(() => _repository.pause(gameId));

  Future<Result<void>> resume(String gameId) =>
      _run(() => _repository.resume(gameId));

  Future<Result<void>> end(String gameId) =>
      _run(() => _repository.end(gameId));

  Future<Result<void>> cancel(String gameId) =>
      _run(() => _repository.cancel(gameId));

  Future<Result<void>> submitAction({
    required String gameId,
    required String actionType,
    Map<String, dynamic> payload = const <String, dynamic>{},
    String? clientActionId,
  }) {
    final error = GameValidation.action(
      gameId: gameId,
      playerId: 'self',
      actionType: actionType,
      payload: payload,
      clientActionId: clientActionId,
    );
    if (error != null) {
      _failure = ValidationError(error);
      notifyListeners();
      return Future<Result<void>>.value(FailureResult(ValidationError(error)));
    }
    return _run(
      () => _repository.submitAction(
        gameId: gameId,
        actionType: actionType,
        payload: payload,
        clientActionId: clientActionId,
      ),
      onSuccess: () {
        _actionFeedback = 'Action submitted.';
        _analytics.logEvent(
          'game_action_submitted',
          parameters: {'gameId': gameId, 'actionType': actionType},
        );
      },
    );
  }

  Future<Result<void>> _run(
    Future<Result<void>> Function() action, {
    VoidCallback? onSuccess,
  }) async {
    if (_busy) {
      return const FailureResult(
        ValidationError('A game action is already in progress.'),
      );
    }
    _busy = true;
    _actionFeedback = null;
    notifyListeners();
    final result = await action();
    result.fold(
      onSuccess: (_) => onSuccess?.call(),
      onFailure: (failure) => _failure = failure,
    );
    _busy = false;
    _safeNotify();
    return result;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_gameSub?.cancel());
    unawaited(_peopleSub?.cancel());
    super.dispose();
  }
}

final class GameCreateProvider extends ChangeNotifier {
  GameCreateProvider({
    required GameRepository repository,
    Analytics analytics = const _NoOpAnalytics(),
  }) : _repository = repository,
       _analytics = analytics;

  final GameRepository _repository;
  final Analytics _analytics;
  GameDraft _draft = const GameDraft();
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _saving = false;

  GameDraft get draft => _draft;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get saving => _saving;

  void start({String? groupId}) {
    _draft = GameDraft(groupId: groupId);
    _state = LoadingState.loaded;
    notifyListeners();
  }

  void update(GameDraft draft) {
    _draft = draft;
    notifyListeners();
  }

  Future<Result<PubgetGame>> create() async {
    final validation = GameValidation.draft(_draft);
    if (validation != null) {
      _failure = ValidationError(validation);
      notifyListeners();
      return FailureResult(ValidationError(validation));
    }
    try {
      GameEngine.assertCanCreate(_draft.type);
    } on GameException catch (error) {
      _failure = error.toFailure();
      notifyListeners();
      return FailureResult(error.toFailure());
    }
    _saving = true;
    notifyListeners();
    final result = await _repository.create(_draft);
    _saving = false;
    result.fold(
      onSuccess: (game) {
        _draft = _draft.copyWith(gameId: game.id);
        _analytics.logEvent(
          'game_created',
          parameters: {'gameId': game.id, 'type': game.type.name},
        );
        if (game.type == GameType.mafia) {
          _analytics.logEvent(
            'mafia_game_created',
            parameters: {'gameId': game.id},
          );
        }
      },
      onFailure: (failure) => _failure = failure,
    );
    notifyListeners();
    return result;
  }
}

final class _NoOpAnalytics implements Analytics {
  const _NoOpAnalytics();

  @override
  void logEvent(String name, {Map<String, Object?> parameters = const {}}) {}
}
