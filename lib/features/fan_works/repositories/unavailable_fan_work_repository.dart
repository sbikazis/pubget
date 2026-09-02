import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/fan_work_models.dart';
import 'fan_work_repository.dart';

final class UnavailableFanWorkRepository implements FanWorkRepository {
  UnavailableFanWorkRepository(this.message);

  final String message;

  FailureResult<T> _fail<T>() => FailureResult<T>(UnknownError(message));

  @override
  Future<Result<String>> saveDraft(FanWorkDraft draft) async => _fail();

  @override
  Future<Result<void>> deleteDraft(String workId) async => _fail();

  @override
  Future<Result<FanWork>> publish(String workId) async => _fail();

  @override
  Future<Result<void>> archive(String workId) async => _fail();

  @override
  Future<Result<FanWorkUploadTicket>> startMediaUpload({
    required String workId,
    required String contentType,
  }) async => _fail();

  @override
  Future<Result<void>> uploadMediaBytes({
    required FanWorkUploadTicket ticket,
    required List<int> bytes,
    required String contentType,
  }) async => _fail();

  @override
  Future<Result<void>> confirmMedia({
    required String workId,
    required String mediaId,
    required String path,
    required FanWorkMediaRole role,
    String caption = '',
  }) async => _fail();

  @override
  Future<Result<void>> like({required String workId, required bool like}) async =>
      _fail();

  @override
  Future<Result<void>> bookmark({
    required String workId,
    required bool bookmark,
  }) async => _fail();

  @override
  Future<Result<void>> report({
    required String workId,
    required FanWorkReportReason reason,
    String details = '',
  }) async => _fail();

  @override
  Stream<Result<FanWork>> watchWork(String workId) =>
      Stream<Result<FanWork>>.value(_fail());

  @override
  Future<Result<FanWork>> getWork(String workId) async => _fail();

  @override
  Future<Result<FanWorkListPage>> getPublicFeed({
    FanWorkType? type,
    String? animeId,
    FanWork? after,
    int limit = 20,
  }) async => _fail();

  @override
  Future<Result<FanWorkListPage>> getCreatorWorks({
    required String creatorId,
    FanWork? after,
    int limit = 20,
  }) async => _fail();

  @override
  Future<Result<List<FanWork>>> getMyDrafts({required String userId}) async =>
      _fail();

  @override
  Future<Result<List<FanWorkPreview>>> search(String query) async => _fail();

  @override
  Future<Result<bool>> hasLiked({
    required String workId,
    required String userId,
  }) async => _fail();

  @override
  Future<Result<bool>> hasBookmarked({
    required String workId,
    required String userId,
  }) async => _fail();
}
