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
    return AppRouter.routeFromUri(routeInformation.uri);
  }

  @override
  RouteInformation restoreRouteInformation(AppRoute configuration) {
    return switch (configuration) {
      FoundationRoute() => RouteInformation(uri: Uri(path: '/')),
      ParameterizedRoute(:final path, :final parameters) => RouteInformation(
        uri: Uri(
          path: path,
          queryParameters: parameters.isEmpty ? null : parameters,
        ),
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
  }) : _stack = <AppRoute>[initialRoute],
       navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>() {
    refreshListenable?.addListener(_refreshGuard);
    _replace(_guard(initialRoute));
  }

  final Widget homePage;
  final Widget? designSystemPage;
  final Map<String, Widget> domainPages;
  final Map<String, ParameterizedPageBuilder> parameterizedPages;
  final AppRouteGuard? routeGuard;
  final Listenable? refreshListenable;
  @override
  final GlobalKey<NavigatorState> navigatorKey;
  final List<AppRoute> _stack;
  AppRoute? _pendingRoute;
  var _sessionHadProtectedAccess = false;

  AppRoute get _route => _stack.last;

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

  @visibleForTesting
  AppRoute? get pendingRoute => _pendingRoute;

  bool get canPop => _stack.length > 1 || !AppRouter.isRoot(_stack.last);

  @visibleForTesting
  List<AppRoute> get stack => List<AppRoute>.unmodifiable(_stack);

  @override
  Future<void> setNewRoutePath(AppRoute configuration) async {
    _replace(_guard(configuration));
  }

  Future<void> navigate(AppRoute configuration) async {
    final next = _guard(configuration);
    if (AppRouter.isRoot(next) || _stack.isEmpty) {
      _replace(next);
      return;
    }
    if (_sameRoute(next, _stack.last)) return;
    _stack.add(next);
    notifyListeners();
  }

  void popStack() {
    if (_stack.length > 1) {
      _stack.removeLast();
      notifyListeners();
      return;
    }
    if (!AppRouter.isRoot(_stack.last)) {
      _replace(const ParameterizedRoute(path: '/home'));
    }
  }

  void _replace(AppRoute route) {
    _stack
      ..clear()
      ..add(route);
    notifyListeners();
  }

  @override
  Future<bool> popRoute() async {
    // 1) Sheets / dialogs / local MaterialPageRoutes on this navigator.
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      final handled = await navigator.maybePop();
      if (handled) return true;
    }
    // 2) App route stack (one step only).
    if (canPop) {
      popStack();
      return true;
    }
    // 3) Shell / login roots: absorb hardware back — never exit the app.
    return true;
  }

  void clearPending() {
    _pendingRoute = null;
    _sessionHadProtectedAccess = false;
  }

  AppRoute _guard(AppRoute route) {
    if (route case ParameterizedRoute(:final path)) {
      final redirect = routeGuard?.call(path);
      if (redirect != null && redirect != path) {
        final signingOutToLogin =
            redirect == '/login' && _sessionHadProtectedAccess;
        if (signingOutToLogin) {
          _pendingRoute = null;
          _sessionHadProtectedAccess = false;
        } else if (!_authFlowPaths.contains(path)) {
          _pendingRoute = route;
        }
        return ParameterizedRoute(path: redirect);
      }
      if (redirect == null && !_authFlowPaths.contains(path)) {
        _sessionHadProtectedAccess = true;
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
    if (AppRouter.isRoot(guarded)) {
      _replace(guarded);
      return;
    }
    _stack[_stack.length - 1] = guarded;
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
      ParameterizedRoute(:final path) when path == '/' || path.isEmpty =>
        homePage,
      FoundationRoute() => homePage,
      _ => domainPages['/unknown'] ?? homePage,
    };
    final pageKey = switch (_route) {
      FoundationRoute() => const ValueKey<String>('foundation'),
      ParameterizedRoute(:final path)
          when AppRouter.shellPaths.contains(path) =>
        const ValueKey<String>('app-shell'),
      ParameterizedRoute(:final path) => ValueKey<String>(path),
    };

    return Navigator(
      key: navigatorKey,
      pages: <Page<void>>[MaterialPage<void>(key: pageKey, child: page)],
      // v2 game screens use named navigation for secondary destinations
      // (rules, for example). Keep those destinations on the same router
      // registry instead of relying on an app-level MaterialApp route table.
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri == null) return null;
        final route = AppRouter.routeFromUri(uri);
        if (route case ParameterizedRoute(:final path, :final parameters)) {
          final builder = parameterizedPages[path];
          if (builder != null) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => builder(parameters),
            );
          }
          final domain = domainPages[path];
          if (domain != null) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => domain,
            );
          }
        }
        return null;
      },
      onDidRemovePage: (page) {
        // Overlay routes (Drawer) share this Navigator. Ignore those pops.
        // In-app back is handled by [popStack]; do not reset to splash.
        if (page.key != pageKey) {
          return;
        }
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

  static const shellPaths = <String>{
    '/home',
    '/groups',
    '/joined',
    '/private',
    '/edits',
  };

  /// Destinations that reset history. No back arrow on these screens.
  static const rootPaths = <String>{
    '/splash',
    '/login',
    '/onboarding',
    '/reels',
    ...shellPaths,
  };

  static bool isRoot(AppRoute route) => switch (route) {
    FoundationRoute() => true,
    ParameterizedRoute(:final path) => rootPaths.contains(path),
  };

  static AppRoute routeFromUri(Uri uri) {
    try {
      return _routeFromUri(uri);
    } catch (_) {
      return const ParameterizedRoute(path: '/unknown');
    }
  }

  static AppRoute routeFromString(String raw) {
    try {
      return _routeFromUri(Uri.parse(raw));
    } catch (_) {
      return const ParameterizedRoute(path: '/unknown');
    }
  }

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
    return delegate.navigate(AppRouter.routeFromString(path));
  }

  /// Single-step dismiss: local navigator layer first, then app stack.
  /// Never calls [SystemNavigator.pop] / never exits the app.
  static Future<bool> popLayer(BuildContext context) async {
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) {
      return navigator.maybePop();
    }
    final delegate = Router.maybeOf(context)?.routerDelegate;
    if (delegate is AppRouterDelegate && delegate.canPop) {
      delegate.popStack();
      return true;
    }
    return false;
  }

  static Future<void> back(BuildContext context) async {
    await popLayer(context);
  }

  static bool canPop(BuildContext context) {
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) return true;
    final delegate = Router.maybeOf(context)?.routerDelegate;
    if (delegate is AppRouterDelegate) return delegate.canPop;
    return false;
  }
}

AppRoute _routeFromUri(Uri uri) {
  final segments = [
    for (final segment in uri.pathSegments)
      if (segment.isNotEmpty) segment,
  ];
  final query = uri.queryParameters;

  ParameterizedRoute entity({
    required String path,
    required String key,
    required String id,
  }) {
    if (id.trim().isEmpty) {
      return const ParameterizedRoute(path: '/unknown');
    }
    return ParameterizedRoute(
      path: path,
      parameters: <String, String>{...query, key: id},
    );
  }

  if (segments.length == 2 && segments.first == 'event') {
    return entity(path: '/event', key: 'eventId', id: segments[1]);
  }
  if (segments.isNotEmpty && segments.first == 'anime') {
    if (segments.length == 1) {
      return ParameterizedRoute(path: '/anime', parameters: query);
    }
    final second = segments[1];
    if (second == 'browse' ||
        second == 'genre' ||
        second == 'season' ||
        second == 'library' ||
        second == 'ratings' ||
        second == 'characters' ||
        second == 'me') {
      return ParameterizedRoute(path: '/anime/$second', parameters: query);
    }
    return entity(path: '/anime/details', key: 'animeId', id: second);
  }
  if (segments.length == 2 && segments.first == 'game') {
    return entity(path: '/game', key: 'gameId', id: segments[1]);
  }
  if (segments.length == 2 && segments.first == 'mafia') {
    return entity(path: '/mafia', key: 'gameId', id: segments[1]);
  }
  if (segments.length == 2 && segments.first == 'fan-work') {
    return entity(path: '/fan-work', key: 'workId', id: segments[1]);
  }
  if (segments.length == 2 && segments.first == 'group') {
    return entity(path: '/group', key: 'groupId', id: segments[1]);
  }
  if (segments.length == 2 && segments.first == 'profile') {
    return entity(path: '/profile', key: 'uid', id: segments[1]);
  }
  if (segments.isEmpty) {
    return const FoundationRoute();
  }
  final path = '/${segments.join('/')}';
  if (path == '/unknown') {
    return const ParameterizedRoute(path: '/unknown');
  }
  return _requireEntityId(ParameterizedRoute(path: path, parameters: query));
}

const _requiredEntityKeys = <String, String>{
  '/event': 'eventId',
  '/game': 'gameId',
  '/games/waiting': 'gameId',
  '/games/room': 'gameId',
  '/mafia': 'gameId',
  '/fan-work': 'workId',
  '/group': 'groupId',
  '/anime/details': 'animeId',
  '/store/item': 'itemId',
};

AppRoute _requireEntityId(ParameterizedRoute route) {
  final key = _requiredEntityKeys[route.path];
  if (key == null) return route;
  final id = route.parameters[key]?.trim() ?? '';
  if (id.isEmpty) {
    return const ParameterizedRoute(path: '/unknown');
  }
  return route;
}
