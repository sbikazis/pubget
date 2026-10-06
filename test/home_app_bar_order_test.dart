import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_shell_scope.dart';
import 'package:pubget/app/app_shell_tab.dart';
import 'package:pubget/features/home/screens/home_page.dart';

/// Pins Master Spec §4.1, which fixes the Home top bar order:
///
///   logo ← coins (+) ← dragon store ← search ← notifications ← profile ← ☰
///
/// The previous version of this test asserted the opposite (a centred logo,
/// coins on a second strip below it, and a settings button). That encoded the
/// defect the audit found: the bar was forced LTR, had no search or store
/// button, and coins were not part of the bar.
void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required Size size,
    TextDirection direction = TextDirection.rtl,
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
            child: const Scaffold(
              appBar: HomeTopBar(
                name: 'Zak',
                avatarUrl: null,
                frameId: null,
                coins: 42,
                notifyCount: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The seven controls in spec order. In RTL the first is rightmost, so each
  /// control must sit to the *left* of the previous one.
  void expectSpecOrder(WidgetTester tester) {
    final logo = tester.getRect(find.byKey(const Key('home-logo')));
    final coins = tester.getRect(find.byKey(const Key('home-coins')));
    final store = tester.getRect(find.byKey(const Key('home-store')));
    final search = tester.getRect(find.byKey(const Key('home-search')));
    final notify = tester.getRect(find.byKey(const Key('home-notifications')));
    final avatar = tester.getRect(find.byKey(const Key('home-avatar')));
    final menu = tester.getRect(find.byKey(const Key('app-shell-menu')));

    // RTL: start edge is the right edge, so each next item is further left.
    expect(logo.left, greaterThan(coins.left));
    expect(coins.left, greaterThan(store.left));
    expect(store.left, greaterThan(search.left));
    expect(search.left, greaterThan(notify.left));
    expect(notify.left, greaterThan(avatar.left));
    expect(avatar.left, greaterThan(menu.left));
  }

  void expectNoOverlapAndSizing(WidgetTester tester) {
    final logo = tester.getRect(find.byKey(const Key('home-logo')));
    final coins = tester.getRect(find.byKey(const Key('home-coins')));
    final store = tester.getRect(find.byKey(const Key('home-store')));
    final search = tester.getRect(find.byKey(const Key('home-search')));
    final notify = tester.getRect(find.byKey(const Key('home-notifications')));
    final menu = tester.getRect(find.byKey(const Key('app-shell-menu')));
    final screen = tester.getSize(find.byType(Scaffold));

    // No two controls may overlap.
    expect(logo.overlaps(coins), isFalse);
    expect(coins.overlaps(store), isFalse);
    expect(store.overlaps(search), isFalse);
    expect(search.overlaps(notify), isFalse);
    expect(notify.overlaps(menu), isFalse);

    // Everything stays inside the bar horizontally.
    for (final rect in <Rect>[logo, coins, store, search, notify, menu]) {
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(screen.width));
    }

    // §4.1 "unified icons": every icon control is the same size. The absolute
    // size is allowed to shrink on narrow phones, but never to differ.
    for (final rect in <Rect>[store, search, notify, menu]) {
      expect(rect.width, closeTo(notify.width, 1));
      expect(rect.height, closeTo(notify.height, 1));
    }

    // The logo stays visually dominant at 1.5x the icons.
    expect(
      logo.width / notify.width,
      closeTo(1.5, 0.12),
      reason: '§4.1 keeps the logo visually dominant at 1.5x the icons',
    );

    // Coins are part of the bar row, vertically centred with the icons,
    // rather than sitting on a second strip underneath it.
    expect(coins.center.dy, closeTo(notify.center.dy, 4));

    // The bar adds no extra height for a coin strip any more.
    final bar = tester.widget<HomeTopBar>(find.byType(HomeTopBar));
    expect(bar.preferredSize.height, HomeTopBar.barHeight);
  }

  testWidgets('RTL bar follows the §4.1 order: logo, coins, store, search, '
      'notifications, profile, menu', (tester) async {
    await pumpBar(tester, size: const Size(1080, 1920));
    expectSpecOrder(tester);
    expectNoOverlapAndSizing(tester);
  });

  testWidgets('RTL bar has zero overlap on a narrow phone', (tester) async {
    await pumpBar(tester, size: const Size(360, 800));
    expectSpecOrder(tester);
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

    final logo = tester.getRect(find.byKey(const Key('home-logo')));
    final menu = tester.getRect(find.byKey(const Key('app-shell-menu')));

    // Same source order, mirrored geometry: logo first in reading order.
    expect(logo.left, lessThan(menu.left));
  });

  testWidgets('the bar exposes search and store, which §4.1 requires', (
    tester,
  ) async {
    await pumpBar(tester, size: const Size(1080, 1920));

    expect(find.byKey(const Key('home-search')), findsOneWidget);
    expect(find.byKey(const Key('home-store')), findsOneWidget);
    expect(find.byKey(const Key('home-coins')), findsOneWidget);
  });

  testWidgets('coins are hidden, not faked, when the balance is unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AppShellScope(
            openDrawer: () {},
            currentTab: AppShellTab.discover,
            child: const Scaffold(
              appBar: HomeTopBar(
                name: 'Zak',
                avatarUrl: null,
                frameId: null,
                coins: null,
                notifyCount: 0,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('home-coins')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}