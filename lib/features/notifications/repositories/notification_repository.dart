import '../../../core/errors/result.dart';
import '../models/app_notification.dart';
import '../models/unread_counts.dart';

abstract interface class NotificationRepository {
  Stream<Result<List<AppNotification>>> getNotifications(
    String uid, {
    int limit = 30,
  });

  Future<Result<List<AppNotification>>> getOlderNotifications({
    required String uid,
    required AppNotification before,
    int limit = 30,
  });

  Stream<Result<UnreadCounts>> watchUnreadCounts(String uid);

  Future<Result<void>> markAsRead(String notificationId);
  Future<Result<void>> markAllAsRead();
  Future<Result<bool>> registerDeviceToken();
  Future<Result<void>> unregisterDeviceToken();
}
