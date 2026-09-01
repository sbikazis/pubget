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
    this.designSystemPage,
    GlobalKey<NavigatorState>? navigatorKey,
    AppRoute initialRoute = const FoundationRoute(),
  }) : _route = initialRoute,
       navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>();

  final Widget homePage;
  final Widget? designSystemPage;
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
    final page = switch (_route) {
      ParameterizedRoute(:final path)
          when designSystemPage != null &&
              (path == '/design-system' || path == '/design-system/') =>
        designSystemPage!,
      _ => homePage,
    };
    final pageKey = switch (_route) {
      FoundationRoute() => const ValueKey<String>('foundation'),
      ParameterizedRoute(:final path) => ValueKey<String>(path),
    };

    return Navigator(
      key: navigatorKey,
      pages: <Page<void>>[MaterialPage<void>(key: pageKey, child: page)],
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
    Widget? designSystemPage,
    AppRoute initialRoute = const FoundationRoute(),
  }) {
    return RouterConfig<AppRoute>(
      routerDelegate: AppRouterDelegate(
        homePage: homePage,
        designSystemPage: designSystemPage,
        initialRoute: initialRoute,
      ),
      routeInformationParser: AppRouteInformationParser(),
    );
  }
}
