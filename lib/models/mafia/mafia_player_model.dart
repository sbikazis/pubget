// lib/models/mafia/mafia_player_model.dart
//
// ✅ الإضافة الوحيدة: lastSeenAt — يُحدَّث دورياً (heartbeat) من
// الجهاز نفسه طالما شاشة اللعبة مفتوحة. disconnectHandler.js يقرأه
// ليقرر isDisconnected. بقية الملف كما هو من Stage 4.5 دون تغيير.

import 'package:cloud_firestore/cloud_firestore.dart';

class MafiaPlayerModel {
  final String id;
  final String userId;
  final String username;
  final String avatar;
  final bool isAlive;
  final bool isDisconnected;
  final bool isMuted;
  final bool hasLeft;
  final DateTime joinedAt;
  final DateTime? lastSeenAt;
  final int coinsEarned;
  final int votesReceived;
  final bool canSpeak;
  final bool canVote;
  final bool canUseAbility;
  final bool revealedRole;

  const MafiaPlayerModel({
    required this.id,
    required this.userId,
    required this.username,
    this.avatar = '',
    this.isAlive = true,
    this.isDisconnected = false,
    this.isMuted = false,
    this.hasLeft = false,
    required this.joinedAt,
    this.lastSeenAt,
    this.coinsEarned = 0,
    this.votesReceived = 0,
    this.canSpeak = true,
    this.canVote = true,
    this.canUseAbility = true,
    this.revealedRole = false,
  });

  factory MafiaPlayerModel.fromMap(String id, Map<String, dynamic> map) {
    return MafiaPlayerModel(
      id: id,
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      avatar: map['avatar'] ?? '',
      isAlive: map['isAlive'] ?? true,
      isDisconnected: map['isDisconnected'] ?? false,
      isMuted: map['isMuted'] ?? false,
      hasLeft: map['hasLeft'] ?? false,
      joinedAt: map['joinedAt'] != null
          ? _toDateTime(map['joinedAt'])
          : DateTime.now(),
      lastSeenAt: map['lastSeenAt'] != null
          ? _toDateTime(map['lastSeenAt'])
          : null,
      coinsEarned: map['coinsEarned'] ?? 0,
      votesReceived: map['votesReceived'] ?? 0,
      canSpeak: map['canSpeak'] ?? true,
      canVote: map['canVote'] ?? true,
      canUseAbility: map['canUseAbility'] ?? true,
      revealedRole: map['revealedRole'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'avatar': avatar,
      'isAlive': isAlive,
      'isDisconnected': isDisconnected,
      'isMuted': isMuted,
      'hasLeft': hasLeft,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastSeenAt': lastSeenAt != null ? Timestamp.fromDate(lastSeenAt!) : null,
      'coinsEarned': coinsEarned,
      'votesReceived': votesReceived,
      'canSpeak': canSpeak,
      'canVote': canVote,
      'canUseAbility': canUseAbility,
      'revealedRole': revealedRole,
    };
  }

  MafiaPlayerModel copyWith({
    String? username,
    String? avatar,
    bool? isAlive,
    bool? isDisconnected,
    bool? isMuted,
    bool? hasLeft,
    DateTime? joinedAt,
    DateTime? lastSeenAt,
    int? coinsEarned,
    int? votesReceived,
    bool? canSpeak,
    bool? canVote,
    bool? canUseAbility,
    bool? revealedRole,
  }) {
    return MafiaPlayerModel(
      id: id,
      userId: userId,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      isAlive: isAlive ?? this.isAlive,
      isDisconnected: isDisconnected ?? this.isDisconnected,
      isMuted: isMuted ?? this.isMuted,
      hasLeft: hasLeft ?? this.hasLeft,
      joinedAt: joinedAt ?? this.joinedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      coinsEarned: coinsEarned ?? this.coinsEarned,
      votesReceived: votesReceived ?? this.votesReceived,
      canSpeak: canSpeak ?? this.canSpeak,
      canVote: canVote ?? this.canVote,
      canUseAbility: canUseAbility ?? this.canUseAbility,
      revealedRole: revealedRole ?? this.revealedRole,
    );
  }
}

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}