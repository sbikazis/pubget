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
      style: boxed == null
          ? null
          : IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: Size(boxed, boxed),
              maximumSize: Size(boxed, boxed),
              padding: EdgeInsets.zero,
            ),
      onPressed: () => AppShellScope.maybeOf(context)?.openDrawer(),
    );
  }
}
