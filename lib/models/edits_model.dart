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

  // ── حقول النظام الذكي
  final double score;
  final int totalWatchSeconds;
  final double avgWatchPercent;

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
    this.score = 0.0,
    this.totalWatchSeconds = 0,
    this.avgWatchPercent = 0.0,
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
    double? score,
    int? totalWatchSeconds,
    double? avgWatchPercent,
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
      score: score ?? this.score,
      totalWatchSeconds: totalWatchSeconds ?? this.totalWatchSeconds,
      avgWatchPercent: avgWatchPercent ?? this.avgWatchPercent,
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
      score: (data['score'] ?? 0.0).toDouble(),
      totalWatchSeconds: data['totalWatchSeconds'] ?? 0,
      avgWatchPercent: (data['avgWatchPercent'] ?? 0.0).toDouble(),
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
      'score': score,
      'totalWatchSeconds': totalWatchSeconds,
      'avgWatchPercent': avgWatchPercent,
    };
  }

  bool isLikedBy(String userId) => likes.contains(userId);

  // ── حساب النقاط محلياً
  double computeScore() {
    final ageHours =
        DateTime.now().difference(createdAt).inHours.toDouble();
    final interactionScore =
        (likes.length * 3.0) + (views * 0.5) + (commentsCount * 2.0);
    final watchScore = avgWatchPercent * 10.0;
    final decayFactor = 1.0 / (1.0 + (ageHours / 24.0));
    return (interactionScore + watchScore) * decayFactor +
        (1.0 / (1.0 + ageHours * 0.01));
  }
}

// ══════════════════════════════════════════════
// ── موديل التعليقات الجديد
// ══════════════════════════════════════════════
class CommentModel {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String text;
  final DateTime createdAt;
  final List<String> likes;

  CommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.text,
    required this.createdAt,
    this.likes = const [],
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['username'] ?? data['userName'] ?? '',
      userAvatar: data['userAvatar'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: List<String>.from(data['likes'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': userName,
      'userAvatar': userAvatar,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': likes,
    };
  }

  CommentModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    String? text,
    DateTime? createdAt,
    List<String>? likes,
  }) {
    return CommentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
    );
  }
}