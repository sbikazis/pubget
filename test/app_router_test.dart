import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_route.dart';
import 'package:pubget/app/app_router.dart';

void main() {
  test('route parser maps /guide as a normal path', () async {
    final parser = AppRouteInformationParser();
    final route = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/guide')),
    );
    expect(route, isA<ParameterizedRoute>());
    expect((route as ParameterizedRoute).path, '/guide');
  });

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

  test('route parser maps /mafia/{id} and /achievements deep links', () async {
    final parser = AppRouteInformationParser();
    final mafia = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/mafia/m-1')),
    );
    expect(mafia, isA<ParameterizedRoute>());
    expect((mafia as ParameterizedRoute).path, '/mafia');
    expect(mafia.parameters['gameId'], 'm-1');
    final achievements = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/achievements?id=first_group')),
    );
    expect(achievements, isA<ParameterizedRoute>());
    expect((achievements as ParameterizedRoute).path, '/achievements');
    expect(achievements.parameters['id'], 'first_group');
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

  test('route parser maps /store/item query links', () async {
    final parser = AppRouteInformationParser();
    final route = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/store/item?itemId=frame_sakura')),
    );
    expect(route, isA<ParameterizedRoute>());
    final parameterized = route as ParameterizedRoute;
    expect(parameterized.path, '/store/item');
    expect(parameterized.parameters['itemId'], 'frame_sakura');
  });

  test('trailing slashes, encoding, and entity aliases parse safely', () async {
    final parser = AppRouteInformationParser();

    Future<ParameterizedRoute> parse(String raw) async {
      final route = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse(raw)),
      );
      return route as ParameterizedRoute;
    }

    final event = await parse('/event/abc123/');
    expect(event.path, '/event');
    expect(event.parameters['eventId'], 'abc123');

    final encoded = await parse('/event/abc%201');
    expect(encoded.parameters['eventId'], 'abc 1');

    final arabic = await parse('/event/${Uri.encodeComponent('حدث')}');
    expect(arabic.parameters['eventId'], 'حدث');

    final fanWork = await parse('/fan-work/w1?view=manga');
    expect(fanWork.path, '/fan-work');
    expect(fanWork.parameters['view'], 'manga');

    final browse = await parse('/anime/browse?kind=trending');
    expect(browse.path, '/anime/browse');
    expect(browse.parameters['kind'], 'trending');

    final genre = await parse('/anime/genre?genreId=1&name=Action');
    expect(genre.path, '/anime/genre');
    expect(genre.parameters['genreId'], '1');

    final season = await parse('/anime/season?year=2024&season=fall');
    expect(season.path, '/anime/season');
    expect(season.parameters['year'], '2024');

    final store = await parse('/store');
    expect(store.path, '/store');

    final group = await parse('/group/g-1');
    expect(group.path, '/group');
    expect(group.parameters['groupId'], 'g-1');

    final profile = await parse('/profile/u-1');
    expect(profile.path, '/profile');
    expect(profile.parameters['uid'], 'u-1');
  });

  test('missing ids, unknown routes, and malformed URIs fall back safely', () {
    ParameterizedRoute asRoute(AppRoute route) => route as ParameterizedRoute;

    expect(asRoute(AppRouter.routeFromString('/event/')).path, '/unknown');
    expect(asRoute(AppRouter.routeFromString('/event')).path, '/unknown');
    expect(asRoute(AppRouter.routeFromString('/game/')).path, '/unknown');
    expect(asRoute(AppRouter.routeFromString('/mafia/')).path, '/unknown');
    expect(asRoute(AppRouter.routeFromString('/fan-work/')).path, '/unknown');
    expect(asRoute(AppRouter.routeFromString('/store/item')).path, '/unknown');
    expect(asRoute(AppRouter.routeFromString('/not-a-real-route')).path, '/not-a-real-route');
    expect(asRoute(AppRouter.routeFromString(':')).path, '/unknown');
  });

  testWidgets('unknown routes render the fallback page instead of crashing', (
    tester,
  ) async {
    final delegate = AppRouterDelegate(
      homePage: const Text('Splash'),
      domainPages: const <String, Widget>{
        '/unknown': Text('Unknown link'),
      },
      initialRoute: const ParameterizedRoute(path: '/totally-missing'),
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

    expect(find.text('Unknown link'), findsOneWidget);
  });

  test('cancelled login keeps the pending target without looping', () async {
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

    expect((delegate.currentConfiguration as ParameterizedRoute).path, '/login');
    expect(delegate.pendingRoute, isNotNull);
    await delegate.setNewRoutePath(const ParameterizedRoute(path: '/login'));
    expect((delegate.currentConfiguration as ParameterizedRoute).path, '/login');
    expect(
      (delegate.pendingRoute as ParameterizedRoute).parameters['eventId'],
      'e1',
    );
  });

  test('sign-out clears a previously restored protected destination', () async {
    var authenticated = true;
    final delegate = AppRouterDelegate(
      homePage: const Text('Splash'),
      parameterizedPages: <String, ParameterizedPageBuilder>{
        '/home': (_) => const Text('Home'),
        '/event': (parameters) => Text('Event ${parameters['eventId']}'),
        '/login': (_) => const Text('Login'),
      },
      initialRoute: const ParameterizedRoute(path: '/home'),
      routeGuard: (path) {
        if (path != '/login' && !authenticated) return '/login';
        return null;
      },
    );

    expect((delegate.currentConfiguration as ParameterizedRoute).path, '/home');
    authenticated = false;
    await delegate.setNewRoutePath(const ParameterizedRoute(path: '/home'));
    expect((delegate.currentConfiguration as ParameterizedRoute).path, '/login');
    expect(delegate.pendingRoute, isNull);
  });
}
