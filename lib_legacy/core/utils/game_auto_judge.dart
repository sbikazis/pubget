import '../../models/game_model.dart';
import '../constants/game_status.dart';

enum TimeoutType {
  none,
  setupTimeout, // تجاوز الـ 60 ثانية في التجهيز
  turnTimeout, // تجاوز الـ 40 ثانية في الدور
  totalGameTimeout // تجاوز الـ 10 دقائق الكلية
}

class GameAutoJudge {
  // الثوابت الزمنية كما وصفتها بدقة
  static const int setupLimit = 60; // ثانية لاختيار الشخصية
  static const int turnLimit = 40; // ثانية لكل دور (سؤال أو جواب)
  static const int totalLimit = 600; // 10 دقائق للعبة كاملة

  /// الوظيفة الأساسية: فحص ما إذا كان هناك تجاوز للوقت بناءً على حالة اللعبة
  static TimeoutType checkTimeout(GameModel game) {
    final now = DateTime.now();

    // 1. فحص الوقت الكلي للعبة (10 دقائق)
    // اللعبة تبدأ عدادها من لحظة الإنشاء createdAt
    final totalElapsed = now.difference(game.createdAt).inSeconds;
    if (totalElapsed >= totalLimit && !game.status.isOver) {
      return TimeoutType.totalGameTimeout;
    }

    // 2. فحص وقت التجهيز (60 ثانية)
    // نستخدم isInSetup للتحقق من الحالة
    if (game.status.isInSetup) {
      final setupElapsed = now.difference(game.setupStartedAt ?? game.createdAt).inSeconds;
      if (setupElapsed >= setupLimit) {
        return TimeoutType.setupTimeout;
      }
    }

    // 3. فحص وقت الدور الحالي (40 ثانية)
    // نستخدم isLive للتحقق من أن اللعبة في حالة guessing النشطة
    if (game.status.isLive) {
      // نعتمد على lastActionAt لإعادة تشغيل الـ 40 ثانية مع كل حركة
      final actionTime = game.lastActionAt ?? game.createdAt;
      final turnElapsed = now.difference(actionTime).inSeconds;
      if (turnElapsed >= turnLimit) {
        return TimeoutType.turnTimeout;
      }
    }

    return TimeoutType.none;
  }

  /// يحدد من هو الخاسر بناءً على التوقيت والحالة الحالية
  static String? getTimedOutPlayerId(GameModel game) {
    final timeout = checkTimeout(game);
    
    if (timeout == TimeoutType.setupTimeout) {
      // في مرحلة التجهيز، الخاسر هو من لم يكمل اختيار شخصيته
      if (game.playerOneCharacter == null) return game.playerOneId;
      if (game.playerTwoId != null && game.playerTwoCharacter == null) return game.playerTwoId;
    }

    if (timeout == TimeoutType.turnTimeout) {
      // في مرحلة اللعب النشط، الخاسر هو صاحب الدور الحالي
      return game.currentTurnUserId;
    }

    return null; // في حالة الوقت الكلي (تعادل)
  }

  /// رسالة توضيحية لسبب انتهاء اللعبة تظهر في الدردشة كـ GameEvent
  static String getReasonMessage(TimeoutType type, String? playerName) {
    switch (type) {
      case TimeoutType.setupTimeout:
        return "انتهى وقت التجهيز (60ث). خسارة اللاعب $playerName لعدم الجاهزية.";
      case TimeoutType.turnTimeout:
        return "انتهى وقت الدور (40ث). خسارة اللاعب $playerName بسبب التأخر.";
      case TimeoutType.totalGameTimeout:
        return "انتهى الوقت الكلي للمباراة (10د). النتيجة: تعادل.";
      default:
        return "";
    }
  }
}