import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_route.dart';
import 'package:pubget/app/app_router.dart';
import 'package:pubget/app/app_shell_scope.dart';
import 'package:pubget/app/app_shell_tab.dart';
import 'package:pubget/features/home/screens/home_page.dart';

/// Pins the revised Home top bar layout:
///
///   [☰ drawer]              Pubget              [search][notifications][avatar]
///
/// The drawer affordance leads, the brand mark is visually centred, and the
/// discovery/act controls trail. Store and the coin balance deliberately moved
/// into the navigation drawer (§4.1 revision), so the bar is no longer crowded
/// by seven controls and never renders `home-store` / `home-coins`.
void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required Size size,
    TextDirection direction = TextDirection.rtl,
    int notifyCount = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: AppShellScope(
            openDrawer: () {},
            currentTab: AppShellTab.discover,
            child: Scaffold(
              appBar: HomeTopBar(
                name: 'Zak',
                avatarUrl: null,
                frameId: null,
                notifyCount: notifyCount,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Rect rect(WidgetTester tester, String key) =>
      tester.getRect(find.byKey(Key(key)));

  /// RTL reading order is right to left, so each control sits further left than
  /// the previous one: menu, logo, search, notifications, avatar.
  void expectRtlOrder(WidgetTester tester) {
    final menu = rect(tester, 'app-shell-menu');
    final logo = rect(tester, 'home-logo');
    final search = rect(tester, 'home-search');
    final notify = rect(tester, 'home-notifications');
    final avatar = rect(tester, 'home-avatar');

    expect(menu.left, greaterThan(logo.left), reason: 'drawer leads (right)');
    expect(logo.left, greaterThan(search.left));
    expect(search.left, greaterThan(notify.left));
    expect(
      notify.left,
      greaterThan(avatar.left),
      reason: 'avatar trails (left)',
    );
  }

  /// The same source order mirrors in English: menu, logo, search, notify,
  /// avatar left to right.
  void expectLtrOrder(WidgetTester tester) {
    final menu = rect(tester, 'app-shell-menu');
    final logo = rect(tester, 'home-logo');
    final search = rect(tester, 'home-search');
    final notify = rect(tester, 'home-notifications');
    final avatar = rect(tester, 'home-avatar');

    expect(menu.left, lessThan(logo.left), reason: 'drawer leads (left)');
    expect(logo.left, lessThan(search.left));
    expect(search.left, lessThan(notify.left));
    expect(notify.left, lessThan(avatar.left), reason: 'avatar trails (right)');
  }

  void expectNoOverlapAndSizing(WidgetTester tester) {
    final logo = rect(tester, 'home-logo');
    final menu = rect(tester, 'app-shell-menu');
    final search = rect(tester, 'home-search');
    final notify = rect(tester, 'home-notifications');
    final avatar = rect(tester, 'home-avatar');
    final screen = tester.getSize(find.byType(Scaffold));

    for (final r in <Rect>[logo, menu, search, notify, avatar]) {
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(screen.width));
    }

    // The logo lives in the centre and must not be collided into by either
    // cluster.
    expect(logo.overlaps(menu), isFalse);
    expect(logo.overlaps(search), isFalse);
    expect(logo.overlaps(notify), isFalse);
    expect(logo.overlaps(avatar), isFalse);
    expect(menu.overlaps(search), isFalse);
    expect(search.overlaps(notify), isFalse);
    expect(notify.overlaps(avatar), isFalse);

    // Every icon control is the same size (it may shrink on narrow phones but
    // never differ between controls).
    for (final r in <Rect>[menu, search, notify, avatar]) {
      expect(r.width, closeTo(notify.width, 1));
      expect(r.height, closeTo(notify.height, 1));
    }

    // The logo stays visually dominant at 1.5x the icons.
    expect(
      logo.width / notify.width,
      closeTo(1.5, 0.12),
      reason: 'the brand mark stays dominant at 1.5x the icons',
    );

    // The bar height never changes.
    final bar = tester.widget<HomeTopBar>(find.byType(HomeTopBar));
    expect(bar.preferredSize.height, HomeTopBar.barHeight);
  }

  testWidgets('RTL bar reads menu, logo, search, notifications, avatar', (
    tester,
  ) async {
    await pumpBar(tester, size: const Size(1080, 1920));
    expectRtlOrder(tester);
    expectNoOverlapAndSizing(tester);
  });

  testWidgets('RTL bar has zero overlap on a narrow phone', (tester) async {
    await pumpBar(tester, size: const Size(360, 800));
    expectRtlOrder(tester);
    expectNoOverlapAndSizing(tester);
  });

  testWidgets('the bar is directional, so English mirrors the RTL order', (
    tester,
  ) async {
    await pumpBar(
      tester,
      size: const Size(1080, 1920),
      direction: TextDirection.ltr,
    );
    expectLtrOrder(tester);
    expectNoOverlapAndSizing(tester);
  });

  testWidgets('store and coins are no longer part of the bar', (tester) async {
    await pumpBar(tester, size: const Size(1080, 1920));

    expect(find.byKey(const Key('app-shell-menu')), findsOneWidget);
    expect(find.byKey(const Key('home-logo')), findsOneWidget);
    expect(find.byKey(const Key('home-search')), findsOneWidget);
    expect(find.byKey(const Key('home-notifications')), findsOneWidget);
    expect(find.byKey(const Key('home-avatar')), findsOneWidget);

    // Moved into the drawer.
    expect(find.byKey(const Key('home-store')), findsNothing);
    expect(find.byKey(const Key('home-coins')), findsNothing);
  });

  testWidgets('search, notifications and avatar open their real destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final delegate = AppRouterDelegate(
      homePage: Builder(
        builder: (context) => Scaffold(
          appBar: HomeTopBar(
            name: 'Zak',
            avatarUrl: null,
            frameId: null,
            notifyCount: 2,
          ),
        ),
      ),
      domainPages: <String, Widget>{
        '/search': const Text('Search destination'),
        '/notifications': const Text('Notifications destination'),
        '/profile': const Text('Profile destination'),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: AppShellScope(
            openDrawer: () {},
            currentTab: AppShellTab.discover,
            child: Router<AppRoute>(
              routerDelegate: delegate,
              routeInformationParser: AppRouteInformationParser(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> tapAndReturn(
      String key,
      String path,
      String destination,
    ) async {
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect((delegate.currentConfiguration as ParameterizedRoute).path, path);
      expect(find.text(destination), findsOneWidget);
      // Return to Home (a shell path resolves back to the home page).
      await delegate.navigate(AppRouter.routeFromString('/home'));
      await tester.pumpAndSettle();
    }

    await tapAndReturn('home-search', '/search', 'Search destination');
    await tapAndReturn(
      'home-notifications',
      '/notifications',
      'Notifications destination',
    );
    await tapAndReturn('home-avatar', '/profile', 'Profile destination');
  });
}
