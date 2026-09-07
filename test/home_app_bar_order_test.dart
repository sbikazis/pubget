import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_shell_scope.dart';
import 'package:pubget/features/home/screens/home_page.dart';

void main() {
  testWidgets('home bar keeps the logo centered with profile left and menu right', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
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

    final screen = tester.getSize(find.byType(Scaffold));
    final avatar = tester.getRect(find.byKey(const Key('home-avatar')));
    final notify = tester.getRect(find.byKey(const Key('home-notifications')));
    final coins = tester.getRect(find.byKey(const Key('home-coins')));
    final logo = tester.getRect(find.byKey(const Key('home-logo')));
    final settings = tester.getRect(find.byKey(const Key('home-settings')));
    final menu = tester.getRect(find.byKey(const Key('app-shell-menu')));

    expect(avatar.left, lessThan(notify.left));
    expect(notify.right, lessThan(logo.left));
    expect(coins.center.dx, lessThan(logo.center.dx));
    expect(logo.center.dx, closeTo(screen.width / 2, 48));
    expect(settings.left, greaterThan(logo.right));
    expect(menu.left, greaterThan(settings.left));
    expect(menu.center.dx, greaterThan(screen.width * 0.72));
  });
}
