import 'dart:async';
import '../constants/game_constants.dart';

class GameTimerManager {
  /// يحسب الوقت المتبقي لأي مرحلة بناءً على وقت بدئها
  /// [startedAt] هو الوقت الذي تم تسجيله في Firestore عند بدء المرحلة
  /// [durationInSeconds] هو الثابت من ملف GameConstants
  static int getRemainingSeconds(DateTime startedAt, int durationInSeconds) {
    final now = DateTime.now();
    final difference = now.difference(startedAt).inSeconds;
    final remaining = durationInSeconds - difference;
    return remaining > 0 ? remaining : 0;
  }

  /// يتحقق مما إذا كان الوقت قد انتهى فعلياً
  static bool isTimeUp(DateTime startedAt, int durationInSeconds) {
    return getRemainingSeconds(startedAt, durationInSeconds) <= 0;
  }

  /// دالة مخصصة لمرحلة اختيار الشخصية (60 ثانية)
  static bool hasSetupTimeout(DateTime setupStartedAt) {
    return isTimeUp(setupStartedAt, GameConstants.characterSelectionDuration);
  }

  /// دالة مخصصة لتبادل الأدوار (40 ثانية)
  static bool hasTurnTimeout(DateTime lastActionAt) {
    return isTimeUp(lastActionAt, GameConstants.turnDuration);
  }

  /// دالة مخصصة لعمر اللعبة الإجمالي (10 دقائق)
  static bool hasGameTotalTimeout(DateTime createdAt) {
    // نحول الدقائق إلى ثوانٍ للحساب
    return isTimeUp(createdAt, GameConstants.maxGameDurationMinutes * 60);
  }

  /// ميكانيكية الـ Stream (تحديث الواجهة برمجياً)
  /// التعديل: يدعم الآن المزامنة مع الوقت الفعلي بدلاً من العد من الصفر فقط
  static Stream<int> startCountdown(int seconds) {
    return Stream.periodic(const Duration(seconds: 1), (i) => seconds - i - 1)
        .take(seconds);
  }

  /// ✅ التعديل الجديد: Stream مزامن مع الوقت الفعلي (Sync Stream)
  /// يقوم بحساب الثواني المتبقية فعلياً من لحظة الحركة الأخيرة [lastActionAt]
  /// مما يضمن أن كل اللاعبين يرون نفس الرقم في نفس اللحظة.
  static Stream<int> startSyncedCountdown(DateTime lastActionAt, int totalDuration) {
    final initialRemaining = getRemainingSeconds(lastActionAt, totalDuration);
    
    return Stream.periodic(const Duration(seconds: 1), (i) {
      final currentRemaining = getRemainingSeconds(lastActionAt, totalDuration);
      return currentRemaining;
    }).takeWhile((remaining) => remaining >= 0);
  }
}