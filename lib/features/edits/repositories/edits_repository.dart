import 'dart:typed_data';

import '../../../core/errors/result.dart';
import '../models/edit_models.dart';

typedef UploadProgress = void Function(double value);

abstract interface class EditsRepository {
  Future<Result<Edit>> uploadEdit({
    required Uint8List bytes,
    required String contentType,
    required String caption,
    required String animeTag,
    UploadProgress? onProgress,
  });
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
  });
  Future<Result<void>> recordView({
    required String editId,
    required String sessionId,
    required double watchPercent,
    required double watchSeconds,
  });
  Future<Result<String>> startPlayback(String editId);
  Future<Result<List<EditComment>>> getComments(String editId);
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
