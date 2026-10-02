import '../../../core/errors/result.dart';
import '../models/fan_work_models.dart';

/// Progress callback for a Fan Work upload, `0..1` and monotonic. Defined here,
/// on the contract, so the repository interface and the upload client cannot
/// drift apart.
typedef FanWorkUploadProgress = void Function(double value);

abstract interface class FanWorkDraftStore {
  Future<void> write(String key, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> read(String key);
  Future<void> delete(String key);
}

abstract interface class CharacterFanWorkRepository {
  Future<Result<FanWorkListPage>> getCharacterFeed(
    String characterId, {
    FanWork? after,
    int limit = 20,
  });
}

abstract interface class FanWorkRepository {
  Future<Result<String>> saveDraft(FanWorkDraft draft);

  Future<Result<void>> deleteDraft(String workId);

  Future<Result<FanWork>> publish(String workId);

  Future<Result<void>> archive(String workId);

  /// The role travels with the request so the server can reject a PDF offered
  /// as an artwork slot (and the reverse) before it mints a session.
  Future<Result<FanWorkUploadTicket>> startMediaUpload({
    required String workId,
    required FanWorkMediaRole role,
    required String contentType,
  });

  Future<Result<void>> uploadMediaBytes({
    required FanWorkUploadTicket ticket,
    required List<int> bytes,
    required String contentType,
    FanWorkUploadProgress? onProgress,
  });

  Future<Result<void>> cancelMediaUpload();

  /// [characterId] is set only for [FanWorkMediaRole.characterPortrait], so the
  /// server can attach the file to one cast entry instead of the work itself.
  /// [pageCount] is set only for a PDF document.
  Future<Result<void>> confirmMedia({
    required String workId,
    required String mediaId,
    required String path,
    required FanWorkMediaRole role,
    String caption = '',
    String characterId = '',
    int? pageCount,
  });

  Future<Result<void>> like({required String workId, required bool like});

  Future<Result<void>> bookmark({
    required String workId,
    required bool bookmark,
  });

  Future<Result<void>> rate({required String workId, required int rating});

  Future<Result<int?>> myRating({
    required String workId,
    required String userId,
  });

  Future<Result<void>> report({
    required String workId,
    required FanWorkReportReason reason,
    String details,
  });

  Future<Result<void>> addComment({
    required String workId,
    required String text,
    String? replyToCommentId,
    String? eventId,
  });

  Future<Result<List<FanWorkComment>>> getComments(
    String workId, {
    FanWorkComment? after,
    int limit = 30,
  });

  Future<Result<void>> commentAction({
    required String workId,
    required String commentId,
    required String action,
  });

  Future<Result<void>> revisePublished({
    required String workId,
    String? title,
    String? description,
    FanWorkCopyright? copyright,
    List<String>? tags,
  });

  Future<Result<void>> requestRemoval({required String workId, String details});

  /// Mints the short-lived grant the in-app reader streams a PDF with. It is
  /// the only way a document byte leaves the platform, and it is refused for a
  /// work the caller may not read.
  Future<Result<FanWorkDocumentAccess>> getDocumentAccess({
    required String workId,
  });

  Future<Result<FanWorkReadingProgress>> getReadingProgress({
    required String workId,
    required String userId,
  });

  Future<Result<void>> saveReadingProgress({
    required String workId,
    required FanWorkReadingProgress progress,
  });

  Future<Result<void>> markAsRead({required String workId});

  Stream<Result<FanWork>> watchWork(String workId);

  Future<Result<FanWork>> getWork(String workId);

  Future<Result<FanWorkListPage>> getPublicFeed({
    FanWorkType? type,
    String? animeId,
    FanWork? after,
    int limit = 20,
  });

  Future<Result<FanWorkListPage>> getCreatorWorks({
    required String creatorId,
    FanWork? after,
    int limit = 20,
  });

  Future<Result<List<FanWork>>> getMyDrafts({required String userId});

  Future<Result<List<FanWorkPreview>>> search(String query);

  Future<Result<bool>> hasLiked({
    required String workId,
    required String userId,
  });

  Future<Result<bool>> hasBookmarked({
    required String workId,
    required String userId,
  });

  Future<Result<List<FanWorkRevision>>> getRevisions(String workId);

  Future<Result<FanWorkAnalytics>> getAnalytics(String creatorId);
}
