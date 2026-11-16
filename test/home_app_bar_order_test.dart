import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_shell_scope.dart';
import 'package:pubget/app/app_shell_tab.dart';
import 'package:pubget/features/home/screens/home_page.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
                coins: 42,
                notifyCount: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void expectBarLayout(WidgetTester tester) {
    final logo = tester.getRect(find.byKey(const Key('home-logo')));
    final coins = tester.getRect(find.byKey(const Key('home-coins')));
    final store = tester.getRect(find.byKey(const Key('home-store')));
    final search = tester.getRect(find.byKey(const Key('home-search')));
    final notify = tester.getRect(find.byKey(const Key('home-notifications')));
    final avatar = tester.getRect(find.byKey(const Key('home-avatar')));
    final menu = tester.getRect(find.byKey(const Key('app-shell-menu')));

    // Master Spec §4.1 — RTL order, right to left.
    final ordered = <Rect>[logo, coins, store, search, notify, avatar, menu];
    for (var i = 0; i < ordered.length - 1; i++) {
      expect(
        ordered[i].right,
        greaterThan(ordered[i + 1].right),
        reason: 'slot $i must sit to the right of slot ${i + 1}',
      );
      expect(
        ordered[i].left,
        greaterThanOrEqualTo(ordered[i + 1].right),
        reason: 'slot $i overlaps slot ${i + 1}',
      );
    }

    expect(logo.width, closeTo(HomeTopBar.logoSize, 2));
    for (final rect in <Rect>[store, search, notify, avatar, menu]) {
      expect(rect.width, closeTo(HomeTopBar.iconSize, 2));
      expect(rect.height, closeTo(HomeTopBar.iconSize, 2));
    }
    expect(find.byKey(const Key('home-settings')), findsNothing);
  }

  testWidgets('home bar follows the spec RTL order on a tablet', (
    tester,
  ) async {
    await pumpBar(tester, size: const Size(1080, 1920));
    expectBarLayout(tester);
  });

  testWidgets('home bar has zero overlap on a narrow phone', (tester) async {
    await pumpBar(tester, size: const Size(360, 800));
    expectBarLayout(tester);
  });
}
