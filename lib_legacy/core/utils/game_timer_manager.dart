import 'dart:async';
import '../constants/game_constants.dart';

class GameTimerManager {
  static int getRemainingSeconds(DateTime startedAt, int durationInSeconds) {
    final now = DateTime.now();
    final difference = now.difference(startedAt).inSeconds;
    final remaining = durationInSeconds - difference;
    return remaining;
  }

  static bool isTimeUp(DateTime startedAt, int durationInSeconds) {
    return getRemainingSeconds(startedAt, durationInSeconds) <= 0;
  }

  static bool hasSetupTimeout(DateTime setupStartedAt) {
    return isTimeUp(setupStartedAt, GameConstants.characterSelectionDuration);
  }

  // ✅ التعديل - يقبل null وما يحسبش الوقت إلا بدات اللعبة
  static bool hasTurnTimeout(DateTime? lastActionAt) {
    if (lastActionAt == null) return false; // ما بداتش اللعبة
    return isTimeUp(lastActionAt, GameConstants.turnDuration);
  }

  static bool hasGameTotalTimeout(DateTime createdAt) {
    return isTimeUp(createdAt, GameConstants.maxGameDurationMinutes * 60);
  }

  static Stream<int> startCountdown(int seconds) {
    return Stream.periodic(const Duration(seconds: 1), (i) => seconds - i - 1)
        .take(seconds);
  }

  static Stream<int> startSyncedCountdown(DateTime lastActionAt, int totalDuration) {
    return Stream.periodic(const Duration(seconds: 1), (i) {
      return getRemainingSeconds(lastActionAt, totalDuration);
    }).takeWhile((remaining) => remaining > -1);
  }

  static DateTime getServerTime(DateTime serverTimestamp) {
    return serverTimestamp;
  }
}
