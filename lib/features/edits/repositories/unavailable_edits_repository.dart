import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/edit_models.dart';
import 'edits_repository.dart';

final class UnavailableEditsRepository implements EditsRepository {
  const UnavailableEditsRepository(this.message);
  final String message;

  FailureResult<T> _failure<T>() => FailureResult(UnknownError(message));

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
  }) async => _failure();

  @override
  Future<Result<void>> cancelUpload() async => _failure();

  @override
  Stream<Result<Edit>> watchEdit(String editId) => Stream.value(_failure());

  @override
  Future<Result<void>> retryProcessing(String editId) async => _failure();

  @override
  Future<Result<Edit>> finalizeEditUpload(String editId) async => _failure();

  @override
  Future<Result<EditPage>> getFeed({Edit? after, int limit = 5}) async =>
      _failure();

  @override
  Future<Result<List<Edit>>> getCreatorEdits(
    String creatorId, {
    int limit = 12,
  }) async => _failure();

  @override
  Future<Result<Edit>> getEdit(String editId) async => _failure();

  @override
  Future<Result<Edit>> repostEdit(String editId) async => _failure();

  @override
  Future<Result<void>> deleteEdit(String editId) async => _failure();

  @override
  Future<Result<void>> likeEdit({
    required String editId,
    required bool like,
  }) async => _failure();

  @override
  Future<Result<void>> addComment({
    required String editId,
    required String text,
    String? replyToCommentId,
    String kind = 'text',
    List<String> mentions = const <String>[],
  }) async => _failure();

  @override
  Future<Result<void>> recordView({
    required String editId,
    required String sessionId,
    required double watchPercent,
    required double watchSeconds,
    String eventType = 'progress',
  }) async => _failure();

  @override
  Future<Result<void>> recordImpression({
    required String editId,
    required String sessionId,
  }) async => _failure();

  @override
  Future<Result<String>> startPlayback(String editId) async => _failure();

  @override
  Future<Result<List<EditComment>>> getComments(
    String editId, {
    EditComment? after,
    int limit = 30,
    EditCommentSort sort = EditCommentSort.newest,
  }) async => _failure();

  @override
  Future<Result<void>> commentAction({
    required String editId,
    required String commentId,
    required String action,
  }) async => _failure();

  @override
  Future<Result<void>> recordSignal({
    required String editId,
    required String type,
  }) async => _failure();
}
