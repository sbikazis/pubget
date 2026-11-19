import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/kirari/data/kirari_repository.dart';
import 'package:pubget/features/kirari/screens/kirari_feed_page.dart';

class _FakeCommentsRepository extends Fake implements KirariRepository {
  _FakeCommentsRepository(this.firstPage, {this.nextPage = const []});

  final List<Map<String, dynamic>> firstPage;
  final List<Map<String, dynamic>> nextPage;
  final List<String> actions = <String>[];
  int calls = 0;

  @override
  Future<List<Map<String, dynamic>>> getComments(
    String reelId, {
    String? before,
    int limit = 30,
  }) async {
    calls++;
    return before == null ? firstPage : nextPage;
  }

  @override
  Future<void> commentAction(
    String reelId,
    String commentId,
    String kind,
  ) async {
    actions.add('$kind:$commentId');
  }
}

KirariReel _reel() => const KirariReel(
  id: 'reel-1',
  creatorId: 'creator',
  caption: 'caption',
  videoUrl: '',
  coverUrl: '',
  durationSeconds: 10,
  likesCount: 0,
  commentsCount: 2,
);

Map<String, dynamic> _comment(String id, {bool pinned = false}) =>
    <String, dynamic>{
      'id': id,
      'text': 'text-$id',
      'authorId': 'viewer',
      'status': 'published',
      'pinned': pinned,
      'likesCount': 0,
    };

Future<void> _pump(
  WidgetTester tester,
  _FakeCommentsRepository repository, {
  String currentUserId = 'viewer',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: KirariCommentsSheet(
          reel: _reel(),
          repository: repository,
          currentUserId: currentUserId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('creator sees the pinned badge and can unpin', (tester) async {
    final repository = _FakeCommentsRepository([
      _comment('c1', pinned: true),
      _comment('c2'),
    ]);

    await _pump(tester, repository, currentUserId: 'creator');

    expect(find.text('Pinned'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Unpin comment'), findsOneWidget);
    expect(find.text('Pin comment'), findsNothing);

    await tester.tap(find.text('Unpin comment'));
    await tester.pumpAndSettle();
    expect(repository.actions, contains('unpin:c1'));
  });

  testWidgets('a viewer cannot pin or unpin someone else\'s comment', (
    tester,
  ) async {
    final repository = _FakeCommentsRepository([_comment('c1', pinned: true)]);

    await _pump(tester, repository);

    expect(find.text('Pinned'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Pin comment'), findsNothing);
    expect(find.text('Unpin comment'), findsNothing);
    expect(find.text('Report comment'), findsOneWidget);
  });

  testWidgets('loading another page does not duplicate a comment', (
    tester,
  ) async {
    // The load-more row sits after 30 tiles; give the sheet enough height for
    // the lazy ListView to build it without manual scrolling.
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final firstPage = List<Map<String, dynamic>>.generate(
      30,
      (index) => _comment('c$index'),
    );
    final repository = _FakeCommentsRepository(
      firstPage,
      nextPage: [_comment('c0')],
    );

    await _pump(tester, repository);
    expect(find.text('Load more comments'), findsOneWidget);

    await tester.tap(find.text('Load more comments'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('text-c0'), findsOneWidget);
  });
}
