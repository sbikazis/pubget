import 'package:cloud_firestore/cloud_firestore.dart';

class RespectModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final int value;
  final DateTime createdAt;

  const RespectModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.value,
    required this.createdAt,
  });

  /// Create from Firestore
  factory RespectModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return RespectModel(
      id: documentId,
      fromUserId: map['fromUserId'] as String,
      toUserId: map['toUserId'] as String,
      value: map['value'] as int,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore
  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'value': value,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}