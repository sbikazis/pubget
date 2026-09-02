import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/mafia_models.dart';
import '../repositories/mafia_repository.dart';

final class MafiaProvider extends ChangeNotifier {
  MafiaProvider({required MafiaRepository repository})
    : _repository = repository;

  final MafiaRepository _repository;
  StreamSubscription<Result<MafiaGame>>? _gameSub;
  StreamSubscription<Result<List<MafiaPlayer>>>? _playersSub;
  StreamSubscription<Result<MafiaPrivateState>>? _privateSub;
  StreamSubscription<Result<List<Map<String, dynamic>>>>? _eventsSub;
  StreamSubscription<Result<List<Map<String, dynamic>>>>? _chatSub;
  Timer? _heartbeat;
  MafiaGame? _game;
  List<MafiaPlayer> _players = const <MafiaPlayer>[];
  MafiaPrivateState _private = const MafiaPrivateState();
  List<Map<String, dynamic>> _events = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _chat = const <Map<String, dynamic>>[];
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _busy = false;
  bool _disposed = false;
  String? _userId;
  String? _gameId;

  MafiaGame? get game => _game;
  List<MafiaPlayer> get players => _players;
  MafiaPrivateState get privateState => _private;
  List<Map<String, dynamic>> get events => _events;
  List<Map<String, dynamic>> get chat => _chat;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get busy => _busy;

  MafiaPlayer? get self {
    for (final item in _players) {
      if (item.userId == _userId) return item;
    }
    return null;
  }

  Future<void> open({required String gameId, required String userId}) async {
    _gameId = gameId;
    _userId = userId;
    _state = LoadingState.loading;
    notifyListeners();
    await _cancel();
    _gameSub = _repository.watchGame(gameId).listen((result) {
      if (_disposed) return;
      result.fold(
        onSuccess: (game) {
          _game = game;
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
      notifyListeners();
    });
    _playersSub = _repository.watchPlayers(gameId).listen((result) {
      result.fold(onSuccess: (value) => _players = value, onFailure: (_) {});
      notifyListeners();
    });
    _privateSub = _repository
        .watchPrivate(gameId: gameId, userId: userId)
        .listen((result) {
          result.fold(
            onSuccess: (value) => _private = value,
            onFailure: (_) {},
          );
          notifyListeners();
        });
    _eventsSub = _repository.watchEvents(gameId).listen((result) {
      result.fold(onSuccess: (value) => _events = value, onFailure: (_) {});
      notifyListeners();
    });
    _chatSub = _repository.watchChat(gameId).listen((result) {
      result.fold(onSuccess: (value) => _chat = value, onFailure: (_) {});
      notifyListeners();
    });
    _heartbeat = Timer.periodic(const Duration(seconds: 25), (_) {
      unawaited(_repository.heartbeat(gameId));
    });
  }

  Future<Result<String>> create({
    required String groupId,
    int minPlayers = 4,
    int maxPlayers = 8,
  }) {
    return _repository.create(
      groupId: groupId,
      minPlayers: minPlayers,
      maxPlayers: maxPlayers,
    );
  }

  Future<Result<void>> join() => _run(() => _repository.join(_gameId!));

  Future<Result<void>> start() => _run(() => _repository.start(_gameId!));

  Future<Result<void>> nightAction(String targetId) {
    final night = _game?.currentNight ?? 0;
    return _run(
      () => _repository.submitNightAction(
        gameId: _gameId!,
        targetId: targetId,
        nightNumber: night,
      ),
    );
  }

  Future<Result<void>> vote(String targetId) {
    final day = _game?.currentDay ?? 0;
    return _run(
      () => _repository.submitVote(
        gameId: _gameId!,
        targetId: targetId,
        dayNumber: day,
      ),
    );
  }

  Future<Result<void>> sendChat(String text) {
    final me = self;
    if (me == null) {
      return Future<Result<void>>.value(
        const FailureResult(ValidationError('You are not in this game.')),
      );
    }
    return _run(
      () => _repository.sendChat(gameId: _gameId!, text: text, self: me),
    );
  }

  void bindUser(String? userId) {
    if (_userId == userId) return;
    reset();
    _userId = userId;
  }

  void reset() {
    unawaited(_cancel());
    _game = null;
    _players = const <MafiaPlayer>[];
    _private = const MafiaPrivateState();
    _events = const <Map<String, dynamic>>[];
    _chat = const <Map<String, dynamic>>[];
    _failure = null;
    _busy = false;
    _gameId = null;
    _state = LoadingState.initial;
    if (!_disposed) notifyListeners();
  }

  Future<Result<void>> _run(Future<Result<void>> Function() action) async {
    if (_busy) {
      return const FailureResult(
        ValidationError('A Mafia action is already in progress.'),
      );
    }
    if (_gameId == null) {
      return const FailureResult(ValidationError('Open a Mafia game first.'));
    }
    _busy = true;
    notifyListeners();
    final result = await action();
    result.fold(onSuccess: (_) {}, onFailure: (failure) => _failure = failure);
    _busy = false;
    if (!_disposed) notifyListeners();
    return result;
  }

  Future<void> _cancel() async {
    _heartbeat?.cancel();
    await _gameSub?.cancel();
    await _playersSub?.cancel();
    await _privateSub?.cancel();
    await _eventsSub?.cancel();
    await _chatSub?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_cancel());
    super.dispose();
  }
}
