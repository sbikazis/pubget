import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/limits.dart';
import '../../../core/errors/failure.dart';

enum EditStatus {
  uploading,
  processing,
  published,
  failed,
  rejected,
  removed,
  deleted;

  static EditStatus parse(String? raw) {
    return EditStatus.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => EditStatus.processing,
    );
  }
}

final class EditCounters {
  const EditCounters({
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.saves = 0,
    this.respectReceived = 0,
    this.impressions = 0,
    this.views = 0,
    this.qualifiedViews = 0,
    this.completions = 0,
    this.replays = 0,
  });

  final int likes;
  final int comments;
  final int shares;
  final int saves;
  final int respectReceived;
  final int impressions;
  final int views;
  final int qualifiedViews;
  final int completions;
  final int replays;

  factory EditCounters.fromMap(Map<String, dynamic> map) {
    final nested = map['counters'];
    final counters = nested is Map
        ? Map<String, dynamic>.from(nested)
        : const <String, dynamic>{};
    int read(String nestedKey, String flatKey) {
      final value = counters[nestedKey] ?? map[flatKey];
      return value is num ? value.toInt() : 0;
    }
    return EditCounters(
      likes: read('likes', 'likesCount'),
      comments: read('comments', 'commentsCount'),
      shares: read('shares', 'sharesCount'),
      saves: read('saves', 'savesCount'),
      respectReceived: read('respectReceived', 'respectReceivedCount'),
      impressions: read('impressions', 'impressionsCount'),
      views: read('views', 'viewsCount'),
      qualifiedViews: read('qualifiedViews', 'qualifiedViewsCount'),
      completions: read('completions', 'completionCount'),
      replays: read('replays', 'replaysCount'),
    );
  }
}

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
    this.originalCreatorId,
    this.moderationStatus = 'pending',
    this.moderationReason,
    this.durationSeconds = 0,
    this.publishedAt,
    this.failureReason,
    this.counters = const EditCounters(),
    this.schemaVersion = 1,
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
  final String? originalCreatorId;
  final String moderationStatus;
  final String? moderationReason;
  final int durationSeconds;
  final DateTime? publishedAt;
  final String? failureReason;
  final EditCounters counters;
  final int schemaVersion;

  EditStatus get statusEnum => EditStatus.parse(status);
  bool get isPublished => statusEnum == EditStatus.published;
  bool get isProcessing =>
      statusEnum == EditStatus.uploading || statusEnum == EditStatus.processing;
  bool get isFailed =>
      statusEnum == EditStatus.failed || statusEnum == EditStatus.rejected;
  bool get isRepost => originalEditId != null && originalEditId!.isNotEmpty;
  String get displayCreatorId =>
      (originalCreatorId != null && originalCreatorId!.isNotEmpty)
      ? originalCreatorId!
      : creatorId;

  bool get hasPlayableVideo => videoUrl.trim().isNotEmpty && isPublished;
  bool get hasThumbnail => thumbnailUrl.trim().isNotEmpty;

  bool canReceiveRespectFrom(String? viewerId) {
    return viewerId != null &&
        viewerId.isNotEmpty &&
        viewerId != displayCreatorId;
  }

  bool canRepost({required DateTime now, String? viewerId}) {
    if (!isPublished) return false;
    if (viewerId != null && viewerId == creatorId) return false;
    final origin = publishedAt ?? createdAt;
    if (origin == null) return false;
    return now.difference(origin) <= Limits.editRepostWindow;
  }

  String get userFacingFailure {
    if (moderationStatus == 'flagged' || statusEnum == EditStatus.rejected) {
      return moderationReason ??
          'This Edit was flagged and was not published.';
    }
    return switch (failureReason) {
      'invalid-video' =>
        'This video is not a supported MP4, or it is too large.',
      'duration' => 'Videos can be up to 3 minutes long.',
      _ => 'Processing failed. You can retry or delete this draft.',
    };
  }

  Edit copyWith({
    int? likesCount,
    int? commentsCount,
    int? viewsCount,
    String? status,
    EditCounters? counters,
  }) {
    return Edit(
      id: id,
      creatorId: creatorId,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      caption: caption,
      animeTag: animeTag,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewsCount: viewsCount ?? this.viewsCount,
      score: score,
      createdAt: createdAt,
      status: status ?? this.status,
      originalEditId: originalEditId,
      repostedBy: repostedBy,
      originalCreatorId: originalCreatorId,
      moderationStatus: moderationStatus,
      moderationReason: moderationReason,
      durationSeconds: durationSeconds,
      publishedAt: publishedAt,
      failureReason: failureReason,
      counters: counters ?? this.counters,
      schemaVersion: schemaVersion,
    );
  }

  factory Edit.fromMap(Map<String, dynamic> map, {required String id}) {
    final counters = EditCounters.fromMap(map);
    return Edit(
      id: id,
      creatorId: map['creatorId'] as String? ?? '',
      videoUrl: (map['processedStoragePath'] as String?) ??
          map['videoUrl'] as String? ??
          '',
      thumbnailUrl: (map['thumbnailStoragePath'] as String?) ??
          map['thumbnailUrl'] as String? ??
          '',
      caption: map['caption'] as String? ?? '',
      animeTag: map['animeTag'] as String? ?? '',
      likesCount: counters.likes,
      commentsCount: counters.comments,
      viewsCount: counters.qualifiedViews > 0
          ? counters.qualifiedViews
          : counters.views,
      score: map['score'] as num? ?? 0,
      createdAt: _date(map['createdAt']),
      status: map['status'] as String? ?? 'processing',
      originalEditId: map['originalEditId'] as String?,
      repostedBy: map['repostedBy'] as String?,
      originalCreatorId: map['originalCreatorId'] as String?,
      moderationStatus: map['moderationStatus'] as String? ?? 'pending',
      moderationReason: map['moderationReason'] as String?,
      durationSeconds: _int(map['durationSeconds']),
      publishedAt: _date(map['publishedAt']),
      failureReason: map['failureReason'] as String?,
      counters: counters,
      schemaVersion: _int(map['schemaVersion'] ?? 1),
    );
  }

  static Failure? uploadTerminalFailure({
    required String? status,
    String? moderationReason,
  }) {
    if (status == 'published') return null;
    if (status == 'rejected') {
      return ValidationError(
        moderationReason ?? 'This Edit was flagged and was not published.',
      );
    }
    if (status == 'failed' || status == 'uploading' || status == 'processing') {
      return const ValidationError(
        'Video processing failed. Choose a valid MP4 and retry.',
      );
    }
    return const ValidationError(
      'Video processing failed. Choose a valid MP4 and retry.',
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) {
      final millis = value > 20000000000 ? value.toInt() : value.toInt() * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    if (value is String) return DateTime.tryParse(value);
    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'];
      if (seconds is num) {
        return DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000);
      }
    }
    return null;
  }
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
    this.kind = 'text',
    this.mentions = const <String>[],
  });
  final String id;
  final String authorId;
  final String text;
  final int likesCount;
  final DateTime? createdAt;
  final String? replyToCommentId;
  final String kind;
  final List<String> mentions;

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
      kind: map['kind'] as String? ?? 'text',
      mentions: (map['mentions'] is List)
          ? (map['mentions'] as List).whereType<String>().toList()
          : const <String>[],
    );
  }
}

final class EditUploadSource {
  const EditUploadSource.file(this.path) : bytes = null;
  const EditUploadSource.memory(this.bytes) : path = null;

  final String? path;
  final List<int>? bytes;

  int get size => bytes?.length ?? 0;
}

enum EditCommentSort { newest, top }
