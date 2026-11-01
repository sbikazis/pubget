import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/widgets/pubget_design_system.dart';
import '../../../l10n/group_copy.dart';

class Step4Customization extends StatefulWidget {
  const Step4Customization({
    required this.welcomeMessageController,
    required this.chatBackgroundController,
    required this.onChanged,
    super.key,
  });

  final TextEditingController welcomeMessageController;
  final TextEditingController chatBackgroundController;
  final VoidCallback onChanged;

  @override
  State<Step4Customization> createState() => _Step4CustomizationState();
}

class _Step4CustomizationState extends State<Step4Customization> {
  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            copy.customizationTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            copy.customizationHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: copy.welcomeMessageSection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                PubgetTextArea(
                  key: const Key('group-create-welcome-message'),
                  controller: widget.welcomeMessageController,
                  label: copy.welcomeMessageLabel,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  onChanged: (_) => widget.onChanged(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  copy.welcomeMessageHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: copy.chatBackgroundSection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                PubgetTextField(
                  key: const Key('group-create-chat-background'),
                  controller: widget.chatBackgroundController,
                  label: copy.chatBackgroundLabel,
                  helperText: copy.chatBackgroundHint,
                  onChanged: (_) => widget.onChanged(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  copy.chatBackgroundHintDetail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
              ],
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