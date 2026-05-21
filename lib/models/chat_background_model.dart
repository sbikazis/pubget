// lib/models/chat_background_model.dart

/// نوع مصدر الخلفية
enum ChatBackgroundType {
  /// لا توجد خلفية (الثيم الافتراضي)
  none,

  /// صورة مرفوعة على Firebase Storage (للمجموعات)
  network,

  /// صورة محفوظة محلياً على الجهاز (للدردشة الخاصة)
  local,
}

class ChatBackgroundModel {
  /// نوع مصدر الخلفية
  final ChatBackgroundType type;

  /// المسار: URL للشبكة أو مسار ملف محلي
  final String? path;

  /// قيمة الـ Overlay (0.0 → شفاف تماماً، 1.0 → معتم تماماً)
  /// القيمة الافتراضية 0.38 تضمن وضوح عناصر الدردشة
  final double overlayOpacity;

  const ChatBackgroundModel({
    required this.type,
    this.path,
    this.overlayOpacity = 0.38,
  });

  /// خلفية فارغة (بدون صورة)
  const ChatBackgroundModel.none()
      : type = ChatBackgroundType.none,
        path = null,
        overlayOpacity = 0.0;

  /// خلفية من الشبكة (مجموعة)
  const ChatBackgroundModel.network({
    required String url,
    double opacity = 0.38,
  })  : type = ChatBackgroundType.network,
        path = url,
        overlayOpacity = opacity;

  /// خلفية محلية (دردشة خاصة)
  const ChatBackgroundModel.local({
    required String filePath,
    double opacity = 0.38,
  })  : type = ChatBackgroundType.local,
        path = filePath,
        overlayOpacity = opacity;

  /// هل توجد خلفية فعلية؟
  bool get hasBackground =>
      type != ChatBackgroundType.none &&
      path != null &&
      path!.isNotEmpty;

  /// هل المصدر من الشبكة؟
  bool get isNetwork => type == ChatBackgroundType.network;

  /// هل المصدر محلي؟
  bool get isLocal => type == ChatBackgroundType.local;

  /// نسخة معدّلة مع تغيير الـ opacity فقط
  ChatBackgroundModel withOpacity(double opacity) {
    return ChatBackgroundModel(
      type: type,
      path: path,
      overlayOpacity: opacity,
    );
  }

  /// تحويل لـ Map للحفظ في SharedPreferences (للدردشة الخاصة)
  Map<String, dynamic> toLocalMap() {
    return {
      'type': type.name,
      'path': path,
      'overlayOpacity': overlayOpacity,
    };
  }

  /// استعادة من Map محفوظ في SharedPreferences
  factory ChatBackgroundModel.fromLocalMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String? ?? 'none';
    final type = ChatBackgroundType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => ChatBackgroundType.none,
    );

    return ChatBackgroundModel(
      type: type,
      path: map['path'] as String?,
      overlayOpacity: (map['overlayOpacity'] as num?)?.toDouble() ?? 0.38,
    );
  }

  @override
  String toString() {
    return 'ChatBackgroundModel(type: $type, path: $path, overlay: $overlayOpacity)';
  }
}