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
}
