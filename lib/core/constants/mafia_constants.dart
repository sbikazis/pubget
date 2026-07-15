// lib/core/constants/mafia_constants.dart

class MafiaRoles {
  MafiaRoles._();

  static const String mafia = 'mafia';
  static const String doctor = 'doctor';
  static const String detective = 'detective';
  static const String sniper = 'sniper';
  static const String silencer = 'silencer';
  static const String goodBoy = 'good_boy';
  static const String citizen = 'citizen';

  static const List<String> all = [
    mafia,
    doctor,
    detective,
    sniper,
    silencer,
    goodBoy,
    citizen,
  ];
}

class MafiaTeams {
  MafiaTeams._();

  static const String mafias = 'mafias';
  static const String citizens = 'citizens';
  static const String neutral = 'neutral';
}

class MafiaGameVersions {
  MafiaGameVersions._();

  static const String classic = 'classic';
  static const String advanced = 'advanced';
  static const String ranked = 'ranked';
  static const String hardcore = 'hardcore';
  static const String event = 'event';
  static const String season = 'season';
  static const String custom = 'custom';

  static const List<String> all = [
    classic,
    advanced,
    ranked,
    hardcore,
    event,
    season,
    custom,
  ];
}

/// مؤقتات اللعبة بكل مراحلها.
/// ⚠️ هذه القيم تُستخدم في مكانين فقط:
/// 1. Flutter: لعرض تقديري فقط (لا يُكتب منها شيء على المرحلة الفعلية).
/// 2. functions/src/mafia/phaseFlow.js: نسخة مطابقة تماماً بالثواني،
///    وهي المصدر الحقيقي الوحيد الذي يُحدد متى تنتقل المرحلة فعلياً.
/// أي تعديل هنا يجب أن يُرافقه نفس التعديل في phaseFlow.js يدوياً.
class MafiaTimers {
  MafiaTimers._();

  static const int lobbyWaitSeconds = 60;
  static const int startingCountdownSeconds = 10;

  static const int nightSeconds = 45;
  static const int daySeconds = 20;
  static const int discussionSeconds = 90;
  static const int votingSeconds = 45;
  static const int executionSeconds = 15;
}

enum MafiaGameStatus {
  waiting,
  starting,
  night,
  day,
  discussion,
  voting,
  execution,
  finished,
  cancelled,
}

extension MafiaGameStatusExt on MafiaGameStatus {
  String get name {
    return toString().split('.').last;
  }

  bool get isActive =>
      this != MafiaGameStatus.finished && this != MafiaGameStatus.cancelled;

  static MafiaGameStatus fromString(String? value) {
    if (value == null) return MafiaGameStatus.waiting;
    return MafiaGameStatus.values.firstWhere(
      (st) => st.name == value,
      orElse: () => MafiaGameStatus.waiting,
    );
  }
}