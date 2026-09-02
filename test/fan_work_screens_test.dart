import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text(FanWorkTypeCatalog.label(FanWorkType.manga)), findsOneWidget);
    expect(find.text(FanWorkTypeCatalog.label(FanWorkType.aiCharacter)), findsOneWidget);
    await tester.tap(find.text(FanWorkTypeCatalog.label(FanWorkType.character)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fan-work-character-name')), findsOneWidget);
  });

  testWidgets('manga viewer keeps page order and an indicator', (tester) async {
    final auth = await _auth();
    final repository = _FakeFanWorkRepository()
      ..watchWorkResult = Success(_manga());
    final details = FanWorkDetailsProvider(repository: repository);
    addTearDown(details.dispose);
    addTearDown(auth.dispose);
    await details.open(workId: 'manga-1', userId: 'alice');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<FanWorkDetailsProvider>.value(value: details),
        ],
        child: const MaterialApp(home: MangaViewerPage(workId: 'manga-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Splash'), findsOneWidget);
  });

  testWidgets('story reader shows body text', (tester) async {
    final auth = await _auth();
    final repository = _FakeFanWorkRepository()
      ..watchWorkResult = Success(_story());
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
        child: const MaterialApp(home: StoryReaderPage(workId: 'story-1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('village far away'), findsOneWidget);
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
      FanWorkPage(
        mediaId: 'p2',
        path: 'https://example.test/2.jpg',
        index: 1,
      ),
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

  @override
  Future<Result<void>> archive(String workId) async => const Success<void>(null);

  @override
  Future<Result<void>> bookmark({
    required String workId,
    required bool bookmark,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> confirmMedia({
    required String workId,
    required String mediaId,
    required String path,
    required FanWorkMediaRole role,
    String caption = '',
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> deleteDraft(String workId) async =>
      const Success<void>(null);

  @override
  Future<Result<FanWorkListPage>> getCreatorWorks({
    required String creatorId,
    FanWork? after,
    int limit = 20,
  }) async => const Success(FanWorkListPage(items: <FanWork>[], hasMore: false));

  @override
  Future<Result<List<FanWork>>> getMyDrafts({required String userId}) async =>
      const Success(<FanWork>[]);

  @override
  Future<Result<FanWorkListPage>> getPublicFeed({
    FanWorkType? type,
    String? animeId,
    FanWork? after,
    int limit = 20,
  }) async => const Success(FanWorkListPage(items: <FanWork>[], hasMore: false));

  @override
  Future<Result<FanWork>> getWork(String workId) async =>
      watchWorkResult ?? const FailureResult(NotFoundError('missing'));

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

  @override
  Future<Result<String>> saveDraft(FanWorkDraft draft) async =>
      const Success('draft-1');

  @override
  Future<Result<List<FanWorkPreview>>> search(String query) async =>
      const Success(<FanWorkPreview>[]);

  @override
  Future<Result<FanWorkUploadTicket>> startMediaUpload({
    required String workId,
    required String contentType,
  }) async => const FailureResult(UnknownError('unused'));

  @override
  Future<Result<void>> uploadMediaBytes({
    required FanWorkUploadTicket ticket,
    required List<int> bytes,
    required String contentType,
  }) async => const Success<void>(null);

  @override
  Stream<Result<FanWork>> watchWork(String workId) =>
      Stream<Result<FanWork>>.value(
        watchWorkResult ??
            const FailureResult(NotFoundError('This Fan Work is unavailable.')),
      );
}
