import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_route.dart';
import 'package:pubget/app/app_router.dart';
import 'package:pubget/features/fan_works/widgets/fan_work_widgets.dart';

void main() {
  test('canonical Fan Work links stay stable', () {
    expect(FanWorkLinks.path('abc 1'), '/fan-work/abc%201');
    expect(
      FanWorkLinks.canonical('abc 1'),
      'https://pubget-aaf27.web.app/fan-work/abc%201',
    );
  });

  test('route parser maps /fan-work/{id} deep links', () async {
    final parser = AppRouteInformationParser();
    final route = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/fan-work/abc123?ref=share')),
    );
    expect(route, isA<ParameterizedRoute>());
    final parameterized = route as ParameterizedRoute;
    expect(parameterized.path, '/fan-work');
    expect(parameterized.parameters['workId'], 'abc123');
    expect(parameterized.parameters['ref'], 'share');
  });

  test('pending Fan Work deep link is restored after login', () async {
    var authenticated = false;
    final delegate = AppRouterDelegate(
      homePage: const Text('Splash'),
      parameterizedPages: <String, ParameterizedPageBuilder>{
        '/fan-work': (parameters) => Text('Work ${parameters['workId']}'),
        '/login': (_) => const Text('Login'),
      },
      initialRoute: const ParameterizedRoute(
        path: '/fan-work',
        parameters: {'workId': 'w1'},
      ),
      routeGuard: (path) {
        if (path == '/fan-work' && !authenticated) return '/login';
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
      '/fan-work',
    );
    expect(
      (delegate.currentConfiguration as ParameterizedRoute).parameters['workId'],
      'w1',
    );
  });
}
