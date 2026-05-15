import 'package:cloud_firestore/cloud_firestore.dart';

class EditModel {
  final String id;
  final String uploaderId;
  final String uploaderName;
  final String uploaderAvatar;
  final String videoUrl;
  final String thumbnailUrl;
  final String animeTitle;
  final String caption;
  final List<String> likes;
  final int commentsCount;
  final int views;
  final DateTime createdAt;

  EditModel({
    required this.id,
    required this.uploaderId,
    required this.uploaderName,
    required this.uploaderAvatar,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.animeTitle,
    required this.caption,
    required this.likes,
    required this.commentsCount,
    required this.views,
    required this.createdAt,
  });

  EditModel copyWith({
    String? id,
    String? uploaderId,
    String? uploaderName,
    String? uploaderAvatar,
    String? videoUrl,
    String? thumbnailUrl,
    String? animeTitle,
    String? caption,
    List<String>? likes,
    int? commentsCount,
    int? views,
    DateTime? createdAt,
  }) {
    return EditModel(
      id: id ?? this.id,
      uploaderId: uploaderId ?? this.uploaderId,
      uploaderName: uploaderName ?? this.uploaderName,
      uploaderAvatar: uploaderAvatar ?? this.uploaderAvatar,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      animeTitle: animeTitle ?? this.animeTitle,
      caption: caption ?? this.caption,
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
      views: views ?? this.views,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory EditModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EditModel(
      id: doc.id,
      uploaderId: data['uploaderId'] ?? '',
      uploaderName: data['uploaderName'] ?? '',
      uploaderAvatar: data['uploaderAvatar'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      animeTitle: data['animeTitle'] ?? '',
      caption: data['caption'] ?? '',
      likes: List<String>.from(data['likes'] ?? []),
      commentsCount: data['commentsCount'] ?? 0,
      views: data['views'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uploaderId': uploaderId,
      'uploaderName': uploaderName,
      'uploaderAvatar': uploaderAvatar,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'animeTitle': animeTitle,
      'caption': caption,
      'likes': likes,
      'commentsCount': commentsCount,
      'views': views,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  bool isLikedBy(String userId) => likes.contains(userId);
}