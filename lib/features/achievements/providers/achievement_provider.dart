import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../data/achievement_catalog.dart';
import '../models/achievement_models.dart';
import '../repositories/achievement_repository.dart';

final class AchievementProvider extends ChangeNotifier {
  AchievementProvider({required AchievementRepository repository})
      : _repository = repository;

  final AchievementRepository _repository;
  StreamSubscription<Result<List<AchievementItem>>>? _sub;
  List<AchievementItem> _items = AchievementCatalog.lockedItems();
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  String? _userId;
  bool _disposed = false;
  final Set<String> _celebratedIds = <String>{};
  final List<AchievementItem> _pendingCelebrations = <AchievementItem>[];

  List<AchievementItem> get items => _items;
  List<AchievementItem> get unlocked =>
      _items.where((item) => item.unlocked).toList(growable: false);
  LoadingState get state => _state;
  Failure? get failure => _failure;
  String? get userId => _userId;

  /// Next unlock celebration that hasn't been shown yet (once per id).
  AchievementItem? takePendingCelebration() {
    while (_pendingCelebrations.isNotEmpty) {
      final next = _pendingCelebrations.removeAt(0);
      if (_celebratedIds.add(next.id)) {
        unawaited(_persistCelebrated(next.id));
        return next;
      }
    }
    return null;
  }

  void bindUser(String? userId) {
    if (_userId == userId) return;
    unawaited(_sub?.cancel());
    _items = AchievementCatalog.lockedItems();
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
    await _loadCelebrated(userId);
    // Prefer callable for full progress, then watch unlocks for live updates.
    final listed = await _repository.list(userId: userId);
    if (_disposed || _userId != userId) return;
    listed.fold(
      onSuccess: (items) {
        _ingest(items, seedCelebrations: false);
        _failure = null;
        _state = LoadingState.loaded;
      },
      onFailure: (failure) {
        _failure = failure;
        _state = failure is NetworkError
            ? LoadingState.offline
            : LoadingState.error;
      },
    );
    _safeNotify();

    await _sub?.cancel();
    _sub = _repository.watch(userId).listen((result) {
      if (_disposed || _userId != userId) return;
      result.fold(
        onSuccess: (items) {
          _ingest(items, seedCelebrations: true);
          _failure = null;
          _state = LoadingState.loaded;
        },
        onFailure: (failure) {
          _failure = failure;
          if (_items.every((item) => !item.unlocked)) {
            _state = failure is NetworkError
                ? LoadingState.offline
                : LoadingState.error;
          }
        },
      );
      notifyListeners();
    });
  }

  void _ingest(List<AchievementItem> items, {required bool seedCelebrations}) {
    final previousUnlocked = {
      for (final item in _items.where((i) => i.unlocked)) item.id,
    };
    _items = items;
    if (!seedCelebrations) return;
    for (final item in items.where((i) => i.unlocked)) {
      if (previousUnlocked.contains(item.id)) continue;
      if (_celebratedIds.contains(item.id)) continue;
      _pendingCelebrations.add(item);
    }
  }

  Future<void> _loadCelebrated(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved =
          prefs.getStringList('achievement_celebrated_$userId') ?? const [];
      _celebratedIds
        ..clear()
        ..addAll(saved);
    } on Object {
      // Local prefs optional.
    }
  }

  Future<void> _persistCelebrated(String id) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'achievement_celebrated_$uid',
        _celebratedIds.toList(growable: false),
      );
    } on Object {
      // ignore
    }
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
