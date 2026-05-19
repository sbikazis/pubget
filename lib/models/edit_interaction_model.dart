import 'package:cloud_firestore/cloud_firestore.dart';

enum InteractionType {
  like,
  comment,
  share,
  profileVisit,
  watch,
  skip,
}

class EditInteractionModel {
  final String id;
  final String userId;
  final String editId;
  final String animeTitle;
  final String uploaderId;
  final InteractionType type;
  final int watchSeconds;
  final double watchPercent;
  final DateTime createdAt;

  EditInteractionModel({
    required this.id,
    required this.userId,
    required this.editId,
    required this.animeTitle,
    required this.uploaderId,
    required this.type,
    this.watchSeconds = 0,
    this.watchPercent = 0.0,
    required this.createdAt,
  });

  // وزن كل تفاعل في بناء بصمة الاهتمام
  double get weight {
    switch (type) {
      case InteractionType.like:         return 3.0;
      case InteractionType.comment:      return 4.0;
      case InteractionType.share:        return 5.0;
      case InteractionType.profileVisit: return 2.0;
      case InteractionType.watch:
        if (watchPercent >= 0.8) return 4.0;  // اهتمام حقيقي
        if (watchPercent >= 0.4) return 2.0;  // اهتمام متوسط
        return 0.5;                            // مشاهدة خفيفة
      case InteractionType.skip:         return -1.0; // إشارة سلبية
    }
  }

  factory EditInteractionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EditInteractionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      editId: data['editId'] ?? '',
      animeTitle: data['animeTitle'] ?? '',
      uploaderId: data['uploaderId'] ?? '',
      type: InteractionType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'watch'),
        orElse: () => InteractionType.watch,
      ),
      watchSeconds: data['watchSeconds'] ?? 0,
      watchPercent: (data['watchPercent'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'editId': editId,
      'animeTitle': animeTitle,
      'uploaderId': uploaderId,
      'type': type.name,
      'watchSeconds': watchSeconds,
      'watchPercent': watchPercent,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}