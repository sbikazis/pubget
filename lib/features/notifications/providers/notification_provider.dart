import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/app_notification.dart';
import '../models/unread_counts.dart';
import '../repositories/notification_repository.dart';

final class NotificationProvider extends ChangeNotifier {
  NotificationProvider({required NotificationRepository repository})
    : _repository = repository;

  final NotificationRepository _repository;
  final List<AppNotification> _items = <AppNotification>[];
  StreamSubscription<Result<List<AppNotification>>>? _itemsSubscription;
  StreamSubscription<Result<UnreadCounts>>? _countSubscription;
  String? _uid;
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  int _unreadCount = 0;
  int _groupsUnreadCount = 0;
  int _privateUnreadCount = 0;
  int _mentionsUnreadCount = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _disposed = false;

  List<AppNotification> get items => List.unmodifiable(_items);
  LoadingState get state => _state;
  Failure? get failure => _failure;
  int get unreadCount => _unreadCount;
  int get groupsUnreadCount => _groupsUnreadCount;
  int get privateUnreadCount => _privateUnreadCount;
  int get mentionsUnreadCount => _mentionsUnreadCount;
  bool get hasMore => _hasMore;

  Future<void> open(String uid) async {
    if (_uid == uid) return;
    await close();
    _uid = uid;
    _state = LoadingState.loading;
    notifyListeners();
    _itemsSubscription = _repository.getNotifications(uid).listen(_receive);
    _countSubscription = _repository.watchUnreadCounts(uid).listen((result) {
      result.fold(
        onSuccess: (counts) {
          _unreadCount = counts.notifications;
          _groupsUnreadCount = counts.groups;
          _privateUnreadCount = counts.privateChats;
          _mentionsUnreadCount = counts.mentions;
          _safeNotify();
        },
        onFailure: (failure) {
          _failure = failure;
          _safeNotify();
        },
      );
    });
  }

  Future<void> loadMore() async {
    final uid = _uid;
    if (uid == null || _items.isEmpty || !_hasMore || _loadingMore) {
      return;
    }
    _loadingMore = true;
    _state = LoadingState.loadingMore;
    notifyListeners();
    final result = await _repository.getOlderNotifications(
      uid: uid,
      before: _items.last,
    );
    result.fold(
      onSuccess: (older) {
        final known = _items.map((item) => item.id).toSet();
        _items.addAll(older.where((item) => known.add(item.id)));
        _hasMore = older.isNotEmpty;
        _state = _items.isEmpty ? LoadingState.empty : LoadingState.loaded;
      },
      onFailure: _setFailure,
    );
    _loadingMore = false;
    _safeNotify();
  }

  Future<void> markAsRead(AppNotification notification) async {
    if (!notification.isUnread) return;
    final result = await _repository.markAsRead(notification.id);
    if (!result.isSuccess) _setFailure(result.failureOrNull!);
  }

  Future<void> markAllAsRead() async {
    final result = await _repository.markAllAsRead();
    if (!result.isSuccess) _setFailure(result.failureOrNull!);
  }

  Future<Result<bool>> enablePush() => _repository.registerDeviceToken();

  void _receive(Result<List<AppNotification>> result) {
    result.fold(
      onSuccess: (incoming) {
        final merged = <String, AppNotification>{
          for (final item in _items) item.id: item,
          for (final item in incoming) item.id: item,
        }.values.toList();
        merged.sort((left, right) {
          final time =
              (right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                    left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                  );
          return time != 0 ? time : right.id.compareTo(left.id);
        });
        _items
          ..clear()
          ..addAll(merged);
        _state = _items.isEmpty ? LoadingState.empty : LoadingState.loaded;
        _failure = null;
      },
      onFailure: _setFailure,
    );
    _safeNotify();
  }

  void _setFailure(Failure failure) {
    _failure = failure;
    _state = failure is NetworkError
        ? LoadingState.offline
        : LoadingState.error;
  }

  Future<void> close() async {
    await _itemsSubscription?.cancel();
    await _countSubscription?.cancel();
    _itemsSubscription = null;
    _countSubscription = null;
    _uid = null;
    _items.clear();
    _unreadCount = 0;
    _groupsUnreadCount = 0;
    _privateUnreadCount = 0;
    _mentionsUnreadCount = 0;
    _state = LoadingState.initial;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_itemsSubscription?.cancel());
    unawaited(_countSubscription?.cancel());
    super.dispose();
  }
}
