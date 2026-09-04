import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/fan_works/models/fan_work_models.dart';
import 'package:pubget/features/fan_works/providers/fan_work_providers.dart';
import 'package:pubget/features/fan_works/repositories/fan_work_repository.dart';
import 'package:pubget/features/fan_works/repositories/memory_fan_work_draft_store.dart';

void main() {
  test('feed pagination appends, skips duplicates, and retries a failed page', () async {
    final repository = _FakeFanWorkRepository()
      ..pages = <FanWorkListPage>[
        FanWorkListPage(items: <FanWork>[_work('a'), _work('b')], hasMore: true),
        FanWorkListPage(items: <FanWork>[_work('b'), _work('c')], hasMore: false),
      ];
    final feed = FanWorkFeedProvider(repository: repository);
    addTearDown(feed.dispose);

    await feed.load();
    expect(feed.items.map((work) => work.id), <String>['a', 'b']);
    expect(feed.hasMore, isTrue);

    await feed.loadMore();
    expect(feed.items.map((work) => work.id), <String>['a', 'b', 'c']);
    expect(feed.hasMore, isFalse);

    repository.feedFailure = const NetworkError('offline');
    repository.pages = <FanWorkListPage>[
      FanWorkListPage(items: const <FanWork>[], hasMore: false),
    ];
    await feed.load();
    expect(feed.offlineCached, isTrue);
    expect(feed.items, isNotEmpty);
  });

  test('empty page marks the end of the feed', () async {
    final repository = _FakeFanWorkRepository()
      ..pages = <FanWorkListPage>[
        FanWorkListPage(items: <FanWork>[_work('a')], hasMore: true),
        const FanWorkListPage(items: <FanWork>[], hasMore: true),
      ];
    final feed = FanWorkFeedProvider(repository: repository);
    addTearDown(feed.dispose);
    await feed.load();
    await feed.loadMore();
    expect(feed.hasMore, isFalse);
    expect(feed.items, hasLength(1));
  });

  test('failed next page keeps existing items and can retry', () async {
    final repository = _FakeFanWorkRepository()
      ..pages = <FanWorkListPage>[
        FanWorkListPage(items: <FanWork>[_work('a')], hasMore: true),
      ]
      ..nextFailure = const NetworkError('timeout');
    final feed = FanWorkFeedProvider(repository: repository);
    addTearDown(feed.dispose);
    await feed.load();
    await feed.loadMore();
    expect(feed.items, hasLength(1));
    expect(feed.failure, isA<NetworkError>());
    repository.nextFailure = null;
    repository.pages.add(
      FanWorkListPage(items: <FanWork>[_work('b')], hasMore: false),
    );
    await feed.retryNextPage();
    expect(feed.items.map((work) => work.id), <String>['a', 'b']);
  });

  test('draft survives a failed save and failed publish', () async {
    final store = MemoryFanWorkDraftStore();
    final repository = _FakeFanWorkRepository()
      ..saveFailure = const NetworkError('offline');
    final editor = FanWorkEditorProvider(
      repository: repository,
      draftStore: store,
    );
    addTearDown(editor.dispose);

    await editor.start();
    editor.selectType(FanWorkType.story);
    editor.updateDraft(
      editor.draft.copyWith(
        title: 'Kept locally',
        body: 'Once upon a time in a village far away.',
      ),
    );
    final saved = await editor.saveDraft();
    expect(saved.isSuccess, isFalse);
    expect(editor.draftSavedLocally, isTrue);
    expect(await store.read('new'), isNotNull);

    repository.saveFailure = null;
    repository.publishFailure = const NetworkError('offline');
    final published = await editor.publish();
    expect(published.isSuccess, isFalse);
    expect(editor.draft.title, 'Kept locally');
    expect(editor.draftSavedLocally, isTrue);
  });

  test('details reports loading, missing, and offline states', () async {
    final repository = _FakeFanWorkRepository();
    final details = FanWorkDetailsProvider(repository: repository);
    addTearDown(details.dispose);

    await details.open(workId: 'missing', userId: 'alice');
    await Future<void>.delayed(Duration.zero);
    expect(details.state, LoadingState.empty);

    repository.watchWorkResult = FailureResult(
      const NetworkError('offline'),
    );
    await details.open(workId: 'w1', userId: 'alice');
    await Future<void>.delayed(Duration.zero);
    expect(details.state, LoadingState.offline);
  });

  test('details loads comments and posts a new one', () async {
    final repository = _FakeFanWorkRepository()
      ..watchWorkResult = Success(_work('w1'))
      ..comments.add(
        const FanWorkComment(id: 'c1', authorId: 'bob', text: 'Loved this'),
      );
    final details = FanWorkDetailsProvider(repository: repository);
    addTearDown(details.dispose);

    await details.open(workId: 'w1', userId: 'alice');
    expect(details.comments.map((comment) => comment.text), <String>['Loved this']);

    await details.addComment(workId: 'w1', text: 'Thanks @bob');
    expect(repository.addedComments, contains('Thanks @bob'));
    expect(
      details.comments.any((comment) => comment.text == 'Thanks @bob'),
      isTrue,
    );

    await details.commentAction(
      workId: 'w1',
      commentId: 'c1',
      action: 'delete',
    );
    expect(details.comments.any((comment) => comment.id == 'c1'), isFalse);
  });

  test('details rating is stored through the repository', () async {
    final repository = _FakeFanWorkRepository()
      ..watchWorkResult = Success(_work('w1'));
    final details = FanWorkDetailsProvider(repository: repository);
    addTearDown(details.dispose);
    await details.open(workId: 'w1', userId: 'alice');
    await details.rate(workId: 'w1', rating: 8);
    expect(details.myRating, 8);
    expect(repository.storedRating, 8);
  });
}

FanWork _work(String id) => FanWork(
  id: id,
  creatorId: 'alice',
  type: FanWorkType.drawing,
  title: 'Work $id',
  description: 'A drawing',
  content: const FanWorkContent(
    images: <FanWorkMedia>[
      FanWorkMedia(mediaId: 'i1', path: 'fan_works/alice/w/i1.jpg'),
    ],
  ),
  status: FanWorkStatus.published,
  moderationStatus: FanWorkModerationStatus.approved,
  visibility: FanWorkVisibility.public,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
  publishedAt: DateTime.utc(2026, 9, 1, 12),
);

final class _FakeFanWorkRepository implements FanWorkRepository {
  List<FanWorkListPage> pages = const <FanWorkListPage>[];
  int _pageIndex = 0;
  Failure? feedFailure;
  Failure? nextFailure;
  Failure? saveFailure;
  Failure? publishFailure;
  Result<FanWork>? watchWorkResult;
  final Map<String, FanWorkDraft> drafts = <String, FanWorkDraft>{};

  @override
  Future<Result<void>> archive(String workId) async => const Success<void>(null);

  @override
  Future<Result<void>> bookmark({
    required String workId,
    required bool bookmark,
  }) async => const Success<void>(null);

  int? storedRating;

  @override
  Future<Result<void>> rate({required String workId, required int rating}) async {
    storedRating = rating;
    return const Success<void>(null);
  }

  @override
  Future<Result<int?>> myRating({
    required String workId,
    required String userId,
  }) async => Success(storedRating);

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
  }) async {
    if (after == null) {
      _pageIndex = 0;
      if (feedFailure != null) return FailureResult(feedFailure!);
    } else if (nextFailure != null) {
      return FailureResult(nextFailure!);
    }
    if (_pageIndex >= pages.length) {
      return const Success(
        FanWorkListPage(items: <FanWork>[], hasMore: false),
      );
    }
    return Success(pages[_pageIndex++]);
  }

  @override
  Future<Result<FanWork>> getWork(String workId) async {
    final draft = drafts[workId];
    if (draft == null) {
      return const FailureResult(NotFoundError('missing'));
    }
    return Success(
      FanWork(
        id: workId,
        creatorId: 'alice',
        type: draft.type,
        title: draft.title,
        description: draft.description,
        content: FanWorkContent(body: draft.body, name: draft.name),
        status: FanWorkStatus.draft,
        moderationStatus: FanWorkModerationStatus.pending,
        visibility: FanWorkVisibility.unpublished,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
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
  Future<Result<FanWork>> publish(String workId) async {
    if (publishFailure != null) return FailureResult(publishFailure!);
    return Success(_work(workId));
  }

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
  Future<Result<String>> saveDraft(FanWorkDraft draft) async {
    if (saveFailure != null) return FailureResult(saveFailure!);
    final id = draft.workId ?? 'draft-1';
    drafts[id] = draft.copyWith(workId: id);
    return Success(id);
  }

  @override
  Future<Result<List<FanWorkPreview>>> search(String query) async =>
      const Success(<FanWorkPreview>[]);

  @override
  Future<Result<FanWorkUploadTicket>> startMediaUpload({
    required String workId,
    required String contentType,
  }) async => Success(
    FanWorkUploadTicket(
      workId: workId,
      mediaId: 'm1',
      path: 'fan_works/alice/$workId/m1.jpg',
      contentType: contentType,
    ),
  );

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
