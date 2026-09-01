import 'package:flutter/material.dart';

import 'app_route.dart';

typedef AppRouteGuard = String? Function(String path);

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
    this.domainPages = const <String, Widget>{},
    GlobalKey<NavigatorState>? navigatorKey,
    AppRoute initialRoute = const FoundationRoute(),
    this.routeGuard,
    this.refreshListenable,
  }) : _route = initialRoute,
       navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>() {
    refreshListenable?.addListener(_refreshGuard);
    _route = _guard(initialRoute);
  }

  final Widget homePage;
  final Widget? designSystemPage;
  final Map<String, Widget> domainPages;
  final AppRouteGuard? routeGuard;
  final Listenable? refreshListenable;
  @override
  final GlobalKey<NavigatorState> navigatorKey;
  AppRoute _route;

  @override
  AppRoute get currentConfiguration => _route;

  @override
  Future<void> setNewRoutePath(AppRoute configuration) async {
    _route = _guard(configuration);
    notifyListeners();
  }

  AppRoute _guard(AppRoute route) {
    if (route case ParameterizedRoute(:final path)) {
      final redirect = routeGuard?.call(path);
      if (redirect != null && redirect != path) {
        return ParameterizedRoute(path: redirect);
      }
    }
    return route;
  }

  void _refreshGuard() {
    final guarded = _guard(_route);
    if (guarded is ParameterizedRoute &&
        _route is ParameterizedRoute &&
        guarded.path == (_route as ParameterizedRoute).path) {
      return;
    }
    _route = guarded;
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_route) {
      ParameterizedRoute(:final path) when domainPages[path] != null =>
        domainPages[path]!,
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

  @override
  void dispose() {
    refreshListenable?.removeListener(_refreshGuard);
    super.dispose();
  }
}

final class AppRouter {
  const AppRouter._();

  static RouterConfig<AppRoute> createConfig({
    required Widget homePage,
    Widget? designSystemPage,
    Map<String, Widget> domainPages = const <String, Widget>{},
    AppRoute initialRoute = const FoundationRoute(),
    AppRouteGuard? routeGuard,
    Listenable? refreshListenable,
  }) {
    return RouterConfig<AppRoute>(
      routerDelegate: AppRouterDelegate(
        homePage: homePage,
        designSystemPage: designSystemPage,
        domainPages: domainPages,
        initialRoute: initialRoute,
        routeGuard: routeGuard,
        refreshListenable: refreshListenable,
      ),
      routeInformationParser: AppRouteInformationParser(),
    );
  }
}

abstract final class AppNavigation {
  static Future<void> go(BuildContext context, String path) {
    final delegate = Router.of(context).routerDelegate as AppRouterDelegate;
    return delegate.setNewRoutePath(ParameterizedRoute(path: path));
  }
}
