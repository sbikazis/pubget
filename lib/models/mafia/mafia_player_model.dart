import 'package:cloud_firestore/cloud_firestore.dart';

class MafiaPlayerModel {
  final String id;
  final String userId;
  final String username;
  final String avatar;
  final String role;
  final String team;
  final bool isAlive;
  final bool isDisconnected;
  final bool isMuted;
  final bool hasLeft;
  final DateTime joinedAt;
  final int coinsEarned;
  final int votesReceived;
  final String? voteTarget;
  final String? nightTarget;
  final bool usedAbility;
  final bool usedBullet;
  final bool canSpeak;
  final bool canVote;
  final bool canUseAbility;
  final bool revealedRole;

  const MafiaPlayerModel({
    required this.id,
    required this.userId,
    required this.username,
    this.avatar = '',
    this.role = '',
    this.team = '',
    this.isAlive = true,
    this.isDisconnected = false,
    this.isMuted = false,
    this.hasLeft = false,
    required this.joinedAt,
    this.coinsEarned = 0,
    this.votesReceived = 0,
    this.voteTarget,
    this.nightTarget,
    this.usedAbility = false,
    this.usedBullet = false,
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
      role: map['role'] ?? '',
      team: map['team'] ?? '',
      isAlive: map['isAlive'] ?? true,
      isDisconnected: map['isDisconnected'] ?? false,
      isMuted: map['isMuted'] ?? false,
      hasLeft: map['hasLeft'] ?? false,
      joinedAt: map['joinedAt'] != null
          ? _toDateTime(map['joinedAt'])
          : DateTime.now(),
      coinsEarned: map['coinsEarned'] ?? 0,
      votesReceived: map['votesReceived'] ?? 0,
      voteTarget: map['voteTarget'],
      nightTarget: map['nightTarget'],
      usedAbility: map['usedAbility'] ?? false,
      usedBullet: map['usedBullet'] ?? false,
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
      'role': role,
      'team': team,
      'isAlive': isAlive,
      'isDisconnected': isDisconnected,
      'isMuted': isMuted,
      'hasLeft': hasLeft,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'coinsEarned': coinsEarned,
      'votesReceived': votesReceived,
      'voteTarget': voteTarget,
      'nightTarget': nightTarget,
      'usedAbility': usedAbility,
      'usedBullet': usedBullet,
      'canSpeak': canSpeak,
      'canVote': canVote,
      'canUseAbility': canUseAbility,
      'revealedRole': revealedRole,
    };
  }

  MafiaPlayerModel copyWith({
    String? username,
    String? avatar,
    String? role,
    String? team,
    bool? isAlive,
    bool? isDisconnected,
    bool? isMuted,
    bool? hasLeft,
    DateTime? joinedAt,
    int? coinsEarned,
    int? votesReceived,
    String? voteTarget,
    String? nightTarget,
    bool? usedAbility,
    bool? usedBullet,
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
      role: role ?? this.role,
      team: team ?? this.team,
      isAlive: isAlive ?? this.isAlive,
      isDisconnected: isDisconnected ?? this.isDisconnected,
      isMuted: isMuted ?? this.isMuted,
      hasLeft: hasLeft ?? this.hasLeft,
      joinedAt: joinedAt ?? this.joinedAt,
      coinsEarned: coinsEarned ?? this.coinsEarned,
      votesReceived: votesReceived ?? this.votesReceived,
      voteTarget: voteTarget ?? this.voteTarget,
      nightTarget: nightTarget ?? this.nightTarget,
      usedAbility: usedAbility ?? this.usedAbility,
      usedBullet: usedBullet ?? this.usedBullet,
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
  return DateTime.now();}
