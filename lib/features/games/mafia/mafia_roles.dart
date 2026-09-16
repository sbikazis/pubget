/// Core Pubget 1.0 Mafia roles. Extra roles (sniper, jester, …) are out of scope.
enum MafiaRole {
  mafia,
  civilian,
  detective,
  doctor;

  static MafiaRole parse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'mafia':
        return MafiaRole.mafia;
      case 'civilian':
        return MafiaRole.civilian;
      case 'detective':
        return MafiaRole.detective;
      case 'doctor':
        return MafiaRole.doctor;
      default:
        throw FormatException('Unknown Mafia role: $raw');
    }
  }

  bool get isMafiaTeam => this == MafiaRole.mafia;

  String get nightActionType {
    switch (this) {
      case MafiaRole.mafia:
        return 'mafia_kill';
      case MafiaRole.detective:
        return 'mafia_investigate';
      case MafiaRole.doctor:
        return 'mafia_protect';
      case MafiaRole.civilian:
        return '';
    }
  }
}
