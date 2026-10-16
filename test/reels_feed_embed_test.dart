import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/edits/models/edit_models.dart';
import 'package:pubget/features/edits/providers/edit_upload_manager.dart';
import 'package:pubget/features/edits/providers/edits_provider.dart';
import 'package:pubget/features/edits/repositories/edits_repository.dart';
import 'package:pubget/features/edits/screens/edit_feed_page.dart';
import 'package:pubget/features/reels/screens/reels_feed_page.dart';
import 'package:pubget/features/social/providers/social_provider.dart';

import 'authentication_test_support.dart';
import 'edits_test_support.dart';
import 'social_test_support.dart';

/// Regression cover for Axis 15 §15.8.
///
/// The audio detail page hosts the reel feed inside its own Scaffold. Before the
/// `embedded` flag existed the feed rendered a Scaffold and AppBar of its own,
/// so the page shipped a Scaffold nested inside a Scaffold with a duplicated
/// toolbar. These tests pin the contract in both directions, and they give the
/// primary viewer screen its first widget test at all.
List<SingleChildWidget> _deps(EditsRepository repository) => [
  Provider<EditsRepository>.value(value: repository),
  ChangeNotifierProvider<NetworkService>(create: (_) => NetworkService()),
  ChangeNotifierProvider<AuthProvider>(
    create: (_) => AuthProvider(repository: FakeAuthRepository()),
  ),
  ChangeNotifierProvider<SocialProvider>(
    create: (_) => SocialProvider(repository: FakeSocialRepository()),
  ),
  ChangeNotifierProvider<EditsProvider>(
    create: (_) => EditsProvider(repository: repository),
  ),
  ChangeNotifierProvider<EditUploadManager>(
    create: (_) => EditUploadManager(repository: repository),
  ),
];

/// Feed rows with empty media paths. `AppImageLoader` short-circuits on an
/// empty url and never reaches Firebase, which is uninitialised in unit tests.
/// These tests are about chrome, not media.
EditsRepository _repo() {
  final base = testEdit();
  return FakeEditsRepository(
    feed: [
      Edit(
        id: base.id,
        creatorId: base.creatorId,
        videoUrl: '',
        thumbnailUrl: '',
        caption: base.caption,
        animeTag: base.animeTag,
        likesCount: base.likesCount,
        commentsCount: base.commentsCount,
        viewsCount: base.viewsCount,
        score: base.score,
        createdAt: base.createdAt,
        publishedAt: base.publishedAt,
        status: base.status,
      ),
    ],
    comments: const [],
  );
}

/// A screen that owns its own chrome and hosts the feed inside it.
Widget _hostApp(Widget feed) {
  return MultiProvider(
    providers: _deps(_repo()),
    child: MaterialApp(home: Scaffold(body: feed)),
  );
}

/// The feed as its own top-level route.
Widget _routeApp(Widget feed) {
  return MultiProvider(
    providers: _deps(_repo()),
    child: MaterialApp(home: feed),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('standalone feed owns one Scaffold and its own AppBar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _routeApp(
        // Explicit leading: the default AppShellMenuButton needs a Router that
        // a bare MaterialApp does not provide. Not what this test is about.
        const EditFeedPage(leading: SizedBox.shrink()),
      ),
    );
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('embedded feed adds no Scaffold or AppBar inside a host', (
    tester,
  ) async {
    await tester.pumpWidget(
      _hostApp(const EditFeedPage(embedded: true)),
    );
    await tester.pump();

    // Only the host Scaffold exists.
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('unscoped ReelsFeedPage forwards the embedded flag', (
    tester,
  ) async {
    await tester.pumpWidget(_hostApp(const ReelsFeedPage(embedded: true)));
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('scoped embedded feed adds no Scaffold either', (tester) async {
    await tester.pumpWidget(
      _hostApp(const ReelsFeedPage(audioId: 'a1', embedded: true)),
    );
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('scoped standalone feed keeps its own chrome', (tester) async {
    await tester.pumpWidget(
      _routeApp(const ReelsFeedPage(audioId: 'a1', title: '#one_piece')),
    );
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('the feed renders inside an embedded host without overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(_hostApp(const ReelsFeedPage(embedded: true)));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
