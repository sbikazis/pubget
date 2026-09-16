import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/l10n/app_strings.dart';
import 'package:pubget/features/edits/data/edit_draft_store.dart';
import 'package:pubget/features/edits/l10n/edit_copy.dart';
import 'package:pubget/features/edits/models/edit_models.dart';
import 'package:pubget/features/edits/repositories/firebase_edits_repository.dart';

void main() {
  test('mapEditException never surfaces raw Storage unauthorized text', () {
    final failure = mapEditException(
      FirebaseException(
        plugin: 'firebase_storage',
        code: 'unauthorized',
        message: 'User is not authorized to perform the desired action.',
      ),
    );
    expect(failure, isA<PermissionError>());
    expect(failure.message.toLowerCase(), isNot(contains('not authorized')));
    expect(failure.message.toLowerCase(), contains('securely'));
  });

  test('mapEditException maps permission-denied callables', () {
    final failure = mapEditException(
      FirebaseException(
        plugin: 'firebase_functions',
        code: 'permission-denied',
        message: 'Only the creator can retry this Edit.',
      ),
    );
    expect(failure, isA<PermissionError>());
  });

  test('EditDraftStore round-trips local path for resume', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = EditDraftStore();
    await store.save(<String, dynamic>{
      'caption': 'hi',
      'editId': 'e1',
      'videoPath': 'edits/u/e1.mp4',
      'localPath': '/tmp/clip.mp4',
      'phase': 'failed',
    });
    final loaded = await store.load();
    expect(loaded?['editId'], 'e1');
    expect(loaded?['localPath'], '/tmp/clip.mp4');
    expect(loaded?['phase'], 'failed');
    await store.clear();
    expect(await store.load(), isNull);
  });

  test('Arabic EditCopy hides technical auth failures', () {
    final copy = EditCopy(AppStrings.arabic);
    final message = copy.friendlyFailure(
      const PermissionError(
        'User is not authorized to perform the desired action.',
      ),
    );
    expect(message, contains('تعذر'));
    expect(message.toLowerCase(), isNot(contains('authorized')));
  });

  test('failureFor uses Arabic processing copy', () {
    final copy = EditCopy(AppStrings.arabic);
    final edit = Edit(
      id: 'e1',
      creatorId: 'a',
      videoUrl: '',
      thumbnailUrl: '',
      caption: '',
      animeTag: '',
      likesCount: 0,
      commentsCount: 0,
      viewsCount: 0,
      score: 0,
      createdAt: DateTime(2026, 1, 1),
      status: 'failed',
      failureReason: 'processing-failed',
    );
    expect(copy.failureFor(edit), contains('فشلت'));
  });
}
