// lib/models/respect_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// ✅ RespectModel: النموذج المسؤول عن بيانات الاحترام فقط
/// تم فصله عن الواجهات لضمان نظافة الكود (Clean Architecture)
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

  /// إنشاء كائن من بيانات Firestore
  factory RespectModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return RespectModel(
      id: documentId,
      fromUserId: map['fromUserId'] as String? ?? '',
      toUserId: map['toUserId'] as String? ?? '',
      value: (map['value'] as num? ?? 0).toInt(), // التأكد من التحويل لـ int بأمان
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// تحويل الكائن إلى Map لإرساله لـ Firestore
  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'value': value,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}