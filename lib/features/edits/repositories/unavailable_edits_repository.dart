import 'dart:typed_data';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/edit_models.dart';
import 'edits_repository.dart';

final class UnavailableEditsRepository implements EditsRepository {
  const UnavailableEditsRepository(this.message);
  final String message;
  FailureResult<T> _fail<T>() => FailureResult(UnknownError(message));

  @override
  Future<Result<Edit>> uploadEdit({
    required Uint8List bytes,
    required String contentType,
    required String caption,
    required String animeTag,
    UploadProgress? onProgress,
  }) async => _fail();
  @override
  Future<Result<EditPage>> getFeed({Edit? after, int limit = 5}) async =>
      _fail();
  @override
  Future<Result<List<Edit>>> getCreatorEdits(
    String creatorId, {
    int limit = 12,
  }) async => _fail();
  @override
  Future<Result<Edit>> getEdit(String editId) async => _fail();
  @override
  Future<Result<Edit>> repostEdit(String editId) async => _fail();
  @override
  Future<Result<void>> deleteEdit(String editId) async => _fail();
  @override
  Future<Result<void>> likeEdit({
    required String editId,
    required bool like,
  }) async => _fail();
  @override
  Future<Result<void>> addComment({
    required String editId,
    required String text,
  }) async => _fail();
  @override
  Future<Result<void>> recordView({
    required String editId,
    required String sessionId,
    required double watchPercent,
    required double watchSeconds,
  }) async => _fail();
  @override
  Future<Result<String>> startPlayback(String editId) async => _fail();
  @override
  Future<Result<List<EditComment>>> getComments(String editId) async => _fail();
  @override
  Future<Result<void>> commentAction({
    required String editId,
    required String commentId,
    required String action,
  }) async => _fail();
  @override
  Future<Result<void>> recordSignal({
    required String editId,
    required String type,
  }) async => _fail();
}
