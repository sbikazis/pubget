import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_shell_scope.dart';
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
    final screen = tester.getSize(find.byType(Scaffold));
    final avatar = tester.getRect(find.byKey(const Key('home-avatar')));
    final notify = tester.getRect(find.byKey(const Key('home-notifications')));
    final coins = tester.getRect(find.byKey(const Key('home-coins')));
    final logo = tester.getRect(find.byKey(const Key('home-logo')));
    final settings = tester.getRect(find.byKey(const Key('home-settings')));
    final menu = tester.getRect(find.byKey(const Key('app-shell-menu')));

    expect(avatar.left, lessThan(notify.left));
    expect(avatar.right + 7, lessThanOrEqualTo(notify.left));
    expect(notify.right, lessThan(logo.left));
    expect(settings.left, greaterThan(logo.right));
    expect(settings.right + 7, lessThanOrEqualTo(menu.left));
    expect(logo.center.dx, closeTo(screen.width / 2, 16));
    expect(logo.overlaps(coins), isFalse);
    expect(coins.top, greaterThanOrEqualTo(logo.bottom - 2));
    expect(notify.width, closeTo(HomeTopBar.iconSize, 2));
    expect(notify.height, closeTo(HomeTopBar.iconSize, 2));
    expect(settings.width, closeTo(HomeTopBar.iconSize, 2));
    expect(menu.width, closeTo(HomeTopBar.iconSize, 2));
    expect(logo.width, closeTo(HomeTopBar.logoSize, 2));
    expect(logo.width / notify.width, closeTo(1.5, 0.12));
  }

  testWidgets('home bar keeps equal icons, 1.5x logo, and coins below', (
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
