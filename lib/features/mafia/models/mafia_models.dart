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
  bool get isFinished =>
      status == 'GAME_OVER' || status == 'CANCELLED';
  bool get canLeaveViaServer =>
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
      minPlayers: (map['minPlayers'] as num?)?.toInt() ?? 4,
      maxPlayers: (map['maxPlayers'] as num?)?.toInt() ?? 8,
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
    this.mafiaTeammateIds = const <String>[],
    this.lastInvestigationResult,
    this.lastDonInvestigationResult,
  });

  final String role;
  final String team;
  final bool assigned;
  final List<String> mafiaTeammateIds;
  final Map<String, dynamic>? lastInvestigationResult;
  final Map<String, dynamic>? lastDonInvestigationResult;

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