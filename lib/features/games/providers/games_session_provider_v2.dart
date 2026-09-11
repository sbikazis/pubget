import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/games_schema_v2.dart';
import '../repositories/games_repository_v2.dart';

enum GameReconnectRoute { chat, waitingRoom, gameRoom, result }

GameReconnectRoute routeForSession(GameSessionV2 session) =>
    switch (session.status) {
      GameLifecycleStatusV2.created ||
      GameLifecycleStatusV2.waiting => GameReconnectRoute.waitingRoom,
      GameLifecycleStatusV2.starting ||
      GameLifecycleStatusV2.inProgress => GameReconnectRoute.gameRoom,
      GameLifecycleStatusV2.completed ||
      GameLifecycleStatusV2.cancelled => GameReconnectRoute.result,
    };

/// Owns one targeted listener and ignores late emissions from prior sessions.
final class GamesSessionProviderV2 extends ChangeNotifier {
  GamesSessionProviderV2(this._repository);
  final GamesRepositoryV2 _repository;
  StreamSubscription<Result<GameSessionV2>>? _subscription;
  GameSessionV2? _session;
  String? _sessionId;
  bool _disposed = false;

  GameSessionV2? get session => _session;
  GameReconnectRoute? get reconnectRoute =>
      _session == null ? null : routeForSession(_session!);

  Future<void> open(String gameId) async {
    final token = gameId;
    await _subscription?.cancel();
    _sessionId = token;
    _session = null;
    _safeNotify();
    _subscription = _repository.watchSession(gameId).listen((result) {
      if (_disposed || _sessionId != token) return;
      result.fold(
        onSuccess: (session) {
          if (_sessionId == token) _session = session;
        },
        onFailure: (_) {},
      );
      _safeNotify();
    });
  }

  Future<Result<void>> send(GameCommandRequest request) async {
    final session = _session;
    if (session == null || _sessionId != request.gameId) {
      return const FailureResult(ValidationError('No active game session.'));
    }
    if (request.expectedVersion != session.version) {
      return const FailureResult(
        ValidationError('Game changed; refresh before retrying.'),
      );
    }
    return _repository.command(request);
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

/// Canonical, debounced lookup hook used by character/anime pickers.
final class DebouncedCanonicalSearch<T> {
  DebouncedCanonicalSearch({
    required this.lookup,
    this.delay = const Duration(milliseconds: 300),
  });
  final Future<List<T>> Function(String canonicalQuery) lookup;
  final Duration delay;
  Timer? _timer;

  Future<List<T>> search(String query) {
    final completer = Completer<List<T>>();
    _timer?.cancel();
    _timer = Timer(delay, () async {
      try {
        completer.complete(await lookup(_canonicalize(query)));
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  static String _canonicalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  void dispose() => _timer?.cancel();
}
