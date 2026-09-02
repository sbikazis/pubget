import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_route.dart';
import 'package:pubget/app/app_router.dart';

void main() {
  test('route parser retains path and query parameters', () async {
    final parser = AppRouteInformationParser();

    final route = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/groups/example?source=invite')),
    );

    expect(route, isA<ParameterizedRoute>());
    final parameterized = route as ParameterizedRoute;
    expect(parameterized.path, '/groups/example');
    expect(parameterized.parameters, {'source': 'invite'});
  });

  test('route parser restores a parameterized route', () {
    final parser = AppRouteInformationParser();

    final information = parser.restoreRouteInformation(
      const ParameterizedRoute(
        path: '/groups/example',
        parameters: {'source': 'invite'},
      ),
    );

    expect(information.uri.toString(), '/groups/example?source=invite');
  });

  testWidgets('design system path renders the internal showcase page', (
    tester,
  ) async {
    final delegate = AppRouterDelegate(
      homePage: const Text('Foundation'),
      designSystemPage: const Text('Design system'),
      initialRoute: const ParameterizedRoute(path: '/design-system'),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Router(
          routerDelegate: delegate,
          routeInformationParser: AppRouteInformationParser(),
        ),
      ),
    );

    expect(find.text('Design system'), findsOneWidget);
    expect(find.text('Foundation'), findsNothing);
  });

  test('route parser maps /event/{id} deep links', () async {
    final parser = AppRouteInformationParser();
    final route = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/event/abc123?ref=share')),
    );
    expect(route, isA<ParameterizedRoute>());
    final parameterized = route as ParameterizedRoute;
    expect(parameterized.path, '/event');
    expect(parameterized.parameters['eventId'], 'abc123');
    expect(parameterized.parameters['ref'], 'share');
  });

  test(
    'pending event deep link is restored after the guard allows it',
    () async {
      var authenticated = false;
      final delegate = AppRouterDelegate(
        homePage: const Text('Splash'),
        parameterizedPages: <String, ParameterizedPageBuilder>{
          '/event': (parameters) => Text('Event ${parameters['eventId']}'),
          '/login': (_) => const Text('Login'),
        },
        initialRoute: const ParameterizedRoute(
          path: '/event',
          parameters: {'eventId': 'e1'},
        ),
        routeGuard: (path) {
          if (path == '/event' && !authenticated) return '/login';
          return null;
        },
      );

      expect(
        (delegate.currentConfiguration as ParameterizedRoute).path,
        '/login',
      );
      authenticated = true;
      await delegate.setNewRoutePath(const ParameterizedRoute(path: '/login'));
      expect(
        (delegate.currentConfiguration as ParameterizedRoute).path,
        '/event',
      );
      expect(
        (delegate.currentConfiguration as ParameterizedRoute)
            .parameters['eventId'],
        'e1',
      );
    },
  );

  testWidgets('authentication path renders its typed domain page', (
    tester,
  ) async {
    final delegate = AppRouterDelegate(
      homePage: const Text('Splash'),
      domainPages: const <String, Widget>{'/login': Text('Login domain')},
      initialRoute: const ParameterizedRoute(path: '/login'),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Router(
          routerDelegate: delegate,
          routeInformationParser: AppRouteInformationParser(),
        ),
      ),
    );

    expect(find.text('Login domain'), findsOneWidget);
    expect(find.text('Splash'), findsNothing);
  });

  test('anime and game deep links both parse after a combined merge', () async {
    final parser = AppRouteInformationParser();
    final anime = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/anime/21')),
    );
    final game = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/game/g-1')),
    );
    expect(anime, isA<ParameterizedRoute>());
    expect((anime as ParameterizedRoute).path, '/anime/details');
    expect(anime.parameters['animeId'], '21');
    expect(game, isA<ParameterizedRoute>());
    expect((game as ParameterizedRoute).path, '/game');
    expect(game.parameters['gameId'], 'g-1');
  });

  test('route parser maps /game/{id} deep links', () async {
    final parser = AppRouteInformationParser();
    final route = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/game/abc123?ref=share')),
    );
    expect(route, isA<ParameterizedRoute>());
    final parameterized = route as ParameterizedRoute;
    expect(parameterized.path, '/game');
    expect(parameterized.parameters['gameId'], 'abc123');
    expect(parameterized.parameters['ref'], 'share');
  });

  test(
    'pending game deep link is restored after the guard allows it',
    () async {
      var authenticated = false;
      final delegate = AppRouterDelegate(
        homePage: const Text('Splash'),
        parameterizedPages: <String, ParameterizedPageBuilder>{
          '/game': (parameters) => Text('Game ${parameters['gameId']}'),
          '/login': (_) => const Text('Login'),
        },
        initialRoute: const ParameterizedRoute(
          path: '/game',
          parameters: {'gameId': 'g1'},
        ),
        routeGuard: (path) {
          if (path == '/game' && !authenticated) return '/login';
          return null;
        },
      );

      expect(
        (delegate.currentConfiguration as ParameterizedRoute).path,
        '/login',
      );
      authenticated = true;
      await delegate.setNewRoutePath(const ParameterizedRoute(path: '/login'));
      expect(
        (delegate.currentConfiguration as ParameterizedRoute).path,
        '/game',
      );
      expect(
        (delegate.currentConfiguration as ParameterizedRoute)
            .parameters['gameId'],
        'g1',
      );
    },
  );
}
