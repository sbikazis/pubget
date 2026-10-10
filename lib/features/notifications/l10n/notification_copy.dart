import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_strings.dart';

/// Localized chrome for the notification inbox (spec §21).
final class NotificationCopy {
  const NotificationCopy(this._s);

  final AppStrings _s;

  static NotificationCopy of(BuildContext context) =>
      NotificationCopy(AppStrings.of(context));

  String get title => _s.pick('Notifications', 'الإشعارات');
  String get markAllRead => _s.pick('Mark all read', 'تعليم الكل كمقروء');
  String get enablePush => _s.pick('Enable push', 'تفعيل الإشعارات');
  String get pushEnabled =>
      _s.pick('Push notifications enabled', 'تم تفعيل الإشعارات');
  String get pushDenied => _s.pick(
    'Notification permission was not granted',
    'لم يُمنح إذن الإشعارات',
  );
  String get emptyTitle => _s.pick('No notifications', 'لا توجد إشعارات');
  String get emptyMessage => _s.pick(
    'Important activity will appear here.',
    'سيظهر النشاط المهم هنا.',
  );
  String get loadFailed =>
      _s.pick('Notifications could not load.', 'تعذّر تحميل الإشعارات.');

  /// The localized default title for a notification type. Metadata supplied by
  /// the server takes precedence for rank and moderation notices, which is
  /// handled by the caller.
  String titleFor(String type) => switch (type) {
    'group_message' => _s.pick('New group message', 'رسالة مجموعة جديدة'),
    'join_request' => _s.pick('Join request', 'طلب انضمام'),
    'request_accepted' => _s.pick('Request accepted', 'قُبل الطلب'),
    'friend_request' => _s.pick('Friend request', 'طلب صداقة'),
    'respect_received' => _s.pick('Respect received', 'وصلك احترام'),
    'game_invite' => _s.pick('Game invite', 'دعوة لعبة'),
    'game_started' => _s.pick('Game starting', 'اللعبة تبدأ'),
    'game_completed' => _s.pick('Game result', 'نتيجة اللعبة'),
    'achievement_unlocked' =>
      _s.pick('Achievement unlocked', 'إنجاز مفتوح'),
    'edit_published' => _s.pick('Edit published', 'نُشر الإيديت'),
    'edit_failed' => _s.pick('Edit processing failed', 'تعذّرت معالجة الإيديت'),
    'edit_needs_review' => _s.pick('Edit held for review', 'الإيديت قيد المراجعة'),
    'rank_promoted' => _s.pick('Rank promoted', 'ترقية في الرتبة'),
    'rank_demoted' => _s.pick('Rank demoted', 'تنزيل في الرتبة'),
    'member_warning' => _s.pick('Member warning', 'تنبيه عضو'),
    _ => _s.pick('Notification', 'إشعار'),
  };
}
