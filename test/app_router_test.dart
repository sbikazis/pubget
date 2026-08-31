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
}
