import 'package:cloud_firestore/cloud_firestore.dart';

class InviteModel {
  final String inviteId;
  final String groupId;

  final String invitedUserId;
  final String invitedByUserId;

  final DateTime createdAt;

  const InviteModel({
    required this.inviteId,
    required this.groupId,
    required this.invitedUserId,
    required this.invitedByUserId,
    required this.createdAt,
  });

  // -------------------------
  // Firestore → Model
  // -------------------------

  factory InviteModel.fromMap(
    String inviteId,
    Map<String, dynamic> map,
  ) {
    return InviteModel(
      inviteId: inviteId,
      groupId: map['groupId'] as String,
      invitedUserId: map['invitedUserId'] as String,
      invitedByUserId: map['invitedByUserId'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  // -------------------------
  // Model → Firestore
  // -------------------------

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'invitedUserId': invitedUserId,
      'invitedByUserId': invitedByUserId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}