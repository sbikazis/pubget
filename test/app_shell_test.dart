import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/app/app_route.dart';
import 'package:pubget/app/app_router.dart';
import 'package:pubget/app/app_shell.dart';
import 'package:pubget/app/app_shell_drawer.dart';
import 'package:pubget/app/app_shell_scope.dart';
import 'package:pubget/app/app_shell_tab.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/notifications/providers/unread_engine.dart';

import 'authentication_test_support.dart';

void main() {
  testWidgets('five tabs render and switch to the matching destination', (
    tester,
  ) async {
    final env = await _pumpShell(tester);

    expect(find.text('Discover body count 0'), findsOneWidget);
    expect(find.textContaining('Groups body'), findsNothing);

    await tester.tap(find.byIcon(Icons.group_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Joined body count 0'), findsOneWidget);
    expect(
      (env.delegate.currentConfiguration as ParameterizedRoute).path,
      '/joined',
    );

    await tester.tap(find.byIcon(Icons.forum_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Private body count 0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.movie_filter_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Edits body count 0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.groups_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Groups body count 0'), findsOneWidget);
    expect(AppShellTab.values, hasLength(5));
  });

  testWidgets('Drawer opens from every shell tab', (tester) async {
    final env = await _pumpShell(tester);
    for (final tab in AppShellTab.values) {
      await env.delegate.setNewRoutePath(ParameterizedRoute(path: tab.path));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('app-shell-menu')));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.text('My Profile'), findsOneWidget);
      tester
          .stateList<ScaffoldState>(find.byType(Scaffold))
          .firstWhere((state) => state.hasDrawer)
          .closeDrawer();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Drawer items route to existing destinations', (tester) async {
    final env = await _pumpShell(tester);

    Future<void> openAndTap(String id) async {
      await tester.tap(find.byKey(const Key('app-shell-menu')));
      await tester.pumpAndSettle();
      final finder = find.byKey(Key('drawer-$id'));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await openAndTap('profile');
    expect(
      env.delegate.currentConfiguration,
      isA<ParameterizedRoute>(),
      reason: '${env.delegate.currentConfiguration}',
    );
    final profile = env.delegate.currentConfiguration as ParameterizedRoute;
    expect(profile.path, '/profile');
    expect(profile.parameters['uid'], 'alice');
    expect(find.textContaining('Profile'), findsWidgets);

    await env.delegate.setNewRoutePath(
      const ParameterizedRoute(path: '/home'),
    );
    await tester.pumpAndSettle();
    await openAndTap('private');
    expect(find.text('Private body count 0'), findsOneWidget);

    await openAndTap('groups');
    expect(find.text('Groups body count 0'), findsOneWidget);

    await openAndTap('joined');
    expect(find.text('Joined body count 0'), findsOneWidget);

    await openAndTap('suggested');
    expect(find.text('Discover body count 0'), findsOneWidget);

    await openAndTap('store');
    expect(find.text('Store page'), findsOneWidget);

    await env.delegate.setNewRoutePath(
      const ParameterizedRoute(path: '/home'),
    );
    await tester.pumpAndSettle();
    await openAndTap('premium');
    expect(find.text('Premium page'), findsOneWidget);

    await env.delegate.setNewRoutePath(
      const ParameterizedRoute(path: '/home'),
    );
    await tester.pumpAndSettle();
    await openAndTap('settings');
    expect(find.text('Settings page'), findsOneWidget);

    await env.delegate.setNewRoutePath(
      const ParameterizedRoute(path: '/home'),
    );
    await tester.pumpAndSettle();
    await openAndTap('guide');
    expect(find.text('Guide page'), findsOneWidget);

    expect(AppShellDrawerDestinations.items, hasLength(9));
  });

  testWidgets('tab switches keep IndexedStack children alive', (tester) async {
    final env = await _pumpShell(tester);
    expect(find.text('Discover body count 0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('Discover-inc')));
    await tester.pump();
    expect(find.text('Discover body count 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.group_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Joined body count 0'), findsOneWidget);

    await env.delegate.setNewRoutePath(const ParameterizedRoute(path: '/home'));
    await tester.pumpAndSettle();
    expect(find.text('Discover body count 1'), findsOneWidget);
  });

  testWidgets('Drawer opens from the start edge in English and Arabic', (
    tester,
  ) async {
    await _pumpShell(tester, locale: const Locale('en'));
    await tester.tap(find.byKey(const Key('app-shell-menu')));
    await tester.pumpAndSettle();
    final ltrDrawer = tester.getRect(find.byType(Drawer));
    expect(ltrDrawer.left, closeTo(0, 0.5));

    await tester.tapAt(Offset(ltrDrawer.right + 8, ltrDrawer.center.dy));
    await tester.pumpAndSettle();

    await _pumpShell(tester, locale: const Locale('ar'));
    expect(
      Directionality.of(tester.element(find.byType(AppShell))),
      TextDirection.rtl,
    );
    await tester.tap(find.byKey(const Key('app-shell-menu')));
    await tester.pumpAndSettle();
    final rtlDrawer = tester.getRect(find.byType(Drawer));
    final width = tester.getSize(find.byType(MaterialApp)).width;
    expect(rtlDrawer.right, closeTo(width, 0.5));
  });
}

typedef _ShellEnv = ({AppRouterDelegate delegate, AuthProvider auth});

Future<_ShellEnv> _pumpShell(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  final authRepository = FakeAuthRepository(
    user: const AuthUser(id: 'alice', email: 'alice@example.com'),
  );
  final auth = AuthProvider(repository: authRepository);
  await auth.initialize();
  addTearDown(authRepository.close);
  addTearDown(auth.dispose);

  const shell = AppShell(
    pages: <Widget>[
      _StubTab(title: 'Discover', body: 'Discover body'),
      _StubTab(title: 'Groups', body: 'Groups body'),
      _StubTab(title: 'Joined', body: 'Joined body'),
      _StubTab(title: 'Private', body: 'Private body'),
      _StubTab(title: 'Edits', body: 'Edits body'),
    ],
  );

  final delegate = AppRouterDelegate(
    homePage: shell,
    domainPages: <String, Widget>{
      '/home': shell,
      '/groups': shell,
      '/joined': shell,
      '/private': shell,
      '/edits': shell,
      '/store': const Text('Store page'),
      '/premium': const Text('Premium page'),
      '/settings': const Text('Settings page'),
      '/guide': const Text('Guide page'),
    },
    parameterizedPages: <String, ParameterizedPageBuilder>{
      '/profile': (parameters) => Text('Profile ${parameters['uid'] ?? 'self'}'),
    },
    initialRoute: const ParameterizedRoute(path: '/home'),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<UnreadEngine>(create: (_) => UnreadEngine()),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Router<AppRoute>(
          routerDelegate: delegate,
          routeInformationParser: AppRouteInformationParser(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (delegate: delegate, auth: auth);
}

class _StubTab extends StatefulWidget {
  const _StubTab({required this.title, required this.body});

  final String title;
  final String body;

  @override
  State<_StubTab> createState() => _StubTabState();
}

class _StubTabState extends State<_StubTab> {
  var _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppShellMenuButton(),
        title: Text('${widget.title} title'),
      ),
      body: Column(
        children: <Widget>[
          Text('${widget.body} count $_count'),
          TextButton(
            key: Key('${widget.title}-inc'),
            onPressed: () => setState(() => _count++),
            child: const Text('inc'),
          ),
        ],
      ),
    );
  }
}
