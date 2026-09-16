import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Modal bottom sheets for Pubget.
///
/// **Forever contract (do not weaken):**
/// - [enableDrag] = true (swipe down to close)
/// - [isDismissible] = true (tap barrier to close)
/// - [showDragHandle] = true (visible drag affordance)
/// - Prefer an explicit close control when the sheet has a title row
///
/// Use [PubgetBottomSheet.present] for custom builders and [show] for the
/// titled chrome. Do not call raw `showModalBottomSheet` in feature code.
class PubgetBottomSheet extends StatelessWidget {
  const PubgetBottomSheet({
    required this.child,
    this.title,
    this.actions,
    this.showClose = true,
    super.key,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool showClose;

  /// Titled sheet with drag handle + optional close (second dismiss path).
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    List<Widget>? actions,
    bool isScrollControlled = false,
    bool showClose = true,
  }) {
    return present<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      builder: (_) => PubgetBottomSheet(
        title: title,
        actions: actions,
        showClose: showClose,
        child: child,
      ),
    );
  }

  /// Low-level presenter — **always** drag + barrier + handle.
  ///
  /// Call this instead of `showModalBottomSheet` everywhere.
  static Future<T?> present<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = false,
    Color? backgroundColor,
    Color? barrierColor,
    BoxConstraints? constraints,
    ShapeBorder? shape,
    bool useSafeArea = true,
    AnimationController? transitionAnimationController,
    bool useRootNavigator = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      // Forever dismiss contract — do not expose knobs that disable these.
      enableDrag: true,
      isDismissible: true,
      showDragHandle: true,
      backgroundColor: backgroundColor,
      barrierColor: barrierColor,
      constraints: constraints,
      shape: shape,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      transitionAnimationController: transitionAnimationController,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppStrings.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (title != null || showClose)
              Row(
                children: <Widget>[
                  if (title != null)
                    Expanded(
                      child: Text(title!, style: theme.textTheme.titleLarge),
                    )
                  else
                    const Spacer(),
                  if (showClose)
                    IconButton(
                      key: const Key('sheet-close'),
                      tooltip: copy.close,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                ],
              ),
            if (title != null) const SizedBox(height: AppSpacing.md),
            Flexible(fit: FlexFit.loose, child: child),
            if (actions != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.end,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PubgetDraggableSheet extends StatelessWidget {
  const PubgetDraggableSheet({
    required this.builder,
    this.initialChildSize = 0.45,
    this.minChildSize = 0.25,
    this.maxChildSize = 0.9,
    super.key,
  });

  final ScrollableWidgetBuilder builder;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      expand: false,
      builder: builder,
    );
  }
}

class PubgetSheetHandle extends StatelessWidget {
  const PubgetSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outline,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}
