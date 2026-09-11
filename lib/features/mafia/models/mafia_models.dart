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
    this.startedAt,
    this.endedAt,
    this.stateVersion = 0,
    this.revoteCount = 0,
    this.revotePending = false,
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
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int stateVersion;
  final int revoteCount;
  final bool revotePending;

  bool get isLobby => _canonical(status) == 'WAITING';
  String get phase => _canonical(currentPhase);
  bool get isFinished =>
      _canonical(status) == 'GAME_OVER' || _canonical(status) == 'CANCELLED';
  bool get canLeaveViaServer => const {
    'STARTING',
    'ROLE_REVEAL',
    'NIGHT',
    'DAY',
    'DISCUSSION',
    'VOTING',
    'VOTE_RESULT',
    'RESOLUTION',
  }.contains(_canonical(status));

  factory MafiaGame.fromMap(Map<String, dynamic> map, {required String id}) {
    return MafiaGame(
      id: id,
      groupId: map['groupId'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      status: _canonical(map['status'] as String? ?? 'WAITING'),
      currentPhase: _canonical(map['currentPhase'] as String? ?? 'WAITING'),
      playersCount: (map['playersCount'] as num?)?.toInt() ?? 0,
      minPlayers: (map['minPlayers'] as num?)?.toInt() ?? 4,
      maxPlayers: (map['maxPlayers'] as num?)?.toInt() ?? 8,
      currentDay: (map['currentDay'] as num?)?.toInt() ?? 0,
      currentNight: (map['currentNight'] as num?)?.toInt() ?? 0,
      winner: map['winner'] as String?,
      countdownEndsAt: _date(map['countdownEndsAt']),
      phaseEndsAt: _date(map['phaseEndsAt']),
      startedAt: _date(map['startedAt']),
      endedAt: _date(map['endedAt']),
      stateVersion: (map['stateVersion'] as num?)?.toInt() ?? 0,
      revoteCount: (map['revoteCount'] as num?)?.toInt() ?? 0,
      revotePending: map['revotePending'] == true,
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
    );
  }
}

final class MafiaPrivateState {
  const MafiaPrivateState({
    this.role = '',
    this.team = '',
    this.assigned = false,
    this.mafiaTeammates = const <String>[],
    this.lastInvestigationResult,
    this.lastDonInvestigationResult,
  });

  final String role;
  final String team;
  final bool assigned;
  final List<String> mafiaTeammates;
  final Map<String, dynamic>? lastInvestigationResult;
  final Map<String, dynamic>? lastDonInvestigationResult;

  factory MafiaPrivateState.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MafiaPrivateState();
    final role = map['role'] as String? ?? '';
    return MafiaPrivateState(
      role: role,
      team: map['team'] as String? ?? '',
      assigned: role.isNotEmpty,
      mafiaTeammates: (map['mafiaTeammates'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      lastInvestigationResult: (map['lastInvestigationResult'] as Map?)
          ?.cast<String, dynamic>(),
      lastDonInvestigationResult: (map['lastDonInvestigationResult'] as Map?)
          ?.cast<String, dynamic>(),
    );
  }
}

String _canonical(String value) {
  switch (value.toLowerCase()) {
    case 'waiting':
      return 'WAITING';
    case 'starting':
      return 'STARTING';
    case 'role_reveal':
      return 'ROLE_REVEAL';
    case 'night':
      return 'NIGHT';
    case 'day':
      return 'DAY';
    case 'discussion':
      return 'DISCUSSION';
    case 'voting':
      return 'VOTING';
    case 'vote_result':
      return 'VOTE_RESULT';
    case 'resolution':
    case 'execution':
      return 'RESOLUTION';
    case 'finished':
    case 'game_over':
      return 'GAME_OVER';
    case 'cancelled':
      return 'CANCELLED';
    default:
      return value.toUpperCase();
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
