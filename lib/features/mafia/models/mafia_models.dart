import 'package:cloud_firestore/cloud_firestore.dart';

enum MafiaPhase {
  waiting,
  starting,
  roleReveal,
  night,
  day,
  discussion,
  voting,
  voteResult,
  resolution,
  gameOver,
  cancelled,
}

/// Mafia is 7-15 players. The server owns the real clamp, so the client uses
/// these values instead of repeating a number that can drift.
abstract final class MafiaLimits {
  static const minPlayers = 7;
  static const maxPlayers = 15;
}

final class MafiaGame {
  const MafiaGame({
    required this.id,
    required this.groupId,
    required this.createdBy,
    required this.status,
    required this.currentPhase,
    required this.playersCount,
    required this.minPlayers,
    required this.maxPlayers,
    this.currentDay = 0,
    this.currentNight = 0,
    this.winner,
    this.countdownEndsAt,
    this.phaseEndsAt,
    this.serverStartedAt,
    this.serverEndsAt,
    this.startedAt,
    this.endedAt,
    this.currentSpeakerId,
    this.voteRound = 1,
    this.revoteCandidates = const <String>[],
  });

  final String id;
  final String groupId;
  final String createdBy;
  final String status;
  final String currentPhase;
  final int playersCount;
  final int minPlayers;
  final int maxPlayers;
  final int currentDay;
  final int currentNight;
  final String? winner;
  final DateTime? countdownEndsAt;
  final DateTime? phaseEndsAt;
  final DateTime? serverStartedAt;
  final DateTime? serverEndsAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? currentSpeakerId;
  final int voteRound;
  final List<String> revoteCandidates;

  bool get isLobby => status == 'WAITING' || status == 'STARTING';
  bool get isFinished => status == 'GAME_OVER' || status == 'CANCELLED';
  // Master Spec 13.7: a player may leave the waiting room too. Dropping below
  // the minimum cancels the lobby instead of starting it short, so the button
  // is offered from the moment the game exists.
  bool get canLeaveViaServer =>
      status == 'WAITING' ||
      status == 'STARTING' ||
      status == 'ROLE_REVEAL' ||
      status == 'NIGHT' ||
      status == 'DAY' ||
      status == 'DISCUSSION' ||
      status == 'VOTING' ||
      status == 'VOTE_RESULT' ||
      status == 'RESOLUTION';

  factory MafiaGame.fromMap(Map<String, dynamic> map, {required String id}) {
    return MafiaGame(
      id: id,
      groupId: map['groupId'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      status: map['status'] as String? ?? 'WAITING',
      currentPhase: map['currentPhase'] as String? ?? 'WAITING',
      playersCount: (map['playersCount'] as num?)?.toInt() ?? 0,
      // Master Spec 13.2: a Mafia lobby is 7-15 players. These defaults are the
      // floor and the ceiling, not a wish: the server clamps to the same range.
      minPlayers:
          (map['minPlayers'] as num?)?.toInt() ?? MafiaLimits.minPlayers,
      maxPlayers:
          (map['maxPlayers'] as num?)?.toInt() ?? MafiaLimits.maxPlayers,
      currentDay: (map['currentDay'] as num?)?.toInt() ?? 0,
      currentNight: (map['currentNight'] as num?)?.toInt() ?? 0,
      winner: map['winner'] as String?,
      countdownEndsAt: _date(map['countdownEndsAt']),
      phaseEndsAt: _date(map['phaseEndsAt']),
      serverStartedAt: _date(map['serverStartedAt']),
      serverEndsAt: _date(map['serverEndsAt']),
      startedAt: _date(map['startedAt']),
      endedAt: _date(map['endedAt']),
      currentSpeakerId: map['currentSpeakerId'] as String?,
      voteRound: (map['voteRound'] as num?)?.toInt() ?? 1,
      revoteCandidates: (map['revoteCandidates'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

final class MafiaPlayer {
  const MafiaPlayer({
    required this.userId,
    required this.username,
    this.avatar = '',
    this.isAlive = true,
    this.isDisconnected = false,
    this.hasLeft = false,
    this.canSpeak = true,
    this.canVote = true,
    this.canUseAbility = true,
    this.revealedRole = false,
    this.role,
    this.canSayLastWords = false,
    this.lastWords,
    this.lastWordsAt,
    this.eliminatedBy,
  });

  final String userId;
  final String username;
  final String avatar;
  final bool isAlive;
  final bool isDisconnected;
  final bool hasLeft;
  final bool canSpeak;
  final bool canVote;
  final bool canUseAbility;
  final bool revealedRole;

  /// Only ever set once the role is public: on this player's own elimination
  /// (Master Spec 13.7) or for everyone when the game ends (13.10). Nobody
  /// else's role is readable while the game is running.
  final String? role;

  /// True while the player is still allowed to submit last words.
  final bool canSayLastWords;
  final String? lastWords;
  final DateTime? lastWordsAt;
  final String? eliminatedBy;

  factory MafiaPlayer.fromMap(Map<String, dynamic> map, {required String id}) {
    return MafiaPlayer(
      userId: map['userId'] as String? ?? id,
      username: map['username'] as String? ?? id,
      avatar: map['avatar'] as String? ?? '',
      isAlive: map['isAlive'] != false,
      isDisconnected: map['isDisconnected'] == true,
      hasLeft: map['hasLeft'] == true,
      canSpeak: map['canSpeak'] != false,
      canVote: map['canVote'] != false,
      canUseAbility: map['canUseAbility'] != false,
      revealedRole: map['revealedRole'] == true,
      role: map['role'] as String?,
      canSayLastWords: map['canSayLastWords'] == true,
      lastWords: map['lastWords'] as String?,
      lastWordsAt: _date(map['lastWordsAt']),
      eliminatedBy: map['eliminatedBy'] as String?,
    );
  }
}

final class MafiaPrivateState {
  const MafiaPrivateState({
    this.role = '',
    this.team = '',
    this.assigned = false,
    this.mafiaTeammateIds = const <String>[],
    this.lastInvestigationResult,
    this.lastDonInvestigationResult,
    this.lastDoctorTargetId,
  });

  final String role;
  final String team;
  final bool assigned;
  final List<String> mafiaTeammateIds;
  final Map<String, dynamic>? lastInvestigationResult;
  final Map<String, dynamic>? lastDonInvestigationResult;

  /// Master Spec 13.3: the Doctor may protect themselves but never the same
  /// player two nights running. Kept client-side so the picker can grey it out;
  /// the server rejects it regardless.
  final String? lastDoctorTargetId;

  factory MafiaPrivateState.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MafiaPrivateState();
    final role = map['role'] as String? ?? '';
    return MafiaPrivateState(
      role: role,
      team: map['team'] as String? ?? '',
      assigned: role.isNotEmpty,
      mafiaTeammateIds: (map['mafiaTeammateIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      lastInvestigationResult: (map['lastInvestigationResult'] as Map?)
          ?.cast<String, dynamic>(),
      lastDonInvestigationResult: (map['lastDonInvestigationResult'] as Map?)
          ?.cast<String, dynamic>(),
      lastDoctorTargetId: map['lastDoctorTargetId'] as String?,
    );
  }
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  try {
    return value?.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}
