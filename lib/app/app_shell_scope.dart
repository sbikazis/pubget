import 'package:flutter/material.dart';

import '../../../app/app_shell_tab.dart';

final class AppShellScope extends InheritedWidget {
  const AppShellScope({
    required this.openDrawer,
    required this.currentTab,
    required super.child,
    super.key,
  });

  final VoidCallback openDrawer;
  final AppShellTab currentTab;

  static AppShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellScope>();
  }

  static AppShellScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'AppShellScope.of() called outside AppShell');
    return scope!;
  }

  bool get isEditsVisible => currentTab == AppShellTab.edits;

  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      openDrawer != oldWidget.openDrawer || currentTab != oldWidget.currentTab;
}

class AppShellMenuButton extends StatelessWidget {
  const AppShellMenuButton({this.size, super.key});

  /// When set, the control is boxed to [size]×[size] with a matching icon.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final boxed = size;
    return IconButton(
      key: const Key('app-shell-menu'),
      icon: const Icon(Icons.menu),
      iconSize: boxed == null ? null : boxed * 0.64,
      tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      visualDensity: boxed == null ? null : VisualDensity.compact,
      padding: boxed == null ? null : EdgeInsets.zero,
      constraints: boxed == null
          ? null
          : BoxConstraints.tightFor(width: boxed, height: boxed),
      onPressed: () => AppShellScope.maybeOf(context)?.openDrawer(),
    );
  }
}
