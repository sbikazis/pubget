import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_route.dart';
import 'package:pubget/app/app_router.dart';
import 'package:pubget/app/entity_routes.dart';
import 'package:pubget/core/links/pubget_deep_link.dart';
import 'package:pubget/core/links/pubget_links.dart';
import 'package:pubget/features/audio/screens/audio_page.dart';
import 'package:pubget/features/hashtags/screens/hashtag_page.dart';
import 'package:pubget/features/reels/screens/reel_details_page.dart';

void main() {
  group('canonical entity links', () {
    test('reel helpers emit /reel/:id', () {
      expect(PubgetLinks.reelPath('abc'), '/reel/abc');
      expect(PubgetLinks.reel('abc'), 'https://pubget-aaf27.web.app/reel/abc');
    });

    test('audio helpers encode the id', () {
      expect(PubgetLinks.audioPath('a1'), '/audio/a1');
      expect(PubgetLinks.audioPath('a 1'), '/audio/a%201');
      expect(PubgetLinks.audio('a1'), 'https://pubget-aaf27.web.app/audio/a1');
    });

    test('hashtag helpers normalise the leading hash', () {
      expect(PubgetLinks.hashtagPath('anime'), '/hashtag/anime');
      expect(PubgetLinks.hashtagPath('#anime'), '/hashtag/anime');
      expect(
        PubgetLinks.hashtag('#anime'),
        'https://pubget-aaf27.web.app/hashtag/anime',
      );
    });

    test('blank ids stay unshareable', () {
      expect(PubgetLinks.reelPath('  '), isEmpty);
      expect(PubgetLinks.reel(''), isEmpty);
      expect(PubgetLinks.audioPath(''), isEmpty);
      expect(PubgetLinks.hashtagPath('#'), isEmpty);
    });

    test('legacy highlight generators are unchanged', () {
      expect(PubgetLinks.editHighlightPath('abc'), '/edits?highlight=abc');
      expect(PubgetLinks.reelHighlightPath('abc'), '/reels?highlight=abc');
    });
  });

  group('router entity parsing', () {
    ParameterizedRoute parse(String raw) =>
        AppRouter.routeFromString(raw) as ParameterizedRoute;

    test('/reel/:id parses and keeps extra query parameters', () {
      final route = parse('/reel/abc?ref=share');
      expect(route.path, '/reel');
      expect(route.parameters['reelId'], 'abc');
      expect(route.parameters['ref'], 'share');
    });

    test('/audio/:id and /hashtag/:tag parse', () {
      final audio = parse('/audio/a1');
      expect(audio.path, '/audio');
      expect(audio.parameters['audioId'], 'a1');

      final hashtag = parse('/hashtag/anime');
      expect(hashtag.path, '/hashtag');
      expect(hashtag.parameters['tag'], 'anime');
    });

    test('legacy feed-highlight links resolve to the entity route', () {
      for (final raw in <String>[
        '/edits?highlight=abc',
        '/reels?highlight=abc',
      ]) {
        final route = parse(raw);
        expect(route.path, '/reel', reason: raw);
        expect(route.parameters['reelId'], 'abc', reason: raw);
        expect(route.parameters.containsKey('highlight'), isFalse, reason: raw);
      }
    });

    test('legacy feeds without a highlight still open the feed', () {
      expect(parse('/edits').path, '/edits');
      expect(parse('/reels').path, '/reels');
      expect(parse('/edits?highlight=').path, '/edits');
    });

    test('missing entity ids fall back to /unknown', () {
      expect(parse('/reel/').path, '/unknown');
      expect(parse('/audio/').path, '/unknown');
      expect(parse('/hashtag/').path, '/unknown');
    });

    test('encoded ids decode once and Arabic tags survive', () {
      expect(parse('/reel/abc%201').parameters['reelId'], 'abc 1');
      expect(
        parse('/hashtag/${Uri.encodeComponent('أنمي')}').parameters['tag'],
        'أنمي',
      );
    });
  });

  group('deep link resolution', () {
    test('canonical reel links pass through unchanged', () {
      final target = PubgetDeepLink.parse('/reel/abc')!;
      expect(target.path, '/reel/abc');
      expect(target.legacyHighlightId, isNull);
      expect(target.isLegacy, isFalse);
    });

    test('legacy highlight links rewrite to /reel/:id', () {
      for (final raw in <String>[
        '/edits?highlight=abc',
        '/reels?highlight=abc',
      ]) {
        final target = PubgetDeepLink.parse(raw)!;
        expect(target.path, '/reel/abc', reason: raw);
        expect(target.legacyHighlightId, 'abc', reason: raw);
        expect(target.isLegacy, isTrue, reason: raw);
      }
    });

    test('absolute links and unrelated destinations are preserved', () {
      expect(
        PubgetDeepLink.parse('https://pubget-aaf27.web.app/reel/abc')!.path,
        '/reel/abc',
      );
      expect(
        PubgetDeepLink.parse('/friend-requests')!.path,
        '/friend-requests',
      );
      expect(PubgetDeepLink.parse('/edits')!.path, '/edits');
    });

    test('blank destinations resolve to null', () {
      expect(PubgetDeepLink.parse('   '), isNull);
    });
  });

  test('entity registry maps every canonical path', () {
    final pages = EntityRoutes.pages();
    expect(pages.keys, containsAll(<String>['/reel', '/audio', '/hashtag']));
    expect(
      pages['/audio']!(<String, String>{'audioId': 'a1'}),
      isA<AudioPage>(),
    );
    expect(
      pages['/hashtag']!(<String, String>{'tag': 'anime'}),
      isA<HashtagPage>(),
    );
  });

  testWidgets('/reel/abc123 opens ReelDetailsPage', (tester) async {
    final delegate = AppRouterDelegate(
      homePage: const Text('Splash'),
      parameterizedPages: EntityRoutes.pages(),
      initialRoute: AppRouter.routeFromString('/reel/abc123'),
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: delegate,
        routeInformationParser: AppRouteInformationParser(),
      ),
    );

    expect(find.byType(ReelDetailsPage), findsOneWidget);
    expect(find.text('abc123'), findsOneWidget);
    expect(find.text('Route: /reel/abc123'), findsOneWidget);
  });

  testWidgets('legacy /edits?highlight=abc123 opens the same reel', (
    tester,
  ) async {
    final delegate = AppRouterDelegate(
      homePage: const Text('Splash'),
      parameterizedPages: EntityRoutes.pages(),
      initialRoute: AppRouter.routeFromString('/edits?highlight=abc123'),
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: delegate,
        routeInformationParser: AppRouteInformationParser(),
      ),
    );

    expect(find.byType(ReelDetailsPage), findsOneWidget);
    expect(find.text('abc123'), findsOneWidget);
    expect(find.text('Route: /reel/abc123'), findsOneWidget);
  });

  testWidgets('AppNavigation.go(/reel/abc) opens the reel route', (
    tester,
  ) async {
    final delegate = AppRouterDelegate(
      homePage: const Text('Splash'),
      parameterizedPages: EntityRoutes.pages(),
      initialRoute: const ParameterizedRoute(path: '/home'),
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: delegate,
        routeInformationParser: AppRouteInformationParser(),
      ),
    );

    // Must be a descendant of the Router, like any in-app navigation.
    final context = tester.element(find.text('Splash'));
    AppNavigation.go(context, '/reel/abc');
    await tester.pumpAndSettle();

    expect(find.byType(ReelDetailsPage), findsOneWidget);
    expect(find.text('abc'), findsOneWidget);
  });
}
