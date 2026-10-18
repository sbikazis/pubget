import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_route.dart';
import 'package:pubget/app/app_router.dart';
import 'package:pubget/core/links/pubget_links.dart';
import 'package:pubget/features/reels/screens/reel_details_page.dart';

void main() {
  test('PubgetLinks builds canonical entity paths', () {
    expect(PubgetLinks.reelPath('abc'), '/reel/abc');
    expect(PubgetLinks.reelPath(''), '/reels');
    expect(PubgetLinks.reelPath('e 1'), '/reel/e%201');
    expect(PubgetLinks.reel('abc'), 'https://pubget-aaf27.web.app/reel/abc');

    expect(PubgetLinks.audioPath('a1'), '/audio/a1');
    expect(PubgetLinks.audio('a1'), 'https://pubget-aaf27.web.app/audio/a1');

    expect(PubgetLinks.hashtagPath('OnePiece'), '/hashtag/onepiece');
    expect(PubgetLinks.hashtagPath('#OnePiece'), '/hashtag/onepiece');
    expect(PubgetLinks.hashtagPath('one piece'), '/hashtag/one%20piece');
    expect(
      PubgetLinks.hashtag('OnePiece'),
      'https://pubget-aaf27.web.app/hashtag/onepiece',
    );
  });

  test('legacy highlight links resolve to the reel entity route', () {
    final edits =
        AppRouter.routeFromString('/edits?highlight=abc') as ParameterizedRoute;
    expect(edits.path, '/reel');
    expect(edits.parameters['reelId'], 'abc');
    expect(PubgetLinks.reelPath(edits.parameters['reelId']!), '/reel/abc');

    final reels =
        AppRouter.routeFromString('/reels?highlight=abc') as ParameterizedRoute;
    expect(reels.path, '/reel');
    expect(reels.parameters['reelId'], 'abc');
  });

  testWidgets('ReelDetailsPage renders the reel id and resolved route', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ReelDetailsPage(reelId: 'abc123')),
    );

    expect(find.text('Reel'), findsOneWidget);
    expect(find.text('abc123'), findsOneWidget);
    expect(find.text('/reel/abc123'), findsOneWidget);
  });

  testWidgets('AppNavigation.go("/reel/abc") opens ReelDetailsPage', (
    tester,
  ) async {
    final rootContext = await _pumpRoutingApp(tester);

    await AppNavigation.go(rootContext, '/reel/abc');
    await tester.pumpAndSettle();

    expect(find.byType(ReelDetailsPage), findsOneWidget);
    expect(find.text('abc'), findsOneWidget);
  });

  testWidgets('legacy /edits?highlight=abc opens the same ReelDetailsPage', (
    tester,
  ) async {
    final rootContext = await _pumpRoutingApp(tester);

    await AppNavigation.go(rootContext, '/edits?highlight=abc');
    await tester.pumpAndSettle();

    expect(find.byType(ReelDetailsPage), findsOneWidget);
    expect(find.text('abc'), findsOneWidget);
  });
}

Future<BuildContext> _pumpRoutingApp(WidgetTester tester) async {
  late BuildContext rootContext;
  final delegate = AppRouterDelegate(
    homePage: Builder(
      builder: (context) {
        rootContext = context;
        return const SizedBox.shrink();
      },
    ),
    parameterizedPages: <String, ParameterizedPageBuilder>{
      '/reel': (parameters) =>
          ReelDetailsPage(reelId: parameters['reelId'] ?? ''),
    },
    initialRoute: const FoundationRoute(),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Router<AppRoute>(
        routerDelegate: delegate,
        routeInformationParser: AppRouteInformationParser(),
      ),
    ),
  );
  return rootContext;
}
