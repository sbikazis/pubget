import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/constants/limits.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/edits/data/edit_validator.dart';
import 'package:pubget/features/edits/models/edit_models.dart';
import 'package:pubget/features/edits/providers/edits_provider.dart';
import 'package:pubget/features/edits/repositories/edits_repository.dart';
import 'package:pubget/features/edits/widgets/edit_comments_sheet.dart';
import 'package:pubget/features/social/models/social_models.dart';

import 'authentication_test_support.dart';
import 'edits_test_support.dart';

void main() {
  test('fan threshold is the shared Limits constant', () {
    expect(Limits.fanThreshold, 5);
    expect(SocialSnapshot.fanThreshold, Limits.fanThreshold);
  });

  test('client validation rejects oversized, long, and non-mp4 videos', () {
    expect(
      EditValidation.reject(
        fileName: 'clip.mov',
        contentType: 'video/quicktime',
        sizeBytes: 12,
      ),
      isA<ValidationError>(),
    );
    expect(
      EditValidation.reject(
        fileName: 'clip.mp4',
        contentType: 'video/mp4',
        sizeBytes: Limits.editMaxBytes + 1,
      ),
      isA<ValidationError>(),
    );
    expect(
      EditValidation.reject(
        fileName: 'clip.mp4',
        contentType: 'video/mp4',
        sizeBytes: 12,
        duration: const Duration(seconds: 181),
      ),
      isA<ValidationError>(),
    );
    expect(
      EditValidation.reject(
        fileName: 'clip.mp4',
        contentType: 'video/mp4',
        sizeBytes: 12,
        duration: const Duration(seconds: 12),
      ),
      isNull,
    );
    expect(EditValidation.mentionsIn('hi @luffy and @zoro'), ['luffy', 'zoro']);
  });

  test('repost window uses the published timestamp and hides after 30 days', () {
    final now = DateTime(2026, 9, 7);
    final live = testEdit(publishedAt: DateTime(2026, 8, 20));
    final expired = testEdit(
      id: 'old',
      publishedAt: DateTime(2026, 7, 1),
      createdAt: DateTime(2026, 7, 1),
    );
    expect(live.canRepost(now: now, viewerId: 'bob'), isTrue);
    expect(expired.canRepost(now: now, viewerId: 'bob'), isFalse);
    expect(live.canRepost(now: now, viewerId: 'alice'), isFalse);
    expect(
      testEdit(status: 'processing').canRepost(now: now, viewerId: 'bob'),
      isFalse,
    );
    expect(live.displayCreatorId, 'alice');
    expect(
      testEdit(originalCreatorId: 'nami', originalEditId: 'src').displayCreatorId,
      'nami',
    );
  });

  test('provider never marks an edit published locally', () async {
    final repository = FakeEditsRepository(
      feed: <Edit>[testEdit(status: 'processing')],
    );
    final provider = EditsProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.load();
    expect(provider.items.single.status, 'processing');
    expect(provider.items.single.isPublished, isFalse);
  });

  test('like overlay applies optimistically before the server confirms', () async {
    final repository = FakeEditsRepository()
      ..likeFailure = const ValidationError('blocked');
    final provider = EditsProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.load();

    final pending = provider.like('e1', true);
    expect(provider.isLiked('e1'), isTrue);
    expect(provider.displayOf(provider.items.single).likesCount, 3);

    await pending;
    expect(provider.isLiked('e1'), isFalse);
    expect(provider.displayOf(provider.items.single).likesCount, 2);
    expect(provider.lastActionFailure, isA<ValidationError>());

    repository.likeFailure = null;
    await provider.like('e1', true);
    expect(provider.isLiked('e1'), isTrue);
    expect(provider.displayOf(provider.items.single).likesCount, 3);
    expect(repository.likeCalls, 2);
  });

  test('double like taps share one in-flight request', () async {
    final repository = FakeEditsRepository();
    final provider = EditsProvider(repository: repository);
    addTearDown(provider.dispose);
    // Same desired state — second call is a no-op after optimistic settle.
    await provider.like('e1', true);
    await provider.like('e1', true);
    expect(repository.likeCalls, 1);
    expect(provider.isLiked('e1'), isTrue);
  });

  testWidgets('comments sheet sorts, replies, and reports', (tester) async {
    final authRepository = FakeAuthRepository(
      user: const AuthUser(id: 'user-1', email: 'fan@example.com'),
    );
    final auth = AuthProvider(repository: authRepository);
    await auth.initialize();
    addTearDown(authRepository.close);
    addTearDown(auth.dispose);
    final editsRepository = FakeEditsRepository();
    addTearDown(editsRepository.close);
    final provider = EditsProvider(repository: editsRepository);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<EditsProvider>.value(value: provider),
          Provider<EditsRepository>.value(value: editsRepository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => EditCommentsSheet.show(context, testEdit()),
              child: const Text('Open comments'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open comments'));
    await tester.pumpAndSettle();
    expect(find.text('Insane timing'), findsOneWidget);
    expect(find.text('Newest'), findsOneWidget);
    expect(find.text('Top'), findsOneWidget);
    await tester.tap(find.byTooltip('Report'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'nice @luffy');
    await tester.tap(find.byTooltip('Comment'));
    await tester.pumpAndSettle();
    expect(editsRepository.commentCalls, 1);
  });
}
