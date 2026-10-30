import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/app/app_router.dart';
import 'package:pubget/app/entity_routes.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/links/pubget_links.dart';
import 'package:pubget/features/audio/screens/audio_page.dart';
import 'package:pubget/features/edits/models/edit_models.dart';
import 'package:pubget/features/edits/repositories/edits_repository.dart';
import 'package:pubget/features/hashtags/screens/hashtag_page.dart';
import 'package:pubget/features/reels/screens/reel_details_page.dart';

import 'edits_test_support.dart';

Future<void> pumpRoute(
  WidgetTester tester,
  EditsRepository repository,
  String path,
) async {
  tester.binding.platformDispatcher.defaultRouteNameTestValue = path;
  addTearDown(
    tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
  );
  // A phone-shaped surface: the Reel video is 9:16, so the metadata column below
  // it only gets built when the viewport is tall enough.
  tester.view.physicalSize = const Size(500, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final delegate = AppRouterDelegate(
    homePage: const Text('Home'),
    parameterizedPages: EntityRoutes.pages(),
    initialRoute: AppRouter.routeFromString(path),
  );
  await tester.pumpWidget(
    Provider<EditsRepository>.value(
      value: repository,
      child: MaterialApp.router(
        routerDelegate: delegate,
        routeInformationParser: AppRouteInformationParser(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('reel details renders stored metadata and counters', (
    tester,
  ) async {
    final repository = FakeEditsRepository(
      feed: <Edit>[
        testEdit(
          id: 'r1',
          videoUrl: '',
          hashtags: const <String>['anime', 'editing'],
          mentions: const <String>['bob'],
          characterIds: const <String>['c1', 'c2'],
          audioId: 'a1',
          allowRemix: false,
          likes: 7,
          views: 42,
        ),
      ],
    );

    await pumpRoute(tester, repository, '/reel/r1');

    expect(find.byType(ReelDetailsPage), findsOneWidget);
    expect(find.text('Gear five port'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('reel-hashtag-anime')),
      findsOneWidget,
    );
    expect(find.text('Anime · one_piece'), findsOneWidget);
    expect(find.text('@bob'), findsOneWidget);
    expect(find.text('2 characters'), findsOneWidget);
    expect(find.text('Remix disabled'), findsOneWidget);
    expect(find.byKey(const Key('reel-audio-attribution')), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('reel details exposes remix enabled when the flag allows it', (
    tester,
  ) async {
    final repository = FakeEditsRepository(
      feed: <Edit>[testEdit(id: 'r2', videoUrl: '', allowRemix: true)],
    );

    await pumpRoute(tester, repository, '/reel/r2');

    expect(find.text('Remix enabled'), findsOneWidget);
    expect(find.text('Remix disabled'), findsNothing);
  });

  testWidgets('reel details hides metadata it does not have', (tester) async {
    final repository = FakeEditsRepository(
      feed: <Edit>[testEdit(id: 'r5', videoUrl: '')],
    );

    await pumpRoute(tester, repository, '/reel/r5');

    expect(find.byKey(const Key('reel-audio-attribution')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('reel-hashtag-anime')),
      findsNothing,
    );
  });

  testWidgets('tap hashtag chip opens the hashtag surface', (tester) async {
    final repository = FakeEditsRepository(
      feed: <Edit>[
        testEdit(id: 'r3', videoUrl: '', hashtags: const ['anime']),
      ],
    );

    await pumpRoute(tester, repository, '/reel/r3');
    await tester.tap(find.byKey(const ValueKey<String>('reel-hashtag-anime')));
    await tester.pumpAndSettle();

    expect(find.byType(HashtagPage), findsOneWidget);
    expect(find.text('Used in 1 Reel'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('reel-tile-r3')), findsOneWidget);
  });

  testWidgets('tap audio attribution opens the audio surface', (tester) async {
    final repository = FakeEditsRepository(
      feed: <Edit>[testEdit(id: 'r4', videoUrl: '', audioId: 'a9')],
    );

    await pumpRoute(tester, repository, '/reel/r4');
    await tester.tap(find.byKey(const Key('reel-audio-attribution')));
    await tester.pumpAndSettle();

    expect(find.byType(AudioPage), findsOneWidget);
    expect(find.text('Original Audio'), findsOneWidget);
    expect(find.text('Used in 1 Reel'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('reel-tile-r4')), findsOneWidget);
  });

  testWidgets('hashtag surface lists only tagged reels', (tester) async {
    final repository = FakeEditsRepository(
      feed: <Edit>[
        testEdit(id: 'h1', videoUrl: '', hashtags: const ['anime']),
        testEdit(id: 'h2', videoUrl: '', hashtags: const ['anime']),
        testEdit(id: 'h3', videoUrl: '', hashtags: const ['other']),
      ],
    );

    await pumpRoute(tester, repository, '/hashtag/anime');

    expect(find.byType(HashtagPage), findsOneWidget);
    expect(find.text('Used in 2 Reels'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('reel-tile-h1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('reel-tile-h2')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('reel-tile-h3')), findsNothing);
  });

  testWidgets('audio surface with no reels shows the empty state', (
    tester,
  ) async {
    await pumpRoute(tester, FakeEditsRepository(feed: <Edit>[]), '/audio/a0');

    expect(find.text('No Reels use this audio yet'), findsOneWidget);
  });

  testWidgets('reel share uses the canonical /reel/:id link', (tester) async {
    String? shared;
    PubgetLinks.debugNativeShare = (text, subject) async {
      shared = text;
    };
    addTearDown(() => PubgetLinks.debugNativeShare = null);

    final repository = FakeEditsRepository(
      feed: <Edit>[testEdit(id: 'r7', videoUrl: '')],
    );

    await pumpRoute(tester, repository, '/reel/r7');
    await tester.tap(find.byKey(const Key('reel-share')));
    await tester.pumpAndSettle();

    expect(shared, 'https://pubget-aaf27.web.app/reel/r7');
  });

  testWidgets('missing reel shows the unavailable state', (tester) async {
    final repository = FakeEditsRepository()
      ..getEditFailure = const NotFoundError('Reel not found.');

    await pumpRoute(tester, repository, '/reel/nope');

    expect(find.text('This Reel is not available'), findsOneWidget);
  });
}
