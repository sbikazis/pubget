import 'package:cloud_firestore/cloud_firestore.dart';

class FanModel {
  final String id;
  final String fanUserId;
  final String targetUserId;
  final DateTime createdAt;

  const FanModel({
    required this.id,
    required this.fanUserId,
    required this.targetUserId,
    required this.createdAt,
  });

  /// Create from Firestore
  factory FanModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return FanModel(
      id: documentId,
      fanUserId: map['fanUserId'] as String,
      targetUserId: map['targetUserId'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore
  Map<String, dynamic> toMap() {
    return {
      'fanUserId': fanUserId,
      'targetUserId': targetUserId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}