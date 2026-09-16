/// Smallest robust Mafia configuration for Pubget 1.0.
///
/// Defaults:
/// - 4–16 players (matches [GameTypeRegistry] capabilities)
/// - Role counts auto-derived at start unless explicit counts are provided
/// - Night 45s, day intro 20s, discussion 90s, voting 45s
class MafiaConfig {
  const MafiaConfig({
    this.minPlayers = 4,
    this.maxPlayers = 16,
    this.mafiaCount,
    this.civilianCount,
    this.detectiveCount,
    this.doctorCount,
    this.nightDurationSeconds = 45,
    this.dayDurationSeconds = 20,
    this.discussionDurationSeconds = 90,
    this.votingDurationSeconds = 45,
    this.deadCanSpectate = true,
    this.deadCanChat = false,
  });

  final int minPlayers;
  final int maxPlayers;
  final int? mafiaCount;
  final int? civilianCount;
  final int? detectiveCount;
  final int? doctorCount;
  final int nightDurationSeconds;
  final int dayDurationSeconds;
  final int discussionDurationSeconds;
  final int votingDurationSeconds;
  final bool deadCanSpectate;

  /// Dead players never get a separate chat channel. Existing group chat
  /// remains the discussion surface for living players.
  final bool deadCanChat;

  Map<String, dynamic> toExtra() {
    return <String, dynamic>{
      'minPlayers': minPlayers,
      'maxPlayers': maxPlayers,
      'mafiaCount': mafiaCount,
      'civilianCount': civilianCount,
      'detectiveCount': detectiveCount,
      'doctorCount': doctorCount,
      'nightDurationSeconds': nightDurationSeconds,
      'dayDurationSeconds': dayDurationSeconds,
      'discussionDurationSeconds': discussionDurationSeconds,
      'votingDurationSeconds': votingDurationSeconds,
      'deadCanSpectate': deadCanSpectate,
      'deadCanChat': false,
    };
  }

  static MafiaConfig fromExtra(Map<String, Object?> extra) {
    return MafiaConfig(
      minPlayers: (extra['minPlayers'] as num?)?.toInt() ?? 4,
      maxPlayers: (extra['maxPlayers'] as num?)?.toInt() ?? 16,
      mafiaCount: (extra['mafiaCount'] as num?)?.toInt(),
      civilianCount: (extra['civilianCount'] as num?)?.toInt(),
      detectiveCount: (extra['detectiveCount'] as num?)?.toInt(),
      doctorCount: (extra['doctorCount'] as num?)?.toInt(),
      nightDurationSeconds:
          (extra['nightDurationSeconds'] as num?)?.toInt() ?? 45,
      dayDurationSeconds: (extra['dayDurationSeconds'] as num?)?.toInt() ?? 20,
      discussionDurationSeconds:
          (extra['discussionDurationSeconds'] as num?)?.toInt() ?? 90,
      votingDurationSeconds:
          (extra['votingDurationSeconds'] as num?)?.toInt() ?? 45,
      deadCanSpectate: extra['deadCanSpectate'] != false,
      deadCanChat: false,
    );
  }
}
