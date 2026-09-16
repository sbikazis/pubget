import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/game_models.dart';
import 'mafia_models.dart';
import 'mafia_phase.dart';
import 'mafia_repository.dart';
import 'mafia_roles.dart';

/// UI-facing Mafia state. Widgets must not contain Mafia business rules.
final class MafiaProvider extends ChangeNotifier {
  MafiaProvider({
    required MafiaRepository repository,
    Analytics analytics = const _NoOpAnalytics(),
  })  : _repository = repository,
        _analytics = analytics;

  final MafiaRepository _repository;
  final Analytics _analytics;

  StreamSubscription<Result<MafiaPrivateState?>>? _privateSub;
  String? _gameId;
  MafiaPrivateState? _private;
  LoadingState _privateState = LoadingState.initial;
  Failure? _failure;
  bool _busy = false;
  bool _pending = false;
  String? _feedback;
  bool _loggedStarted = false;
  bool _loggedCompleted = false;
  bool _disposed = false;

  MafiaPrivateState? get privateState => _private;
  LoadingState get privateLoading => _privateState;
  Failure? get failure => _failure;
  bool get busy => _busy;
  bool get pending => _pending;
  String? get feedback => _feedback;
  MafiaRole? get role => _private?.role;

  Future<void> open({required String gameId, required String userId}) async {
    _gameId = gameId;
    _privateState = LoadingState.loading;
    notifyListeners();
    await _privateSub?.cancel();
    _privateSub = _repository
        .watchPrivateState(gameId: gameId, userId: userId)
        .listen((result) {
      if (_disposed) return;
      result.fold(
        onSuccess: (value) {
          _private = value;
          _privateState = LoadingState.loaded;
          _failure = null;
        },
        onFailure: (failure) {
          _failure = failure;
          _privateState = failure is NetworkError
              ? LoadingState.offline
              : LoadingState.error;
        },
      );
      notifyListeners();
    });
  }

  Duration remaining(MafiaPublicState? publicState) {
    return publicState?.remaining(DateTime.now().toUtc()) ?? Duration.zero;
  }

  bool hasSubmittedNight(MafiaPublicState? publicState) {
    if (_private == null || publicState == null) return false;
    return _private!.submittedNightAction &&
        _private!.nightActionRound == publicState.roundNumber;
  }

  String? currentVote(MafiaPublicState? publicState) {
    if (_private == null || publicState == null) return null;
    if (_private!.voteRound != publicState.roundNumber) return null;
    return _private!.voteTargetId;
  }

  List<String> availableActionTypes({
    required PubgetGame game,
    required MafiaPublicState publicState,
    required GameParticipant? self,
  }) {
    if (game.status != GameStatus.active) return const [];
    if (self != null && (!self.isActive || !self.isAlive)) return const [];
    final role = _private?.role;
    if (role == null) return const [];
    if (publicState.phase == MafiaPhase.night &&
        role.nightActionType.isNotEmpty) {
      return <String>[role.nightActionType];
    }
    if (publicState.phase == MafiaPhase.voting) {
      return const <String>['mafia_vote'];
    }
    return const [];
  }

  void noteGame(PubgetGame game) {
    if (game.status == GameStatus.active && !_loggedStarted) {
      _loggedStarted = true;
      _analytics.logEvent(
        'mafia_game_started',
        parameters: {'gameId': game.id},
      );
      _analytics.logEvent(
        'mafia_phase_started',
        parameters: {'gameId': game.id},
      );
    }
    if (game.status == GameStatus.completed && !_loggedCompleted) {
      _loggedCompleted = true;
      _analytics.logEvent(
        'mafia_game_completed',
        parameters: {'gameId': game.id},
      );
    }
  }

  Future<Result<void>> submit({
    required String type,
    required String targetId,
  }) {
    final gameId = _gameId;
    if (gameId == null) {
      return Future<Result<void>>.value(
        const FailureResult(ValidationError('Game is not open.')),
      );
    }
    return _run(
      () => _repository.submitMafiaAction(
        gameId: gameId,
        type: type,
        targetId: targetId,
      ),
      onSuccess: () {
        _feedback = 'Action submitted.';
        _analytics.logEvent(
          type == 'mafia_vote' ? 'mafia_vote_submitted' : 'mafia_action_submitted',
          parameters: {'gameId': gameId},
        );
      },
    );
  }

  Future<Result<void>> advanceIfExpired(MafiaPublicState? publicState) async {
    final gameId = _gameId;
    if (gameId == null || publicState == null) {
      return const Success<void>(null);
    }
    final left = publicState.remaining(DateTime.now().toUtc());
    if (left == null || left > Duration.zero) {
      return const Success<void>(null);
    }
    return _run(() => _repository.advancePhase(gameId));
  }

  Future<Result<void>> _run(
    Future<Result<void>> Function() action, {
    VoidCallback? onSuccess,
  }) async {
    if (_busy) {
      return const FailureResult(
        ValidationError('A Mafia action is already in progress.'),
      );
    }
    _busy = true;
    _pending = true;
    _feedback = null;
    notifyListeners();
    final result = await action();
    result.fold(
      onSuccess: (_) => onSuccess?.call(),
      onFailure: (failure) {
        _failure = failure;
        if (failure is ValidationError &&
            failure.message.contains('already')) {
          _feedback = failure.message;
        }
      },
    );
    _busy = false;
    _pending = false;
    _safeNotify();
    return result;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_privateSub?.cancel());
    super.dispose();
  }
}

final class _NoOpAnalytics implements Analytics {
  const _NoOpAnalytics();

  @override
  void logEvent(String name, {Map<String, Object?> parameters = const {}}) {}
}
