import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_back_button.dart';
import 'package:pubget/app/app_route.dart';
import 'package:pubget/app/app_router.dart';
import 'package:pubget/core/widgets/pubget_bottom_sheet.dart';

void main() {
  test('shell and login are roots; settings is not', () {
    expect(AppRouter.isRoot(const ParameterizedRoute(path: '/home')), isTrue);
    expect(AppRouter.isRoot(const ParameterizedRoute(path: '/login')), isTrue);
    expect(AppRouter.isRoot(const ParameterizedRoute(path: '/groups')), isTrue);
    expect(
      AppRouter.isRoot(const ParameterizedRoute(path: '/settings')),
      isFalse,
    );
    expect(AppRouter.isRoot(const FoundationRoute()), isTrue);
  });

  test('navigate stacks pushed pages and pop restores the previous', () async {
    final delegate = AppRouterDelegate(
      homePage: const Text('Splash'),
      domainPages: const <String, Widget>{
        '/home': Text('Home'),
        '/settings': Text('Settings'),
        '/guide': Text('Guide'),
        '/login': Text('Login'),
      },
      initialRoute: const ParameterizedRoute(path: '/home'),
    );

    expect(delegate.canPop, isFalse);
    await delegate.navigate(const ParameterizedRoute(path: '/settings'));
    expect(
      (delegate.currentConfiguration as ParameterizedRoute).path,
      '/settings',
    );
    expect(delegate.canPop, isTrue);
    expect(delegate.stack, hasLength(2));

    await delegate.navigate(const ParameterizedRoute(path: '/guide'));
    expect(
      (delegate.currentConfiguration as ParameterizedRoute).path,
      '/guide',
    );
    expect(delegate.stack, hasLength(3));

    delegate.popStack();
    expect(
      (delegate.currentConfiguration as ParameterizedRoute).path,
      '/settings',
    );
    delegate.popStack();
    expect(
      (delegate.currentConfiguration as ParameterizedRoute).path,
      '/home',
    );
    expect(delegate.canPop, isFalse);
  });

  test('navigating to a shell tab resets history', () async {
    final delegate = AppRouterDelegate(
      homePage: const Text('Splash'),
      domainPages: const <String, Widget>{
        '/home': Text('Home'),
        '/settings': Text('Settings'),
        '/groups': Text('Groups'),
      },
      initialRoute: const ParameterizedRoute(path: '/home'),
    );
    await delegate.navigate(const ParameterizedRoute(path: '/settings'));
    await delegate.navigate(const ParameterizedRoute(path: '/groups'));
    expect(
      (delegate.currentConfiguration as ParameterizedRoute).path,
      '/groups',
    );
    expect(delegate.stack, hasLength(1));
    expect(delegate.canPop, isFalse);
  });

  test('deep-linked detail still has a back fallback to home', () {
    final delegate = AppRouterDelegate(
      homePage: const Text('Splash'),
      domainPages: const <String, Widget>{
        '/home': Text('Home'),
        '/settings': Text('Settings'),
      },
      initialRoute: const ParameterizedRoute(path: '/settings'),
    );
    expect(delegate.canPop, isTrue);
    expect(delegate.stack, hasLength(1));
    delegate.popStack();
    expect(
      (delegate.currentConfiguration as ParameterizedRoute).path,
      '/home',
    );
  });

  testWidgets('settings shows a back arrow that returns to home', (
    tester,
  ) async {
    final delegate = AppRouterDelegate(
      homePage: const Text('Splash'),
      domainPages: <String, Widget>{
        '/home': const Scaffold(body: Text('Home body')),
        '/settings': Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              leading: AppBackButton.maybeOf(context),
              title: const Text('Settings title'),
            ),
            body: const Text('Settings body'),
          ),
        ),
      },
      initialRoute: const ParameterizedRoute(path: '/home'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Router(
          routerDelegate: delegate,
          routeInformationParser: AppRouteInformationParser(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home body'), findsOneWidget);
    expect(find.byKey(const Key('app-back')), findsNothing);

    await delegate.navigate(const ParameterizedRoute(path: '/settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings body'), findsOneWidget);
    expect(find.byKey(const Key('app-back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-back')));
    await tester.pumpAndSettle();
    expect(find.text('Home body'), findsOneWidget);
    expect(find.text('Settings body'), findsNothing);
  });

  test('hardware back at shell root is absorbed (does not exit)', () async {
    final delegate = AppRouterDelegate(
      homePage: const Text('Splash'),
      domainPages: const <String, Widget>{
        '/home': Text('Home'),
      },
      initialRoute: const ParameterizedRoute(path: '/home'),
    );
    expect(delegate.canPop, isFalse);
    final handled = await delegate.popRoute();
    expect(handled, isTrue);
    expect(
      (delegate.currentConfiguration as ParameterizedRoute).path,
      '/home',
    );
  });

  testWidgets('local route pops before app stack on hardware back', (
    tester,
  ) async {
    final delegate = AppRouterDelegate(
      homePage: const Text('Splash'),
      domainPages: <String, Widget>{
        '/home': const Scaffold(body: Text('Home body')),
        '/settings': Builder(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(
                leading: AppBackButton.maybeOf(context),
                title: const Text('Settings'),
              ),
              body: Center(
                child: ElevatedButton(
                  key: const Key('open-local'),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            automaticallyImplyLeading: false,
                            leading: IconButton(
                              key: const Key('local-back'),
                              icon: const BackButtonIcon(),
                              onPressed: () =>
                                  Navigator.of(context).maybePop(),
                            ),
                            title: const Text('Local page'),
                          ),
                          body: const Text('Local body'),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open local'),
                ),
              ),
            );
          },
        ),
      },
      initialRoute: const ParameterizedRoute(path: '/home'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Router(
          routerDelegate: delegate,
          routeInformationParser: AppRouteInformationParser(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await delegate.navigate(const ParameterizedRoute(path: '/settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-local')));
    await tester.pumpAndSettle();
    expect(find.text('Local body'), findsOneWidget);

    final handled = await delegate.popRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(find.text('Local body'), findsNothing);
    expect(find.text('Open local'), findsOneWidget);
    expect(
      (delegate.currentConfiguration as ParameterizedRoute).path,
      '/settings',
    );
  });

  testWidgets('bottom sheet closes via close control without popping stack', (
    tester,
  ) async {
    final delegate = AppRouterDelegate(
      homePage: const Text('Splash'),
      domainPages: <String, Widget>{
        '/home': Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open-sheet'),
                  onPressed: () {
                    PubgetBottomSheet.show<void>(
                      context,
                      title: 'Sheet title',
                      child: const Text('Sheet body'),
                    );
                  },
                  child: const Text('Open sheet'),
                ),
              ),
            );
          },
        ),
      },
      initialRoute: const ParameterizedRoute(path: '/home'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Router(
          routerDelegate: delegate,
          routeInformationParser: AppRouteInformationParser(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-sheet')));
    await tester.pumpAndSettle();
    expect(find.text('Sheet body'), findsOneWidget);
    expect(find.byKey(const Key('sheet-close')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sheet-close')));
    await tester.pumpAndSettle();
    expect(find.text('Sheet body'), findsNothing);
    expect(
      (delegate.currentConfiguration as ParameterizedRoute).path,
      '/home',
    );
  });
}
