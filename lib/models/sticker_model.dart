// lib/models/sticker_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class StickerModel {
  final String id;
  final String creatorId;
  final String imageUrl;
  final DateTime createdAt;

  const StickerModel({
    required this.id,
    required this.creatorId,
    required this.imageUrl,
    required this.createdAt,
  });

  factory StickerModel.fromMap(String id, Map<String, dynamic> map) {
    return StickerModel(
      id: id,
      creatorId: map['creatorId'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'creatorId': creatorId,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}