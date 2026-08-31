// lib/core/constants/notification_channels.dart

/// ══════════════════════════════════════════════════════════════
/// ثوابت قنوات الإشعارات وأنواع الـ payload
/// ══════════════════════════════════════════════════════════════

class NotificationChannels {
  NotificationChannels._();

  // ══════════════════════════════════════════════════════════
  // معرّفات القنوات
  // ══════════════════════════════════════════════════════════

  /// قناة الدردشة الجماعية — مع زر Reply
  static const String groupChat = 'pubget_reply_group';

  /// قناة الدردشة الخاصة — مع زر Reply
  static const String privateChat = 'pubget_reply_private';

  /// قناة الإشعارات العامة — بدون Reply (prefix + اسم الصوت)
  static const String generalPrefix = 'pubget_channel_';

  // ══════════════════════════════════════════════════════════
  // أسماء القنوات (تظهر في إعدادات الأندرويد)
  // ══════════════════════════════════════════════════════════

  static const String groupChatName   = 'رسائل المجموعات';
  static const String privateChatName = 'الرسائل الخاصة';
  static const String generalName     = 'Pubget Notifications';

  // ══════════════════════════════════════════════════════════
  // وصف القنوات
  // ══════════════════════════════════════════════════════════

  static const String groupChatDesc   =
      'رسائل دردشة المجموعات مع إمكانية الرد المباشر';
  static const String privateChatDesc =
      'الرسائل الخاصة مع إمكانية الرد المباشر';
  static const String generalDesc     = 'إشعارات تطبيق Pubget';
}

/// ══════════════════════════════════════════════════════════════
/// معرّفات أزرار الـ Reply في الإشعارات
/// ══════════════════════════════════════════════════════════════

class NotificationActions {
  NotificationActions._();

  /// زر الرد على رسالة مجموعة
  static const String replyGroup   = 'REPLY_GROUP';

  /// زر الرد على رسالة خاصة
  static const String replyPrivate = 'REPLY_PRIVATE';

  /// مفتاح النص المُدخَل في حقل الرد
  static const String replyInputKey = 'reply_text';

  /// نص زر الرد (يظهر على الإشعار)
  static const String replyLabel = 'رد';

  /// placeholder حقل الرد
  static const String replyHint = 'اكتب ردك...';
}

/// ══════════════════════════════════════════════════════════════
/// أنواع الإشعارات — تطابق قيم الـ type في FCM payload
/// ══════════════════════════════════════════════════════════════

class AppNotificationTypes {
  AppNotificationTypes._();

  // ── رسائل ──────────────────────────────────────────────
  /// رسالة في دردشة مجموعة
  static const String groupChat   = 'group_chat';

  /// رسالة في دردشة خاصة
  static const String privateChat = 'private_chat';

  // ── طلبات الانضمام ──────────────────────────────────────
  /// طلب انضمام جديد — يصل للشوغو
  static const String joinRequest = 'join_request';

  /// تم قبول الطلب — يصل للمستخدم
  static const String requestAccepted = 'request_accepted';

  /// تم رفض الطلب — يصل للمستخدم
  static const String requestRejected = 'request_rejected';

  // ── أحداث المجموعة ──────────────────────────────────────
  /// تم تفكيك المجموعة
  static const String groupDisbanded = 'group_disbanded';

  // ── التفاعلات ───────────────────────────────────────────
  /// تعليق جديد على إيديت
  static const String comment = 'comment';

  // ── عام ────────────────────────────────────────────────
  /// إشعار عام لا ينتمي لفئة محددة
  static const String generic = 'generic';
}

/// ══════════════════════════════════════════════════════════════
/// مفاتيح الـ payload — حقول البيانات المُرسَلة مع الإشعار
/// ══════════════════════════════════════════════════════════════

class NotificationPayloadKeys {
  NotificationPayloadKeys._();

  /// نوع الإشعار — يطابق قيم NotificationTypes
  static const String type = 'type';

  /// المعرّف المرجعي (groupId / chatId / editId)
  static const String refId = 'refId';

  /// معرّف المُرسِل
  static const String senderId = 'senderId';

  /// معرّف التعليق — للسكرول المباشر في إشعارات التعليقات
  static const String commentId = 'commentId';

  /// اسم المُرسِل — يُعرض في الإشعار
  static const String senderName = 'senderName';

  /// اسم المجموعة أو عنوان المحادثة
  static const String contextName = 'contextName';

  // ── فاصل الـ payload المضغوط ────────────────────────────
  /// الفاصل المستخدم في بناء الـ payload string
  static const String separator = '|';
}