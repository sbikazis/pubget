// lib/core/mafia/mafia_game_engine.dart
//
// ⚠️ تغيير معماري مهم في هذه المرحلة:
// هذا الملف لم يعد يكتب أي تحديث على مرحلة اللعبة في Firestore.
// السبب: القاعدة الصريحة في تصميم اللعبة تنص أن لا يحق لأي Client
// أن يغيّر المرحلة أو يحدد الفائز. السلطة الفعلية لتغيير المرحلة
// أصبحت بالكامل في functions/src/mafia/phaseScheduler.js (سيرفر).
//
// دور هذا الملف الآن: توصيف تسلسل المراحل ومددها، ليُستخدم من
// الواجهة (العدّاد، اسم المرحلة التالية المتوقعة) بدون أي كتابة فعلية.
// هذا التسلسل مطابق حرفياً لما في functions/src/mafia/phaseFlow.js —
// أي تعديل هنا يستوجب تعديل مطابق هناك يدوياً.

import '../constants/mafia_constants.dart';

class MafiaPhaseFlow {
  MafiaPhaseFlow._();

  /// ترتيب المراحل المتكررة بعد الليلة الأولى (لا تشمل waiting/starting
  /// لأنهما تُداران حصراً عبر lobbyManager.js، ولا finished/cancelled
  /// لأنهما حالتا نهاية).
  static const List<MafiaGameStatus> order = [
    MafiaGameStatus.night,
    MafiaGameStatus.day,
    MafiaGameStatus.discussion,
    MafiaGameStatus.voting,
    MafiaGameStatus.execution,
  ];

  /// المرحلة التالية في الدورة (تلقائياً تدور: بعد execution ترجع night).
  static MafiaGameStatus next(MafiaGameStatus current) {
    final idx = order.indexOf(current);
    if (idx == -1) return MafiaGameStatus.night;
    return order[(idx + 1) % order.length];
  }

  static int durationSeconds(MafiaGameStatus phase) {
    switch (phase) {
      case MafiaGameStatus.night:
        return MafiaTimers.nightSeconds;
      case MafiaGameStatus.day:
        return MafiaTimers.daySeconds;
      case MafiaGameStatus.discussion:
        return MafiaTimers.discussionSeconds;
      case MafiaGameStatus.voting:
        return MafiaTimers.votingSeconds;
      case MafiaGameStatus.execution:
        return MafiaTimers.executionSeconds;
      default:
        return 0;
    }
  }

  static String arabicLabel(MafiaGameStatus phase) {
    switch (phase) {
      case MafiaGameStatus.waiting:
        return 'غرفة الانتظار';
      case MafiaGameStatus.starting:
        return 'بدء المباراة...';
      case MafiaGameStatus.night:
        return '🌙 الليل';
      case MafiaGameStatus.day:
        return '☀️ الصباح';
      case MafiaGameStatus.discussion:
        return '💬 النقاش';
      case MafiaGameStatus.voting:
        return '🗳️ التصويت';
      case MafiaGameStatus.execution:
        return '⚖️ الإعدام';
      case MafiaGameStatus.finished:
        return '🏁 انتهت المباراة';
      case MafiaGameStatus.cancelled:
        return '❌ أُلغيت المباراة';
    }
  }
}

/// نسخة قراءة فقط — لا يوجد فيها أي دالة تكتب على Firestore.
/// أُبقيت كواجهة مستقرة (Facade) لأي كود Flutter مستقبلي يحتاج معرفة
/// اسم/مدة/تسلسل المرحلة، دون إغراء أحد بالكتابة المباشرة من العميل.
class MafiaGameEngine {
  const MafiaGameEngine();

  MafiaGameStatus previewNextPhase(MafiaGameStatus current) =>
      MafiaPhaseFlow.next(current);

  int durationOf(MafiaGameStatus phase) => MafiaPhaseFlow.durationSeconds(phase);

  String labelOf(MafiaGameStatus phase) => MafiaPhaseFlow.arabicLabel(phase);
}