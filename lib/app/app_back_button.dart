import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import 'app_router.dart';

/// Standard back arrow for every pushed page.
///
/// Hidden on root destinations (shell tabs, login, splash, onboarding).
class AppBackButton extends StatelessWidget {
  const AppBackButton({this.onPressed, super.key});

  final VoidCallback? onPressed;

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
      onPressed: onPressed ?? () => AppNavigation.back(context),
    );
  }
}
