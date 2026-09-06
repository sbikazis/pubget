import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_back_button.dart';
import 'package:pubget/app/app_route.dart';
import 'package:pubget/app/app_router.dart';

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
}
