import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' show PdfViewer;
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/fan_works/models/fan_work_lifecycle.dart';
import 'package:pubget/features/fan_works/models/fan_work_models.dart';
import 'package:pubget/features/fan_works/providers/fan_work_providers.dart';
import 'package:pubget/features/fan_works/repositories/fan_work_repository.dart';
import 'package:pubget/features/fan_works/screens/fan_work_reader_page.dart';
import 'package:pubget/features/fan_works/screens/fan_work_screens.dart';

import 'authentication_test_support.dart';

void main() {
  testWidgets('fan works feed shows empty copy', (tester) async {
    final auth = await _auth();
    final repository = _FakeFanWorkRepository();
    final feed = FanWorkFeedProvider(repository: repository);
    addTearDown(feed.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<FanWorkFeedProvider>.value(value: feed),
        ],
        child: const MaterialApp(home: FanWorkFeedPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(FanWorkStrings.emptyTitle), findsWidgets);
  });

  testWidgets('details shows a missing-work empty state', (tester) async {
    final auth = await _auth();
    final repository = _FakeFanWorkRepository();
    final details = FanWorkDetailsProvider(repository: repository);
    addTearDown(details.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<FanWorkDetailsProvider>.value(value: details),
        ],
        child: const MaterialApp(home: FanWorkDetailsPage(workId: 'missing')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(FanWorkStrings.missing), findsWidgets);
    expect(find.byType(PubgetEmptyState), findsOneWidget);
  });

  testWidgets('create work lists typed editors', (tester) async {
    final repository = _FakeFanWorkRepository();
    final editor = FanWorkEditorProvider(repository: repository);
    addTearDown(editor.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<FanWorkEditorProvider>.value(
        value: editor,
        child: const MaterialApp(home: FanWorkEditorPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(FanWorkTypeCatalog.label(FanWorkType.manga)),
      findsOneWidget,
    );
    // Only the four creatable types are offered; the legacy read-only types are
    // never selectable.
    for (final type in FanWorkType.creatable) {
      expect(find.byKey(Key('fan-work-type-${type.name}')), findsOneWidget);
    }
    expect(find.byKey(const Key('fan-work-type-aiCharacter')), findsNothing);
    expect(find.byKey(const Key('fan-work-type-worldbuilding')), findsNothing);
    await tester.tap(
      find.text(FanWorkTypeCatalog.label(FanWorkType.character)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fan-work-title')), findsOneWidget);
  });

  testWidgets('editor shows upload progress and retry after cancellation', (
    tester,
  ) async {
    final repository = _FakeFanWorkRepository()
      ..uploadCompleter = Completer<Result<void>>();
    final editor = FanWorkEditorProvider(repository: repository);
    addTearDown(editor.dispose);
    await editor.start();

    await tester.pumpWidget(
      ChangeNotifierProvider<FanWorkEditorProvider>.value(
        value: editor,
        child: const MaterialApp(home: FanWorkEditorPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final upload = editor.uploadMedia(
      bytes: <int>[1, 2, 3],
      contentType: 'image/jpeg',
      role: FanWorkMediaRole.artwork,
    );
    for (
      var attempt = 0;
      attempt < 10 && repository.uploadAttempts == 0;
      attempt += 1
    ) {
      await tester.pump();
    }
    await tester.pump();

    expect(find.text('35% uploaded'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('fan-work-upload-progress')),
    );
    expect(progress.value, closeTo(0.35, 0.001));
    expect(find.byKey(const Key('fan-work-upload-cancel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('fan-work-upload-cancel')));
    await tester.pump();
    final canceled = await upload;
    await tester.pump();

    expect(canceled.failureOrNull, isA<CancelledError>());
    expect(editor.uploadCanceled, isTrue);
    expect(find.text(FanWorkStrings.uploadCanceled), findsOneWidget);
    expect(find.byKey(const Key('fan-work-upload-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('fan-work-upload-retry')));
    for (var attempt = 0; attempt < 20; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(repository.uploadAttempts, 2);
    expect(editor.uploadFailed, isFalse);
    expect(find.byKey(const Key('fan-work-upload-status')), findsNothing);
  });

  testWidgets('a legacy page-image manga routes itself to the page reader', (
    tester,
  ) async {
    final auth = await _auth();
    // `_manga()` has page images and no PDF, so opening it through the normal
    // reader route has to land on the legacy page viewer rather than on a PDF
    // viewer that would find nothing to open.
    final repository = _FakeFanWorkRepository()..works['manga-1'] = _manga();
    final reader = FanWorkReaderProvider(repository: repository);
    addTearDown(reader.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<FanWorkReaderProvider>.value(value: reader),
        ],
        child: const MaterialApp(home: FanWorkReaderPage(workId: 'manga-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LegacyMangaPagesPage), findsOneWidget);
    expect(find.byType(PdfViewer), findsNothing);
    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(find.text('Splash'), findsOneWidget);
    expect(find.byKey(const Key('fan-work-legacy-pages')), findsOneWidget);
    // A legacy row has no grant to mint, so none was requested.
    expect(repository.documentAccessCalls, 0);
  });

  testWidgets('a legacy prose story routes itself to the prose reader', (
    tester,
  ) async {
    final auth = await _auth();
    final repository = _FakeFanWorkRepository()..works['story-1'] = _story();
    final reader = FanWorkReaderProvider(repository: repository);
    addTearDown(reader.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<FanWorkReaderProvider>.value(value: reader),
        ],
        child: const MaterialApp(home: FanWorkReaderPage(workId: 'story-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LegacyStoryReaderPage), findsOneWidget);
    expect(find.textContaining('village far away'), findsOneWidget);
  });

  testWidgets('the document reader explains itself when there is no PDF', (
    tester,
  ) async {
    final auth = await _auth();
    // No access grant: the callable refused, so the reader must say so rather
    // than spin forever or render an empty page.
    final repository = _FakeFanWorkRepository();
    final reader = FanWorkReaderProvider(repository: repository);
    addTearDown(reader.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<FanWorkReaderProvider>.value(value: reader),
        ],
        child: const MaterialApp(home: FanWorkReaderPage(workId: 'w1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byKey(const Key('fan-work-reader-position')), findsNothing);
  });

  testWidgets('details shows comments and accepts a new comment', (
    tester,
  ) async {
    final auth = await _auth();
    final repository = _FakeFanWorkRepository()
      ..watchWorkResult = Success(_story())
      ..comments.add(
        const FanWorkComment(id: 'c1', authorId: 'bob', text: 'Loved this'),
      );
    final details = FanWorkDetailsProvider(repository: repository);
    addTearDown(details.dispose);
    addTearDown(auth.dispose);
    await details.open(workId: 'story-1', userId: 'alice');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<FanWorkDetailsProvider>.value(value: details),
        ],
        child: const MaterialApp(home: FanWorkDetailsPage(workId: 'story-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Loved this'), findsOneWidget);
    expect(find.byKey(const Key('fan-work-comment-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('fan-work-comment-field')),
      'Thanks',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(repository.addedComments, contains('Thanks'));
    expect(find.text('Thanks'), findsOneWidget);
  });
}

Future<AuthProvider> _auth() async {
  final repository = FakeAuthRepository(
    user: const AuthUser(id: 'alice', email: 'alice@example.com'),
  );
  final auth = AuthProvider(repository: repository);
  await auth.initialize();
  return auth;
}

FanWork _manga() => FanWork(
  id: 'manga-1',
  creatorId: 'alice',
  type: FanWorkType.manga,
  title: 'Pages',
  description: '',
  content: const FanWorkContent(
    pages: <FanWorkPage>[
      FanWorkPage(
        mediaId: 'p1',
        path: 'https://example.test/1.jpg',
        index: 0,
        caption: 'Splash',
      ),
      FanWorkPage(mediaId: 'p2', path: 'https://example.test/2.jpg', index: 1),
    ],
  ),
  status: FanWorkStatus.published,
  moderationStatus: FanWorkModerationStatus.approved,
  visibility: FanWorkVisibility.public,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
);

FanWork _story() => FanWork(
  id: 'story-1',
  creatorId: 'alice',
  type: FanWorkType.story,
  title: 'Tale',
  description: '',
  content: const FanWorkContent(
    body: 'Once upon a time in a village far away.',
  ),
  status: FanWorkStatus.published,
  moderationStatus: FanWorkModerationStatus.approved,
  visibility: FanWorkVisibility.public,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
);

final class _FakeFanWorkRepository implements FanWorkRepository {
  Result<FanWork>? watchWorkResult;
  Completer<Result<void>>? uploadCompleter;
  int uploadAttempts = 0;

  /// Works the reader can load, keyed by id.
  final Map<String, FanWork> works = <String, FanWork>{};
  int documentAccessCalls = 0;
  FanWorkDocumentAccess? documentAccess;
  Failure? documentAccessFailure;
  FanWorkReadingProgress storedProgress = const FanWorkReadingProgress();

  @override
  Future<Result<FanWorkDocumentAccess>> getDocumentAccess({
    required String workId,
  }) async {
    documentAccessCalls += 1;
    final failure = documentAccessFailure;
    if (failure != null) return FailureResult(failure);
    final access = documentAccess;
    if (access == null) {
      return const FailureResult(NotFoundError('no document'));
    }
    return Success(access);
  }

  @override
  Future<Result<FanWorkReadingProgress>> getReadingProgress({
    required String workId,
    required String userId,
  }) async => Success(storedProgress);

  @override
  Future<Result<void>> saveReadingProgress({
    required String workId,
    required FanWorkReadingProgress progress,
  }) async {
    storedProgress = progress;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> markAsRead({required String workId}) async {
    storedProgress = FanWorkReadingProgress(
      page: storedProgress.page,
      pageCount: storedProgress.pageCount,
      progress: 1,
      completed: true,
    );
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> archive(String workId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> bookmark({
    required String workId,
    required bool bookmark,
  }) async => const Success<void>(null);

  int? storedRating;

  @override
  Future<Result<void>> rate({
    required String workId,
    required int rating,
  }) async {
    storedRating = rating;
    return const Success<void>(null);
  }

  @override
  Future<Result<int?>> myRating({
    required String workId,
    required String userId,
  }) async => Success(storedRating);

  @override
  Future<Result<void>> cancelMediaUpload() async {
    final pending = uploadCompleter;
    uploadCompleter = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete(const FailureResult(CancelledError()));
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> confirmMedia({
    required String workId,
    required String mediaId,
    required String path,
    required FanWorkMediaRole role,
    String caption = '',
    String characterId = '',
    int? pageCount,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> deleteDraft(String workId) async =>
      const Success<void>(null);

  @override
  Future<Result<FanWorkListPage>> getCreatorWorks({
    required String creatorId,
    FanWork? after,
    int limit = 20,
  }) async =>
      const Success(FanWorkListPage(items: <FanWork>[], hasMore: false));

  @override
  Future<Result<List<FanWork>>> getMyDrafts({required String userId}) async =>
      const Success(<FanWork>[]);

  @override
  Future<Result<FanWorkListPage>> getPublicFeed({
    FanWorkType? type,
    String? animeId,
    FanWork? after,
    int limit = 20,
  }) async =>
      const Success(FanWorkListPage(items: <FanWork>[], hasMore: false));

  @override
  @override
  Future<Result<FanWork>> getWork(String workId) async {
    final published = works[workId];
    if (published != null) return Success(published);
    return watchWorkResult ?? const FailureResult(NotFoundError('missing'));
  }

  @override
  Future<Result<bool>> hasBookmarked({
    required String workId,
    required String userId,
  }) async => const Success(false);

  @override
  Future<Result<bool>> hasLiked({
    required String workId,
    required String userId,
  }) async => const Success(false);

  @override
  Future<Result<void>> like({
    required String workId,
    required bool like,
  }) async => const Success<void>(null);

  @override
  Future<Result<FanWork>> publish(String workId) async =>
      const FailureResult(NotFoundError('unused'));

  @override
  Future<Result<void>> report({
    required String workId,
    required FanWorkReportReason reason,
    String details = '',
  }) async => const Success<void>(null);

  final List<FanWorkComment> comments = <FanWorkComment>[];
  final List<String> addedComments = <String>[];

  @override
  Future<Result<void>> addComment({
    required String workId,
    required String text,
    String? replyToCommentId,
    String? eventId,
  }) async {
    comments.add(
      FanWorkComment(
        id: eventId ?? 'c-${comments.length + 1}',
        authorId: 'alice',
        text: text,
        replyToCommentId: replyToCommentId,
      ),
    );
    addedComments.add(text);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<FanWorkComment>>> getComments(
    String workId, {
    FanWorkComment? after,
    int limit = 30,
  }) async {
    if (after != null) return const Success(<FanWorkComment>[]);
    return Success(List<FanWorkComment>.from(comments));
  }

  @override
  Future<Result<void>> commentAction({
    required String workId,
    required String commentId,
    required String action,
  }) async {
    if (action == 'delete') {
      comments.removeWhere((comment) => comment.id == commentId);
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> revisePublished({
    required String workId,
    String? title,
    String? description,
    FanWorkCopyright? copyright,
    List<String>? tags,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> requestRemoval({
    required String workId,
    String details = '',
  }) async => const Success<void>(null);

  @override
  Future<Result<String>> saveDraft(FanWorkDraft draft) async =>
      const Success('draft-1');

  @override
  Future<Result<List<FanWorkPreview>>> search(String query) async =>
      const Success(<FanWorkPreview>[]);

  @override
  Future<Result<FanWorkUploadTicket>> startMediaUpload({
    required String workId,
    required FanWorkMediaRole role,
    required String contentType,
    String characterId = '',
  }) async => Success(
    FanWorkUploadTicket(
      workId: workId,
      mediaId: 'm1',
      path:
          'fan_works/alice/$workId/m1'
          '${role == FanWorkMediaRole.document ? '.pdf' : '.jpg'}',
      contentType: contentType,
      role: role,
      uploadUrl: 'https://storage.test/upload/session/1',
      maxBytes: role == FanWorkMediaRole.document
          ? FanWorkLifecycle.maxDocumentBytes
          : FanWorkLifecycle.maxImageBytes,
      expiresAt: DateTime.utc(2026, 9, 1, 12, 15),
    ),
  );

  @override
  Future<Result<void>> uploadMediaBytes({
    required FanWorkUploadTicket ticket,
    required List<int> bytes,
    required String contentType,
    FanWorkUploadProgress? onProgress,
  }) async {
    uploadAttempts += 1;
    onProgress?.call(0.35);
    final pending = uploadCompleter;
    if (pending != null) return pending.future;
    onProgress?.call(1);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<FanWorkRevision>>> getRevisions(String workId) async =>
      const Success(<FanWorkRevision>[]);

  @override
  Future<Result<FanWorkAnalytics>> getAnalytics(String creatorId) async =>
      Success(
        FanWorkAnalytics(
          totalWorks: 0,
          publishedWorks: 0,
          draftWorks: 0,
          totalLikes: 0,
          totalBookmarks: 0,
          totalComments: 0,
          totalRatings: 0,
          averageRating: 0.0,
          worksByType: const <String, int>{},
          topWorks: const <FanWorkPreview>[],
        ),
      );

  @override
  Stream<Result<FanWork>> watchWork(String workId) =>
      Stream<Result<FanWork>>.value(
        watchWorkResult ??
            const FailureResult(NotFoundError('This Fan Work is unavailable.')),
      );
}
