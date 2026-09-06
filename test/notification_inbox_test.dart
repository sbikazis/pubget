import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/notifications/models/app_notification.dart';
import 'package:pubget/features/notifications/models/unread_counts.dart';
import 'package:pubget/features/notifications/providers/notification_provider.dart';
import 'package:pubget/features/notifications/repositories/notification_repository.dart';

void main() {
  test('retry re-fetches after a failed inbox load', () async {
    final repository = _FakeNotificationRepository()
      ..failure = const NetworkError('offline');
    final provider = NotificationProvider(repository: repository, pageSize: 2);
    addTearDown(provider.dispose);

    await provider.open('alice');
    expect(provider.state, LoadingState.offline);
    expect(repository.loads, 1);

    repository
      ..failure = null
      ..page = <AppNotification>[_item('n1')];
    await provider.retry();

    expect(repository.loads, 2);
    expect(provider.state, LoadingState.loaded);
    expect(provider.items.single.id, 'n1');
    expect(provider.hasMore, isFalse);
  });

  test('a short last page and close reset hasMore', () async {
    final repository = _FakeNotificationRepository()
      ..page = <AppNotification>[_item('n1'), _item('n2')]
      ..older = <AppNotification>[_item('n3')];
    final provider = NotificationProvider(repository: repository, pageSize: 2);
    addTearDown(provider.dispose);

    await provider.open('alice');
    expect(provider.hasMore, isTrue);

    await provider.loadMore();
    expect(repository.olderLoads, 1);
    expect(provider.items, hasLength(3));
    expect(provider.hasMore, isFalse);

    await provider.close();
    expect(provider.hasMore, isFalse);
    expect(provider.items, isEmpty);
    expect(provider.state, LoadingState.initial);

    await provider.open('alice');
    expect(provider.hasMore, isTrue);
    expect(provider.items, hasLength(2));
  });

}

AppNotification _item(String id) => AppNotification(
  id: id,
  type: 'friend_request',
  actorId: 'bob',
  targetId: 'alice',
  action: 'sent a friend request',
  destination: '/friend-requests',
  metadata: const <String, dynamic>{},
  createdAt: DateTime(2026, 1, 1, 12, id.hashCode % 24),
  readAt: null,
  groupKey: null,
);

final class _FakeNotificationRepository implements NotificationRepository {
  int loads = 0;
  int olderLoads = 0;
  Failure? failure;
  List<AppNotification> page = const <AppNotification>[];
  List<AppNotification> older = const <AppNotification>[];
  UnreadCounts counts = const UnreadCounts(
    notifications: 0,
    groups: 0,
    privateChats: 0,
    mentions: 0,
  );

  @override
  Stream<Result<List<AppNotification>>> getNotifications(
    String uid, {
    int limit = 30,
  }) {
    loads++;
    final error = failure;
    if (error != null) return Stream.value(FailureResult(error));
    return Stream.value(Success(page.take(limit).toList(growable: false)));
  }

  @override
  Future<Result<List<AppNotification>>> getOlderNotifications({
    required String uid,
    required AppNotification before,
    int limit = 30,
  }) async {
    olderLoads++;
    final error = failure;
    if (error != null) return FailureResult(error);
    return Success(older.take(limit).toList(growable: false));
  }

  @override
  Stream<Result<UnreadCounts>> watchUnreadCounts(String uid) =>
      Stream.value(Success(counts));

  @override
  Future<Result<void>> markAsRead(String notificationId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> markAllAsRead() async => const Success<void>(null);

  @override
  Future<Result<bool>> registerDeviceToken() async => const Success(true);

  @override
  Future<Result<void>> unregisterDeviceToken() async =>
      const Success<void>(null);
}
