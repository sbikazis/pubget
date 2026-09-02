import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_router.dart';
import 'package:pubget/app/app_shell_tab.dart';

void main() {
  test('shell tabs map to the four primary destinations', () {
    expect(AppShellTab.discover.path, '/home');
    expect(AppShellTab.groups.path, '/groups');
    expect(AppShellTab.private.path, '/private');
    expect(AppShellTab.edits.path, '/edits');
    expect(AppRouter.shellPaths, AppShellTab.values.map((tab) => tab.path).toSet());
  });

  test('fromPath recovers the selected tab and defaults to Discover', () {
    expect(AppShellTabX.fromPath('/groups'), AppShellTab.groups);
    expect(AppShellTabX.fromPath('/private'), AppShellTab.private);
    expect(AppShellTabX.fromPath('/edits'), AppShellTab.edits);
    expect(AppShellTabX.fromPath('/home'), AppShellTab.discover);
    expect(AppShellTabX.fromPath('/unknown'), AppShellTab.discover);
  });
}
