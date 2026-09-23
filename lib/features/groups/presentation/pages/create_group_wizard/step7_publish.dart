import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/widgets/pubget_design_system.dart';
import '../../../l10n/group_copy.dart';
import '../../../models/group_models.dart';

class Step7Publish extends StatelessWidget {
  const Step7Publish({
    required this.onPublish,
    required this.isSubmitting,
    required this.canPublish,
    required this.name,
    required this.type,
    super.key,
  });

  final Future<void> Function() onPublish;
  final bool isSubmitting;
  final bool canPublish;
  final String name;
  final GroupType? type;

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            copy.finalStep,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            copy.finalStepHint(name),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: copy.readyToPublish,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _CheckItem(copy.checkName, name.trim().isNotEmpty),
                _CheckItem(copy.checkImage, true), // validated earlier
                _CheckItem(copy.checkType, type != null),
                _CheckItem(copy.checkRules, true),
                _CheckItem(copy.checkPermissions, true),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PubgetPrimaryButton(
            key: const Key('group-create-final-publish'),
            onPressed: canPublish && !isSubmitting ? onPublish : null,
            semanticLabel: copy.publishGroup,
            loading: isSubmitting,
            child: Text(isSubmitting ? copy.publishing : copy.publishGroup),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!canPublish)
            Text(
              copy.fillRequiredFields,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.royalPurple.withValues(alpha: 0.35),
            const Color(0xFF160B24),
          ],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem(this.label, this.passed);

  final String label;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Icon(
            passed ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: passed ? AppColors.gold : Colors.white30,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: passed ? Colors.white : Colors.white54,
                ),
          ),
        ],
      ),
    );
  }
}