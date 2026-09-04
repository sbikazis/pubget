import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/achievement_models.dart';
import '../repositories/achievement_repository.dart';

final class AchievementProvider extends ChangeNotifier {
  AchievementProvider({required AchievementRepository repository})
    : _repository = repository;

  final AchievementRepository _repository;
  StreamSubscription<Result<List<AchievementItem>>>? _sub;
  List<AchievementItem> _items = const <AchievementItem>[];
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  String? _userId;
  bool _disposed = false;

  List<AchievementItem> get items => _items;
  List<AchievementItem> get unlocked =>
      _items.where((item) => item.unlocked).toList(growable: false);
  LoadingState get state => _state;
  Failure? get failure => _failure;

  void bindUser(String? userId) {
    if (_userId == userId) return;
    unawaited(_sub?.cancel());
    _items = const <AchievementItem>[];
    _failure = null;
    _userId = userId;
    if (userId == null) {
      _state = LoadingState.initial;
      _safeNotify();
      return;
    }
    open(userId);
  }

  Future<void> open(String userId) async {
    _userId = userId;
    _state = LoadingState.loading;
    notifyListeners();
    await _sub?.cancel();
    _sub = _repository.watch(userId).listen((result) {
      if (_disposed) return;
      result.fold(
        onSuccess: (items) {
          _items = items;
          _failure = null;
          _state = items.isEmpty ? LoadingState.empty : LoadingState.loaded;
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
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
