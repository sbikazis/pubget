import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_route.dart';

typedef AppRouteGuard = String? Function(String path);
typedef ParameterizedPageBuilder =
    Widget Function(Map<String, String> parameters);

final class AppRouteInformationParser extends RouteInformationParser<AppRoute> {
  @override
  Future<AppRoute> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    if (uri.path.isEmpty || uri.path == '/') {
      return const FoundationRoute();
    }
    return _routeFromUri(uri);
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
    this.parameterizedPages = const <String, ParameterizedPageBuilder>{},
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
  final Map<String, ParameterizedPageBuilder> parameterizedPages;
  final AppRouteGuard? routeGuard;
  final Listenable? refreshListenable;
  @override
  final GlobalKey<NavigatorState> navigatorKey;
  AppRoute _route;
  AppRoute? _pendingRoute;

  static const _authFlowPaths = <String>{
    '/login',
    '/register',
    '/splash',
    '/onboarding',
    '/terms',
    '/forgot-password',
  };

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
        if (!_authFlowPaths.contains(path)) {
          _pendingRoute = route;
        }
        return ParameterizedRoute(path: redirect);
      }
    }
    if (_pendingRoute != null) {
      final pending = _pendingRoute!;
      if (pending case ParameterizedRoute(:final path)) {
        final redirect = routeGuard?.call(path);
        if (redirect == null) {
          _pendingRoute = null;
          return pending;
        }
      }
    }
    return route;
  }

  void _refreshGuard() {
    final guarded = _guard(_route);
    if (_sameRoute(guarded, _route)) return;
    _route = guarded;
    notifyListeners();
  }

  bool _sameRoute(AppRoute left, AppRoute right) {
    if (left is FoundationRoute && right is FoundationRoute) return true;
    if (left is ParameterizedRoute && right is ParameterizedRoute) {
      return left.path == right.path &&
          mapEquals(left.parameters, right.parameters);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_route) {
      ParameterizedRoute(:final path, :final parameters)
          when parameterizedPages[path] != null =>
        parameterizedPages[path]!(parameters),
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

  static AppRoute routeFromUri(Uri uri) => _routeFromUri(uri);

  static RouterConfig<AppRoute> createConfig({
    required Widget homePage,
    Widget? designSystemPage,
    Map<String, Widget> domainPages = const <String, Widget>{},
    Map<String, ParameterizedPageBuilder> parameterizedPages =
        const <String, ParameterizedPageBuilder>{},
    AppRoute initialRoute = const FoundationRoute(),
    AppRouteGuard? routeGuard,
    Listenable? refreshListenable,
  }) {
    return RouterConfig<AppRoute>(
      routerDelegate: AppRouterDelegate(
        homePage: homePage,
        designSystemPage: designSystemPage,
        domainPages: domainPages,
        parameterizedPages: parameterizedPages,
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
    return delegate.setNewRoutePath(_routeFromUri(Uri.parse(path)));
  }
}

AppRoute _routeFromUri(Uri uri) {
  if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'event') {
    return ParameterizedRoute(
      path: '/event',
      parameters: <String, String>{
        ...uri.queryParameters,
        'eventId': uri.pathSegments[1],
      },
    );
  }
  if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'game') {
    return ParameterizedRoute(
      path: '/game',
      parameters: <String, String>{
        ...uri.queryParameters,
        'gameId': uri.pathSegments[1],
      },
    );
  }
  if (uri.path.isEmpty || uri.path == '/') {
    return const FoundationRoute();
  }
  return ParameterizedRoute(path: uri.path, parameters: uri.queryParameters);
}
