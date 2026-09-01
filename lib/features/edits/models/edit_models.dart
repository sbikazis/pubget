import 'package:cloud_firestore/cloud_firestore.dart';

final class Edit {
  const Edit({
    required this.id,
    required this.creatorId,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.caption,
    required this.animeTag,
    required this.likesCount,
    required this.commentsCount,
    required this.viewsCount,
    required this.score,
    required this.createdAt,
    required this.status,
    this.originalEditId,
    this.repostedBy,
  });

  final String id;
  final String creatorId;
  final String videoUrl;
  final String thumbnailUrl;
  final String caption;
  final String animeTag;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final num score;
  final DateTime? createdAt;
  final String status;
  final String? originalEditId;
  final String? repostedBy;

  factory Edit.fromMap(Map<String, dynamic> map, {required String id}) {
    final date = map['createdAt'];
    return Edit(
      id: id,
      creatorId: map['creatorId'] as String? ?? '',
      videoUrl: map['videoUrl'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String? ?? '',
      caption: map['caption'] as String? ?? '',
      animeTag: map['animeTag'] as String? ?? '',
      likesCount: _int(map['likesCount']),
      commentsCount: _int(map['commentsCount']),
      viewsCount: _int(map['viewsCount']),
      score: map['score'] as num? ?? 0,
      createdAt: date is Timestamp
          ? date.toDate()
          : date is DateTime
          ? date
          : null,
      status: map['status'] as String? ?? 'processing',
      originalEditId: map['originalEditId'] as String?,
      repostedBy: map['repostedBy'] as String?,
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;
}

final class EditPage {
  const EditPage(this.items, {this.hasMore = false});
  final List<Edit> items;
  final bool hasMore;
}

final class EditComment {
  const EditComment({
    required this.id,
    required this.authorId,
    required this.text,
    required this.likesCount,
    this.createdAt,
    this.replyToCommentId,
  });
  final String id;
  final String authorId;
  final String text;
  final int likesCount;
  final DateTime? createdAt;
  final String? replyToCommentId;

  factory EditComment.fromMap(Map<String, dynamic> map, {required String id}) {
    final date = map['createdAt'];
    return EditComment(
      id: id,
      authorId: map['authorId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      likesCount: map['likesCount'] is num
          ? (map['likesCount'] as num).toInt()
          : 0,
      createdAt: date is Timestamp ? date.toDate() : null,
      replyToCommentId: map['replyToCommentId'] as String?,
    );
  }
}
