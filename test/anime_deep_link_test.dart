import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_route.dart';
import 'package:pubget/app/app_router.dart';

void main() {
  test('route parser maps /anime/{id} deep links', () async {
    final parser = AppRouteInformationParser();
    final route = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/anime/52991?ref=share')),
    );
    expect(route, isA<ParameterizedRoute>());
    final parameterized = route as ParameterizedRoute;
    expect(parameterized.path, '/anime/details');
    expect(parameterized.parameters['animeId'], '52991');
    expect(parameterized.parameters['ref'], 'share');
  });

  test('route parser maps hub, genre, season, and browse paths', () async {
    final parser = AppRouteInformationParser();
    final hub = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/anime')),
    );
    expect((hub as ParameterizedRoute).path, '/anime');

    final genre = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/anime/genre?genreId=1&name=Action')),
    );
    expect((genre as ParameterizedRoute).path, '/anime/genre');
    expect(genre.parameters['genreId'], '1');

    final season = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/anime/season?year=2026&season=winter')),
    );
    expect((season as ParameterizedRoute).path, '/anime/season');
  });

  test('pending anime deep link is restored after the guard allows it', () async {
    var authenticated = false;
    final delegate = AppRouterDelegate(
      homePage: const Text('Splash'),
      parameterizedPages: <String, ParameterizedPageBuilder>{
        '/anime/details': (parameters) =>
            Text('Anime ${parameters['animeId']}'),
        '/login': (_) => const Text('Login'),
      },
      initialRoute: const ParameterizedRoute(
        path: '/anime/details',
        parameters: {'animeId': '52991'},
      ),
      routeGuard: (path) {
        if (path == '/anime/details' && !authenticated) return '/login';
        return null;
      },
    );

    expect((delegate.currentConfiguration as ParameterizedRoute).path, '/login');
    authenticated = true;
    await delegate.setNewRoutePath(const ParameterizedRoute(path: '/login'));
    expect(
      (delegate.currentConfiguration as ParameterizedRoute).path,
      '/anime/details',
    );
    expect(
      (delegate.currentConfiguration as ParameterizedRoute).parameters['animeId'],
      '52991',
    );
  });

  testWidgets('invalid anime id still routes to the details page', (tester) async {
    final delegate = AppRouterDelegate(
      homePage: const Text('Splash'),
      parameterizedPages: <String, ParameterizedPageBuilder>{
        '/anime/details': (parameters) =>
            Text('id:${parameters['animeId'] ?? ''}'),
      },
      initialRoute: const ParameterizedRoute(
        path: '/anime/details',
        parameters: {'animeId': ''},
      ),
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
    expect(find.text('id:'), findsOneWidget);
  });
}
