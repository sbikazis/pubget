import '../../../core/errors/result.dart';
import '../models/fan_work_models.dart';

abstract interface class FanWorkDraftStore {
  Future<void> write(String key, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> read(String key);
  Future<void> delete(String key);
}

abstract interface class FanWorkRepository {
  Future<Result<String>> saveDraft(FanWorkDraft draft);

  Future<Result<void>> deleteDraft(String workId);

  Future<Result<FanWork>> publish(String workId);

  Future<Result<void>> archive(String workId);

  Future<Result<FanWorkUploadTicket>> startMediaUpload({
    required String workId,
    required String contentType,
  });

  Future<Result<void>> uploadMediaBytes({
    required FanWorkUploadTicket ticket,
    required List<int> bytes,
    required String contentType,
  });

  Future<Result<void>> confirmMedia({
    required String workId,
    required String mediaId,
    required String path,
    required FanWorkMediaRole role,
    String caption = '',
  });

  Future<Result<void>> like({required String workId, required bool like});

  Future<Result<void>> bookmark({
    required String workId,
    required bool bookmark,
  });

  Future<Result<void>> report({
    required String workId,
    required FanWorkReportReason reason,
    String details,
  });

  Future<Result<void>> revisePublished({
    required String workId,
    String? title,
    String? description,
    FanWorkCopyright? copyright,
    List<String>? tags,
  });

  Future<Result<void>> requestRemoval({
    required String workId,
    String details,
  });

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
}
