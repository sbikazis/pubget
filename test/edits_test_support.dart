import 'dart:async';

import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/edits/models/edit_models.dart';
import 'package:pubget/features/edits/repositories/edits_repository.dart';

Edit testEdit({
  String id = 'e1',
  String creatorId = 'alice',
  String status = 'published',
  DateTime? createdAt,
  DateTime? publishedAt,
  String? originalEditId,
  String? originalCreatorId,
  int likes = 2,
  int comments = 1,
  int views = 4,
}) {
  return Edit(
    id: id,
    creatorId: creatorId,
    videoUrl: 'edits-processed/$creatorId/$id.mp4',
    thumbnailUrl: 'edits/$creatorId/t_$id.jpg',
    caption: 'Gear five port',
    animeTag: 'one_piece',
    likesCount: likes,
    commentsCount: comments,
    viewsCount: views,
    score: 20,
    createdAt: createdAt ?? DateTime(2026, 8, 1),
    publishedAt: publishedAt ?? DateTime(2026, 8, 1),
    status: status,
    originalEditId: originalEditId,
    originalCreatorId: originalCreatorId ?? creatorId,
  );
}

final class FakeEditsRepository implements EditsRepository {
  FakeEditsRepository({List<Edit>? feed, List<EditComment>? comments})
    : feed = feed ?? <Edit>[testEdit()],
      comments = comments ??
          <EditComment>[
            EditComment(
              id: 'c1',
              authorId: 'bob',
              text: 'Insane timing',
              likesCount: 3,
              createdAt: DateTime(2026, 8, 2),
            ),
          ];

  List<Edit> feed;
  List<EditComment> comments;
  Failure? uploadFailure;
  Failure? likeFailure;
  var likeCalls = 0;
  var commentCalls = 0;
  var uploadCalls = 0;
  var lastLike = true;
  String? lastUploadStatus;
  String? lastIdempotencyKey;
  final _editController = StreamController<Result<Edit>>.broadcast();

  @override
  Future<Result<Edit>> uploadEdit({
    required EditUploadSource source,
    required String contentType,
    required String caption,
    required String animeTag,
    String? fileName,
    int? sizeBytes,
    String? idempotencyKey,
    String? resumeEditId,
    String? resumeVideoPath,
    UploadStarted? onStarted,
    UploadProgress? onProgress,
  }) async {
    uploadCalls += 1;
    lastIdempotencyKey = idempotencyKey;
    onStarted?.call(resumeEditId ?? 'draft-1', resumeVideoPath ?? 'edits/u/draft-1.mp4');
    onProgress?.call(1);
    if (uploadFailure != null) return FailureResult(uploadFailure!);
    lastUploadStatus = 'processing';
    return Success(testEdit(id: resumeEditId ?? 'draft-1', status: 'processing'));
  }

  @override
  Future<Result<void>> cancelUpload() async => const Success<void>(null);

  @override
  Stream<Result<Edit>> watchEdit(String editId) => _editController.stream;

  void emitEdit(Edit edit) => _editController.add(Success(edit));

  @override
  Future<Result<void>> retryProcessing(String editId) async =>
      const Success<void>(null);

  @override
  Future<Result<EditPage>> getFeed({Edit? after, int limit = 5}) async =>
      Success(EditPage(feed, hasMore: false));

  @override
  Future<Result<List<Edit>>> getCreatorEdits(
    String creatorId, {
    int limit = 12,
  }) async => Success(feed.where((edit) => edit.creatorId == creatorId).toList());

  @override
  Future<Result<Edit>> getEdit(String editId) async => Success(
    feed.firstWhere((edit) => edit.id == editId, orElse: () => testEdit()),
  );

  @override
  Future<Result<Edit>> repostEdit(String editId) async =>
      Success(testEdit(id: 'repost-1', originalEditId: editId));

  @override
  Future<Result<void>> deleteEdit(String editId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> likeEdit({
    required String editId,
    required bool like,
  }) async {
    likeCalls += 1;
    lastLike = like;
    if (likeFailure != null) return FailureResult(likeFailure!);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> addComment({
    required String editId,
    required String text,
    String? replyToCommentId,
    String kind = 'text',
    List<String> mentions = const <String>[],
  }) async {
    commentCalls += 1;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> recordView({
    required String editId,
    required String sessionId,
    required double watchPercent,
    required double watchSeconds,
    String eventType = 'progress',
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> recordImpression({
    required String editId,
    required String sessionId,
  }) async => const Success<void>(null);

  @override
  Future<Result<String>> startPlayback(String editId) async =>
      const Success('session-1');

  @override
  Future<Result<List<EditComment>>> getComments(
    String editId, {
    EditComment? after,
    int limit = 30,
    EditCommentSort sort = EditCommentSort.newest,
  }) async => Success(comments);

  @override
  Future<Result<void>> commentAction({
    required String editId,
    required String commentId,
    required String action,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> recordSignal({
    required String editId,
    required String type,
  }) async => const Success<void>(null);

  Future<void> close() async => _editController.close();
}
