import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/roles.dart';

class MemberModel {
  final String userId;
  final String groupId;

  final Roles role;

  // Display inside group
  final String? displayName;
  final String? characterName;
  final String? characterImageUrl;
  final String? characterReason;

  final String? invitedByUserId;

  final DateTime joinedAt;

  const MemberModel({
    required this.userId,
    required this.groupId,
    required this.role,
    required this.joinedAt,
    this.displayName,
    this.characterName,
    this.characterImageUrl,
    this.characterReason,
    this.invitedByUserId,
  });

  // -------------------------
  // Firestore → Model
  // -------------------------

  factory MemberModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return MemberModel(
      userId: map['userId'] as String,
      groupId: map['groupId'] as String,
      role: Roles.fromString(map['role'] as String),
      displayName: map['displayName'] as String?,
      characterName: map['characterName'] as String?,
      characterImageUrl: map['characterImageUrl'] as String?,
      characterReason: map['characterReason'] as String?,
      invitedByUserId: map['invitedByUserId'] as String?,
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
    );
  }

  // -------------------------
  // Model → Firestore
  // -------------------------

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'groupId': groupId,
      'role': role.name,
      'displayName': displayName,
      'characterName': characterName,
      'characterImageUrl': characterImageUrl,
      'characterReason': characterReason,
      'invitedByUserId': invitedByUserId,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  // -------------------------
  // Copy With
  // -------------------------

  MemberModel copyWith({
    Roles? role,
    String? displayName,
    String? characterName,
    String? characterImageUrl,
    String? characterReason,
    String? invitedByUserId,
    DateTime? joinedAt,
  }) {
    return MemberModel(
      userId: userId,
      groupId: groupId,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      characterName: characterName ?? this.characterName,
      characterImageUrl:
          characterImageUrl ?? this.characterImageUrl,
      characterReason:
          characterReason ?? this.characterReason,
      invitedByUserId:
          invitedByUserId ?? this.invitedByUserId,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}