import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/mafia_constants.dart';

class MafiaGameModel {
  final String id;
  final String groupId;
  final String createdBy;
  final DateTime createdAt;
  final String version;
  final MafiaGameStatus status;
  final String currentPhase;
  final int currentDay;
  final int currentNight;
  final int playersCount;
  final int maxPlayers;
  final int minPlayers;
  final String? winner;
  final DateTime? countdownEndsAt;
  final DateTime? phaseEndsAt;
  final bool isLocked;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const MafiaGameModel({
    required this.id,
    required this.groupId,
    required this.createdBy,
    required this.createdAt,
    this.version = MafiaGameVersions.classic,
    this.status = MafiaGameStatus.waiting,
    this.currentPhase = 'waiting',
    this.currentDay = 0,
    this.currentNight = 0,
    this.playersCount = 0,
    this.maxPlayers = 8,
    this.minPlayers = 8,
    this.winner,
    this.countdownEndsAt,
    this.phaseEndsAt,
    this.isLocked = false,
    this.startedAt,
    this.endedAt,
  });

  factory MafiaGameModel.fromMap(String id, Map<String, dynamic> map) {
    return MafiaGameModel(
      id: id,
      groupId: map['groupId'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: map['createdAt'] != null
          ? _toDateTime(map['createdAt'])
          : DateTime.now(),
      version: map['version'] ?? MafiaGameVersions.classic,
      status: MafiaGameStatusExt.fromString(map['status'] as String?),
      currentPhase: map['currentPhase'] ?? 'waiting',
      currentDay: map['currentDay'] ?? 0,
      currentNight: map['currentNight'] ?? 0,
      playersCount: map['playersCount'] ?? 0,
      maxPlayers: map['maxPlayers'] ?? 8,
      minPlayers: map['minPlayers'] ?? 8,
      winner: map['winner'],
      countdownEndsAt: map['countdownEndsAt'] != null
          ? _toDateTime(map['countdownEndsAt'])
          : null,
      phaseEndsAt: map['phaseEndsAt'] != null
          ? _toDateTime(map['phaseEndsAt'])
          : null,
      isLocked: map['isLocked'] ?? false,
      startedAt: map['startedAt'] != null
          ? _toDateTime(map['startedAt'])
          : null,
      endedAt: map['endedAt'] != null
          ? _toDateTime(map['endedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'version': version,
      'status': status.name,
      'currentPhase': currentPhase,
      'currentDay': currentDay,
      'currentNight': currentNight,
      'playersCount': playersCount,
      'maxPlayers': maxPlayers,
      'minPlayers': minPlayers,
      'winner': winner,
      'countdownEndsAt': countdownEndsAt != null
          ? Timestamp.fromDate(countdownEndsAt!)
          : null,
      'phaseEndsAt': phaseEndsAt != null
          ? Timestamp.fromDate(phaseEndsAt!)
          : null,
      'isLocked': isLocked,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
    };
  }

  MafiaGameModel copyWith({
    String? id,
    String? groupId,
    String? createdBy,
    DateTime? createdAt,
    String? version,
    MafiaGameStatus? status,
    String? currentPhase,
    int? currentDay,
    int? currentNight,
    int? playersCount,
    int? maxPlayers,
    int? minPlayers,
    String? winner,
    DateTime? countdownEndsAt,
    DateTime? phaseEndsAt,
    bool? isLocked,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return MafiaGameModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
      status: status ?? this.status,
      currentPhase: currentPhase ?? this.currentPhase,
      currentDay: currentDay ?? this.currentDay,
      currentNight: currentNight ?? this.currentNight,
      playersCount: playersCount ?? this.playersCount,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      minPlayers: minPlayers ?? this.minPlayers,
      winner: winner ?? this.winner,
      countdownEndsAt: countdownEndsAt ?? this.countdownEndsAt,
      phaseEndsAt: phaseEndsAt ?? this.phaseEndsAt,
      isLocked: isLocked ?? this.isLocked,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}
