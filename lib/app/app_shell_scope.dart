import 'package:flutter/material.dart';

/// Lets tab pages open the [AppShell] drawer without nested-Scaffold lookup.
final class AppShellScope extends InheritedWidget {
  const AppShellScope({
    required this.openDrawer,
    required super.child,
    super.key,
  });

  final VoidCallback openDrawer;

  static AppShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellScope>();
  }

  static AppShellScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'AppShellScope.of() called outside AppShell');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      openDrawer != oldWidget.openDrawer;
}

class AppShellMenuButton extends StatelessWidget {
  const AppShellMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('app-shell-menu'),
      icon: const Icon(Icons.menu),
      tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      onPressed: () => AppShellScope.maybeOf(context)?.openDrawer(),
    );
  }
}
