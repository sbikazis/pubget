import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/app_notification.dart';
import '../models/unread_counts.dart';
import 'notification_repository.dart';

final class UnavailableNotificationRepository
    implements NotificationRepository {
  const UnavailableNotificationRepository(this.message);
  final String message;

  FailureResult<T> _failure<T>() => FailureResult(UnknownError(message));

  @override
  Stream<Result<List<AppNotification>>> getNotifications(
    String uid, {
    int limit = 30,
  }) => Stream.value(_failure());

  @override
  Future<Result<List<AppNotification>>> getOlderNotifications({
    required String uid,
    required AppNotification before,
    int limit = 30,
  }) async => _failure();

  @override
  Stream<Result<UnreadCounts>> watchUnreadCounts(String uid) =>
      Stream.value(_failure());

  @override
  Future<Result<void>> markAsRead(String notificationId) async => _failure();

  @override
  Future<Result<void>> markAllAsRead() async => _failure();

  @override
  Future<Result<bool>> registerDeviceToken() async => _failure();

  @override
  Future<Result<void>> unregisterDeviceToken() async => _failure();
}
