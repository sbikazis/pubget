// lib/core/utils/mafia_timer_service.dart
//
// إضافة: دوال مساعدة لتنسيق الوقت المتبقي وحساب النسبة المئوية
// للعداد المرئي. لا تزال كل القيم مبنية حصراً على phaseEndsAt القادم
// من Firestore — لا يوجد أي Timer محلي مستقل يُنشئ وقته الخاص.

import 'package:cloud_firestore/cloud_firestore.dart';

class MafiaTimerService {
  final FirebaseFirestore _firestore;

  MafiaTimerService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DateTime? parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  int remainingSeconds(DateTime? endsAt) {
    if (endsAt == null) return 0;
    final now = DateTime.now().toUtc();
    return endsAt.toUtc().difference(now).inSeconds.clamp(0, 999999);
  }

  /// تنسيق الثواني إلى mm:ss لعرضها في العداد.
  String formatSeconds(int totalSeconds) {
    final s = totalSeconds.clamp(0, 999999);
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  /// نسبة الوقت المتبقي من إجمالي مدة المرحلة، لعرض شريط تقدم بصري.
  /// ترجع 0.0 إذا انتهى الوقت أو كانت المدة الكلية صفر.
  double progressRatio({
    required DateTime? endsAt,
    required int totalDurationSeconds,
  }) {
    if (endsAt == null || totalDurationSeconds <= 0) return 0.0;
    final remaining = remainingSeconds(endsAt);
    return (remaining / totalDurationSeconds).clamp(0.0, 1.0);
  }
}