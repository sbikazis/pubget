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


  // First open in the morning rule

  static AdDisplayDecision checkMorningAd(
    DateTime? lastAdTime,
  ) {
    // Never shown before
    if (lastAdTime == null) {
      return const AdDisplayDecision(
        shouldShow: true,
        reason: "first_time_open",
      );
    }

    // New day
    if (TimeUtils.isNewDay(lastAdTime)) {
      return const AdDisplayDecision(
        shouldShow: true,
        reason: "new_day",
      );
    }

    return const AdDisplayDecision(
      shouldShow: false,
      reason: "already_shown_today",
    );
  }


  // 5 minutes rule (group enter/exit)

  static AdDisplayDecision checkFiveMinutesRule(
    DateTime? lastAdTime,
  ) {
    // Never shown before
    if (lastAdTime == null) {
      return const AdDisplayDecision(
        shouldShow: true,
        reason: "first_time",
      );
    }

    final passed =
        TimeUtils.hasMinutesPassed(lastAdTime, 5);

    if (passed) {
      return const AdDisplayDecision(
        shouldShow: true,
        reason: "five_minutes_passed",
      );
    }

    return const AdDisplayDecision(
      shouldShow: false,
      reason: "cooldown_active",
    );
  }


  // Global guard (Premium users)

  static AdDisplayDecision checkIfPremium({
    required bool isPremium,
    required AdDisplayDecision decision,
  }) {
    if (isPremium) {
      return const AdDisplayDecision(
        shouldShow: false,
        reason: "premium_user",
      );
    }

    return decision;
  }
}