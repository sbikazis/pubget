import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/widgets/pubget_design_system.dart';
import '../../../l10n/group_copy.dart';
import '../../../models/group_models.dart';

class Step3Rules extends StatefulWidget {
  const Step3Rules({
    required this.joinPolicy,
    required this.onJoinPolicyChanged,
    required this.maxMembersController,
    required this.rulesControllers,
    required this.onRulesChanged,
    required this.onAddRule,
    required this.onRemoveRule,
    required this.onReorderRules,
    required this.maxMembersLimit,
    super.key,
  });

  final JoinPolicy joinPolicy;
  final ValueChanged<JoinPolicy> onJoinPolicyChanged;
  final TextEditingController maxMembersController;
  final List<TextEditingController> rulesControllers;
  final VoidCallback onRulesChanged;
  final VoidCallback onAddRule;
  final void Function(int index) onRemoveRule;
  final void Function(int oldIndex, int newIndex) onReorderRules;
  final int maxMembersLimit;

  @override
  State<Step3Rules> createState() => _Step3RulesState();
}

class _Step3RulesState extends State<Step3Rules> {
  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            copy.rulesAndPrivacy,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            copy.rulesAndPrivacyHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: copy.joinPolicySection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _JoinPolicyTile(
                  policy: JoinPolicy.inviteOnly,
                  selected: widget.joinPolicy == JoinPolicy.inviteOnly,
                  onTap: () => widget.onJoinPolicyChanged(JoinPolicy.inviteOnly),
                  icon: Icons.lock_outline,
                  title: copy.joinInviteOnly,
                  subtitle: copy.joinInviteOnlyHint,
                ),
                const SizedBox(height: AppSpacing.sm),
                _JoinPolicyTile(
                  policy: JoinPolicy.approval,
                  selected: widget.joinPolicy == JoinPolicy.approval,
                  onTap: () => widget.onJoinPolicyChanged(JoinPolicy.approval),
                  icon: Icons.how_to_reg_outlined,
                  title: copy.joinApproval,
                  subtitle: copy.joinApprovalHint,
                ),
                const SizedBox(height: AppSpacing.sm),
                _JoinPolicyTile(
                  policy: JoinPolicy.open,
                  selected: widget.joinPolicy == JoinPolicy.open,
                  onTap: () => widget.onJoinPolicyChanged(JoinPolicy.open),
                  icon: Icons.lock_open_outlined,
                  title: copy.joinOpen,
                  subtitle: copy.joinOpenHint,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: copy.memberLimitSection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                PubgetTextField(
                  key: const Key('group-create-max-members'),
                  controller: widget.maxMembersController,
                  label: copy.maxMembersLabel,
                  keyboardType: TextInputType.number,
                  helperText: copy.maxMembersHint(widget.maxMembersLimit),
                  onChanged: (_) => widget.onRulesChanged(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  copy.maxMembersRange(2, widget.maxMembersLimit),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: copy.contentRulesSection,
            child: Column(
              children: <Widget>[
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.rulesControllers.length,
                  onReorder: widget.onReorderRules,
                  itemBuilder: (context, index) => Padding(
                    key: ValueKey(widget.rulesControllers[index]),
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: PubgetTextField(
                            key: Key('group-create-rule-$index'),
                            controller: widget.rulesControllers[index],
                            label: '${copy.rules} ${index + 1}',
                            onChanged: (_) => widget.onRulesChanged(),
                          ),
                        ),
                        PubgetIconButton(
                          icon: Icons.delete_outline,
                          tooltip: copy.removeRule,
                          onPressed: widget.rulesControllers.length == 1
                              ? null
                              : () => widget.onRemoveRule(index),
                        ),
                      ],
                    ),
                  ),
                ),
                PubgetTextButton(
                  key: const Key('group-create-add-rule'),
                  onPressed: widget.onAddRule,
                  semanticLabel: copy.addRule,
                  child: Text(copy.addRule),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinPolicyTile extends StatelessWidget {
  const _JoinPolicyTile({
    required this.policy,
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final JoinPolicy policy;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1A0F2E) : const Color(0xFFF5F0FA);
    final borderColor = selected ? AppColors.gold : AppColors.gold.withValues(alpha: 0.3);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: surfaceColor,
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppColors.gold.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                ),
                child: Icon(
                  icon,
                  color: selected ? AppColors.gold : Colors.white70,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: selected ? AppColors.gold : Colors.white,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                          ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.gold,
                  size: 24,
                ),
            ],
          ),
        ),
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