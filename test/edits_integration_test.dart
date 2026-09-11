import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/links/pubget_links.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/edits/providers/edit_upload_manager.dart';
import 'package:pubget/features/social/models/social_models.dart';
import 'package:pubget/features/social/providers/social_provider.dart';
import 'package:pubget/features/social/repositories/social_repository.dart';

import 'edits_test_support.dart';
import 'social_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('edit highlight deep link encodes the edit id', () {
    expect(
      PubgetLinks.editHighlightPath('abc 1'),
      '/edits?highlight=abc+1',
    );
    expect(PubgetLinks.editHighlight('e9'), contains('highlight=e9'));
  });

  test('soft navigate policy can defer force navigation', () {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final manager = EditUploadManager(
      repository: FakeEditsRepository(),
      shouldForceNavigateToPublished: (_) => false,
    );
    expect(manager.shouldForceNavigateToPublished?.call('new1'), isFalse);
    manager.acceptSoftPublishedOffer('new1');
    expect(manager.highlightEditId, 'new1');
    expect(manager.consumeHighlightEditId(), 'new1');
    manager.dispose();
  });

  test('queue keeps multiple jobs visible for the global bar', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'edit_upload_queue_v2':
          '[{"localId":"a","caption":"","animeTag":"","contentType":"video/mp4","fileName":"one.mp4","localPath":"/tmp/one.mp4","editId":"e1","videoPath":"edits/u/e1.mp4","phase":"uploading","progress":0.4},{"localId":"b","caption":"","animeTag":"","contentType":"video/mp4","fileName":"two.mp4","localPath":"/tmp/two.mp4","editId":"e2","videoPath":"edits/u/e2.mp4","phase":"processing","progress":1}]',
    });
    final slow = FakeEditsRepository();
    final manager = EditUploadManager(repository: slow);
    await manager.restore();
    expect(manager.jobs.length, 2);
    expect(
      manager.jobs.map((job) => job.fileName).toSet(),
      containsAll(<String>['one.mp4', 'two.mp4']),
    );
    manager.dispose();
    await slow.close();
  });

  test('respect from social path updates fan relation in snapshot', () async {
    final repository = FakeSocialRepository();
    final provider = SocialProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.load('viewer-1');

    final result = await provider.giveRespect(
      toUserId: 'creator-9',
      value: 5,
      silentFailure: true,
    );
    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, isTrue);
    expect(
      provider.snapshot.givenRespect.any(
        (item) =>
            item.toUserId == 'creator-9' &&
            item.value >= SocialSnapshot.fanThreshold,
      ),
      isTrue,
    );
    expect(repository.respectCalls, 1);
  });

  test('silent respect failure rolls back without error state', () async {
    final failing = _FailingRespectRepo();
    final silent = SocialProvider(repository: failing);
    addTearDown(silent.dispose);
    await silent.load('viewer-1');
    final result = await silent.giveRespect(
      toUserId: 'creator-9',
      value: 5,
      silentFailure: true,
    );
    expect(result.isSuccess, isFalse);
    expect(
      silent.snapshot.givenRespect.any((item) => item.toUserId == 'creator-9'),
      isFalse,
    );
    expect(silent.failure, isNull);
    expect(silent.state, LoadingState.loaded);
  });
}

final class _FailingRespectRepo implements SocialRepository {
  @override
  Future<Result<SocialSnapshot>> getSnapshot(String userId) async =>
      const Success(SocialSnapshot());

  @override
  Future<Result<void>> giveRespect({
    required String toUserId,
    required int value,
  }) async =>
      const FailureResult(NetworkError('offline'));

  @override
  Future<Result<void>> sendFriendRequest({required String toUserId}) async =>
      const Success(null);

  @override
  Future<Result<void>> respondToFriendRequest({
    required String otherUserId,
    required String response,
  }) async =>
      const Success(null);

  @override
  Future<Result<void>> removeFriend({required String otherUserId}) async =>
      const Success(null);

  @override
  Future<Result<void>> blockUser({required String otherUserId}) async =>
      const Success(null);

  @override
  Future<Result<void>> unblockUser({required String otherUserId}) async =>
      const Success(null);
}
