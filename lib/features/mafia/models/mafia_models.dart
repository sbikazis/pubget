import 'package:cloud_firestore/cloud_firestore.dart';

enum MafiaPhase {
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

  bool get isLobby => status == 'waiting';
  bool get isFinished => status == 'finished' || status == 'cancelled';

  factory MafiaGame.fromMap(Map<String, dynamic> map, {required String id}) {
    return MafiaGame(
      id: id,
      groupId: map['groupId'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      status: map['status'] as String? ?? 'waiting',
      currentPhase: map['currentPhase'] as String? ?? 'waiting',
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
  });

  final String role;
  final String team;
  final bool assigned;

  factory MafiaPrivateState.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MafiaPrivateState();
    final role = map['role'] as String? ?? '';
    return MafiaPrivateState(
      role: role,
      team: map['team'] as String? ?? '',
      assigned: role.isNotEmpty,
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
