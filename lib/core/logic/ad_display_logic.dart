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

  // ✅ إضافة دالة فحص الحد اليومي (3 إعلانات كحد أقصى)
  static AdDisplayDecision checkDailyLimit(int adsShownToday) {
    if (adsShownToday >= 3) {
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

  // First open in the morning rule
  static AdDisplayDecision checkMorningAd(
    DateTime? lastAdTime,
  ) {
    AdDisplayDecision decision;

    // Never shown before
    if (lastAdTime == null) {
      decision = const AdDisplayDecision(
        shouldShow: true,
        reason: "first_time_open",
      );
    }
    // New day
    else if (TimeUtils.isNewDay(lastAdTime)) {
      decision = const AdDisplayDecision(
        shouldShow: true,
        reason: "new_day",
      );
    } else {
      decision = const AdDisplayDecision(
        shouldShow: false,
        reason: "already_shown_today",
      );
    }

    debugPrint('📢 Ad Logic (Morning): ${decision.reason} -> Should Show: ${decision.shouldShow}');
    return decision;
  }

  // ✅ تعديل دالة الـ 5 دقائق (300 ثانية) للتأكد من الفاصل الزمني
  static AdDisplayDecision checkFiveMinutesRule(
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
      // التحقق من مرور 5 دقائق (300 ثانية)
      final passed = TimeUtils.hasMinutesPassed(lastAdTime, 5);

      if (passed) {
        decision = const AdDisplayDecision(
          shouldShow: true,
          reason: "five_minutes_passed",
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