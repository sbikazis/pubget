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
