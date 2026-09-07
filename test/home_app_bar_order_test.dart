import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_shell_scope.dart';
import 'package:pubget/features/home/screens/home_page.dart';

void main() {
  testWidgets('RTL home bar puts hamburger at start and centers the logo', (
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

    final menu = tester.getRect(find.byKey(const Key('app-shell-menu')));
    final logo = tester.getRect(find.byKey(const Key('home-logo')));
    final screen = tester.getSize(find.byType(Scaffold));

    expect(menu.right, greaterThan(logo.right));
    expect(menu.center.dx, greaterThan(screen.width * 0.72));
    expect(logo.center.dx, closeTo(screen.width / 2, 48));

    final coins = tester.getRect(find.byKey(const Key('home-coins')));
    final avatar = tester.getRect(find.byKey(const Key('home-avatar')));
    expect(coins.left, lessThan(avatar.left));
  });
}
