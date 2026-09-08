import '../../../core/errors/result.dart';
import '../models/edit_models.dart';

typedef UploadProgress = void Function(double value);
typedef UploadStarted = void Function(String editId, String videoPath);

abstract interface class EditsRepository {
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
  });

  /// After Storage upload succeeds — kicks server processing idempotently.
  Future<Result<Edit>> finalizeEditUpload(String editId);

  Future<Result<void>> cancelUpload();
  Stream<Result<Edit>> watchEdit(String editId);
  Future<Result<void>> retryProcessing(String editId);
  Future<Result<EditPage>> getFeed({Edit? after, int limit = 5});
  Future<Result<List<Edit>>> getCreatorEdits(
    String creatorId, {
    int limit = 12,
  });
  Future<Result<Edit>> getEdit(String editId);
  Future<Result<Edit>> repostEdit(String editId);
  Future<Result<void>> deleteEdit(String editId);
  Future<Result<void>> likeEdit({required String editId, required bool like});
  Future<Result<void>> addComment({
    required String editId,
    required String text,
    String? replyToCommentId,
    String kind,
    List<String> mentions,
  });
  Future<Result<void>> recordView({
    required String editId,
    required String sessionId,
    required double watchPercent,
    required double watchSeconds,
    String eventType,
  });
  Future<Result<void>> recordImpression({
    required String editId,
    required String sessionId,
  });
  Future<Result<String>> startPlayback(String editId);
  Future<Result<List<EditComment>>> getComments(
    String editId, {
    EditComment? after,
    int limit = 30,
    EditCommentSort sort,
  });
  Future<Result<void>> commentAction({
    required String editId,
    required String commentId,
    required String action,
  });
  Future<Result<void>> recordSignal({
    required String editId,
    required String type,
  });
}
