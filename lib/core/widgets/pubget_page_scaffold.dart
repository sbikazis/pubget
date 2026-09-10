import 'package:flutter/material.dart';

import '../../app/app_back_button.dart';
import '../l10n/app_strings.dart';
import '../navigation/pubget_dismiss.dart';

/// Standard page chrome that always exposes a single-step back when possible.
///
/// Use for **new** screens. Prefer routed navigation via [AppNavigation.go];
/// set [localNavigator] when the page was opened with `Navigator.push`.
class PubgetPageScaffold extends StatelessWidget {
  const PubgetPageScaffold({
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.localNavigator = false,
    this.bottomNavigationBar,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor,
    super.key,
  });

  final Widget body;
  final Widget? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool extendBodyBehindAppBar;
  final Color? backgroundColor;

  /// When true, back pops the local [Navigator] (pushed routes).
  /// When false, uses [AppBackButton] / app route stack.
  final bool localNavigator;

  @override
  Widget build(BuildContext context) {
    final leading = localNavigator
        ? IconButton(
            key: const Key('app-back'),
            tooltip: AppStrings.of(context).back,
            icon: const BackButtonIcon(),
            onPressed: () => Navigator.of(context).maybePop(),
          )
        : AppBackButton.maybeOf(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: leading,
        title: title,
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// Documents the forever dismiss rule next to the sheet API.
@immutable
final class PubgetDismissPolicy {
  const PubgetDismissPolicy._();

  /// Bottom sheets: drag + backdrop + handle (+ optional close in chrome).
  static const sheetMinDismissPaths = 2;

  /// Pages: AppBar back + hardware back (both call [PubgetDismiss.popLayer]).
  static const pageMinDismissPaths = 2;
}
