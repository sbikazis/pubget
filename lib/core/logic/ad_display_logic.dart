// lib/core/logic/ad_display_logic.dart
import 'package:flutter/foundation.dart'; // مضاف لاستخدام debugPrint
import '../utils/time_utils.dart';

class AdDisplayDecision {
  final bool shouldShow;
  final String reason;

  const AdDisplayDecision({
    required this.shouldShow,
    required this.reason,
  });
}

class AdDisplayLogic {
  AdDisplayLogic._();

  // ✅ فحص الحد اليومي (إعلانين كحد أقصى لدخول المجموعات)
  static AdDisplayDecision checkDailyLimit(int adsShownToday) {
    if (adsShownToday >= 2) {
      return const AdDisplayDecision(
        shouldShow: false,
        reason: "daily_limit_reached",
      );
    }
    return const AdDisplayDecision(
      shouldShow: true,
      reason: "within_limit",
    );
  }

  // ✅ دالة الـ 10 دقائق للتأكد من الفاصل الزمني
  static AdDisplayDecision checkTenMinutesRule(
    DateTime? lastAdTime,
  ) {
    AdDisplayDecision decision;

    // Never shown before
    if (lastAdTime == null) {
      decision = const AdDisplayDecision(
        shouldShow: true,
        reason: "first_time",
      );
    } else {
      // التحقق من مرور 10 دقائق
      final passed = TimeUtils.hasMinutesPassed(lastAdTime, 10);

      if (passed) {
        decision = const AdDisplayDecision(
          shouldShow: true,
          reason: "ten_minutes_passed",
        );
      } else {
        decision = const AdDisplayDecision(
          shouldShow: false,
          reason: "cooldown_active",
        );
      }
    }

    debugPrint('📢 Ad Logic (Cooldown): ${decision.reason} -> Should Show: ${decision.shouldShow}');
    return decision;
  }

  // Global guard (Premium users)
  static AdDisplayDecision checkIfPremium({
    required bool isPremium,
    required AdDisplayDecision decision,
  }) {
    // إذا كان بريميوم، نرفض العرض بغض النظر عن القرار السابق
    if (isPremium) {
      const premiumDecision = AdDisplayDecision(
        shouldShow: false,
        reason: "premium_user",
      );
      debugPrint('📢 Ad Logic (Premium Check): User is Premium, blocking ad.');
      return premiumDecision;
    }

    return decision;
  }
}