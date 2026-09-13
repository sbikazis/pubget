import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import 'app_router.dart';

/// Standard back control — always a **single-step** dismiss.
///
/// Prefer [maybeOf] in AppBars. Uses local [Navigator] when a sheet/route was
/// pushed on top; otherwise pops the app route stack. Never exits the app.
class AppBackButton extends StatelessWidget {
  const AppBackButton({this.onPressed, super.key});

  final VoidCallback? onPressed;

  /// Leading control when a single-step back is available; otherwise null
  /// (shell / login roots stay without a back arrow).
  static Widget? maybeOf(BuildContext context) {
    if (!AppNavigation.canPop(context)) return null;
    return const AppBackButton();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('app-back'),
      tooltip: AppStrings.of(context).back,
      icon: const BackButtonIcon(),
      onPressed: onPressed ?? () => AppNavigation.popLayer(context),
    );
  }
}
