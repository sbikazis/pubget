import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class PubgetBottomSheet extends StatelessWidget {
  const PubgetBottomSheet({
    required this.child,
    this.title,
    this.actions,
    super.key,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    List<Widget>? actions,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      showDragHandle: true,
      builder: (_) =>
          PubgetBottomSheet(title: title, actions: actions, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            if (title != null) Text(title!, style: theme.textTheme.titleLarge),
            if (title != null) const SizedBox(height: AppSpacing.lg),
            child,
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
