import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/edits/models/edit_models.dart';
import 'package:pubget/features/edits/providers/edit_upload_manager.dart';
import 'package:pubget/features/edits/repositories/edits_repository.dart';

import 'edits_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('enqueue leaves job active without awaiting upload completion', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final slow = _SlowUploadRepository();
    var uploadStarted = false;
    slow.onStart = () => uploadStarted = true;
    final manager = EditUploadManager(repository: slow);
    await manager.restore();

    final job = await manager.enqueue(
      caption: 'hi',
      animeTag: 'one_piece',
      contentType: 'video/mp4',
      fileName: 'clip.mp4',
      localPath: '/tmp/clip.mp4',
      sizeBytes: 1024,
    );
    // Enqueue returns before upload finishes — job is already tracked.
    expect(manager.hasVisibleJobs, isTrue);
    expect(job.localId, isNotEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(uploadStarted, isTrue);
    expect(
      manager.primaryJob?.phase,
      anyOf(
        EditUploadJobPhase.queued,
        EditUploadJobPhase.uploading,
        EditUploadJobPhase.processing,
      ),
    );

    slow.completeUpload();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(manager.primaryJob?.phase, EditUploadJobPhase.processing);

    manager.dispose();
  });

  test('failed job stays visible with retry path and draft persistence', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repo = FakeEditsRepository()
      ..uploadFailure = const NetworkError('offline');
    final manager = EditUploadManager(repository: repo);
    await manager.restore();
    await manager.enqueue(
      caption: 'draft',
      animeTag: '',
      contentType: 'video/mp4',
      fileName: 'wide.mp4',
      localPath: '/tmp/wide.mp4',
      sizeBytes: 2048,
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(manager.primaryJob?.isFailed, isTrue);
    expect(manager.primaryJob?.errorMessage, contains('offline'));

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('edit_upload_queue_v2');
    expect(raw, isNotNull);
    expect(raw, contains('wide.mp4'));

    manager.dispose();
    await repo.close();
  });

  test('EditStatus parses needs_review for moderation hold', () {
    expect(EditStatus.parse('needs_review'), EditStatus.needsReview);
    final edit = testEdit(status: 'needs_review');
    expect(edit.isNeedsReview, isTrue);
    expect(edit.isPublished, isFalse);
  });

  test('restore resurrects processing jobs for global bar', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'edit_upload_queue_v2':
          '[{"localId":"local-1","caption":"x","animeTag":"","contentType":"video/mp4","fileName":"a.mp4","localPath":"/tmp/a.mp4","editId":"e99","videoPath":"edits/u/e99.mp4","phase":"processing","progress":1}]',
    });
    final repo = FakeEditsRepository();
    final manager = EditUploadManager(repository: repo);
    await manager.restore();
    expect(manager.hasVisibleJobs, isTrue);
    expect(manager.primaryJob?.editId, 'e99');
    expect(manager.primaryJob?.phase, EditUploadJobPhase.processing);
    manager.dispose();
    await repo.close();
  });
}

final class _SlowUploadRepository implements EditsRepository {
  void Function() onStart = () {};
  Completer<Result<Edit>>? _gate;

  void completeUpload() {
    _gate?.complete(Success(testEdit(id: 'draft-1', status: 'processing')));
  }

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
    onStart();
    onStarted?.call(
      resumeEditId ?? 'draft-1',
      resumeVideoPath ?? 'edits/u/draft-1.mp4',
    );
    onProgress?.call(0.4);
    _gate = Completer<Result<Edit>>();
    return _gate!.future;
  }

  @override
  Future<Result<void>> cancelUpload() async => const Success<void>(null);

  @override
  Stream<Result<Edit>> watchEdit(String editId) =>
      const Stream<Result<Edit>>.empty();

  @override
  Future<Result<void>> retryProcessing(String editId) async =>
      const Success<void>(null);

  @override
  Future<Result<Edit>> finalizeEditUpload(String editId) async =>
      Success(testEdit(id: editId, status: 'processing'));

  @override
  Future<Result<EditPage>> getFeed({Edit? after, int limit = 5}) async =>
      const Success(EditPage(<Edit>[], hasMore: false));

  @override
  Future<Result<List<Edit>>> getCreatorEdits(
    String creatorId, {
    int limit = 12,
  }) async => const Success(<Edit>[]);

  @override
  Future<Result<Edit>> getEdit(String editId) async =>
      Success(testEdit(id: editId, status: 'processing'));

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
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> addComment({
    required String editId,
    required String text,
    String? replyToCommentId,
    String kind = 'text',
    List<String> mentions = const <String>[],
  }) async => const Success<void>(null);

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
  }) async => const Success(<EditComment>[]);

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
}
