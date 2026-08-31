import 'package:flutter/material.dart';

import 'app_route.dart';

final class AppRouteInformationParser extends RouteInformationParser<AppRoute> {
  @override
  Future<AppRoute> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    if (uri.path.isEmpty || uri.path == '/') {
      return const FoundationRoute();
    }

    return ParameterizedRoute(path: uri.path, parameters: uri.queryParameters);
  }

  @override
  RouteInformation restoreRouteInformation(AppRoute configuration) {
    return switch (configuration) {
      FoundationRoute() => RouteInformation(uri: Uri(path: '/')),
      ParameterizedRoute(:final path, :final parameters) => RouteInformation(
        uri: Uri(path: path, queryParameters: parameters),
      ),
    };
  }
}

final class AppRouterDelegate extends RouterDelegate<AppRoute>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRoute> {
  AppRouterDelegate({
    required this.homePage,
    GlobalKey<NavigatorState>? navigatorKey,
    AppRoute initialRoute = const FoundationRoute(),
  }) : _route = initialRoute,
       navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>();

  final Widget homePage;
  @override
  final GlobalKey<NavigatorState> navigatorKey;
  AppRoute _route;

  @override
  AppRoute get currentConfiguration => _route;

  @override
  Future<void> setNewRoutePath(AppRoute configuration) async {
    _route = configuration;
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: <Page<void>>[MaterialPage<void>(child: homePage)],
      onDidRemovePage: (_) {
        _route = const FoundationRoute();
        notifyListeners();
      },
    );
  }
}

final class AppRouter {
  const AppRouter._();

  static RouterConfig<AppRoute> createConfig({
    required Widget homePage,
    AppRoute initialRoute = const FoundationRoute(),
  }) {
    return RouterConfig<AppRoute>(
      routerDelegate: AppRouterDelegate(
        homePage: homePage,
        initialRoute: initialRoute,
      ),
      routeInformationParser: AppRouteInformationParser(),
    );
  }
}
