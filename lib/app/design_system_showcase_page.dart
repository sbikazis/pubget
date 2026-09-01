import 'package:flutter/material.dart';

import '../core/loading/loading_state.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/pubget_avatar.dart';
import '../core/widgets/pubget_badge.dart';
import '../core/widgets/pubget_bottom_sheet.dart';
import '../core/widgets/pubget_buttons.dart';
import '../core/widgets/pubget_card.dart';
import '../core/widgets/pubget_dialogs.dart';
import '../core/widgets/pubget_inputs.dart';
import '../core/widgets/pubget_skeleton.dart';
import '../core/widgets/pubget_snackbars.dart';
import '../core/widgets/pubget_states.dart';
import '../core/widgets/pubget_tooltip.dart';

class DesignSystemShowcasePage extends StatefulWidget {
  const DesignSystemShowcasePage({super.key});

  @override
  State<DesignSystemShowcasePage> createState() =>
      _DesignSystemShowcasePageState();
}

class _DesignSystemShowcasePageState extends State<DesignSystemShowcasePage> {
  bool _darkMode = false;
  bool _rightToLeft = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _darkMode ? AppTheme.dark : AppTheme.light,
      child: Directionality(
        textDirection: _rightToLeft ? TextDirection.rtl : TextDirection.ltr,
        child: Builder(
          builder: (context) => Scaffold(
            key: const Key('showcase-root'),
            appBar: AppBar(
              title: const Text('Pubget Design System'),
              leading: Navigator.of(context).canPop()
                  ? const BackButton()
                  : null,
            ),
            body: SelectionArea(
              child: ListView(
                key: const Key('showcase-content'),
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: <Widget>[
                  _ShowcaseHero(
                    darkMode: _darkMode,
                    rightToLeft: _rightToLeft,
                    onDarkModeChanged: (value) =>
                        setState(() => _darkMode = value),
                    onDirectionChanged: (value) =>
                        setState(() => _rightToLeft = value),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _ShowcaseSection(
                    title: 'Typography / الطباعة',
                    description:
                        'A shared hierarchy tested with English and العربية.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Premium social stories',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'قصص اجتماعية بهوية أنمي راقية',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Readable body copy stays calm in both directions '
                          'and across light and dark surfaces.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  _ShowcaseSection(
                    title: 'Buttons',
                    description:
                        'Primary, secondary, text, icon, loading, and disabled.',
                    child: Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        PubgetPrimaryButton(
                          onPressed: () {},
                          semanticLabel: 'Primary showcase action',
                          leadingIcon: Icons.auto_awesome,
                          child: const Text('Primary'),
                        ),
                        PubgetSecondaryButton(
                          onPressed: () {},
                          semanticLabel: 'Secondary showcase action',
                          child: const Text('Secondary'),
                        ),
                        PubgetTextButton(
                          onPressed: () {},
                          semanticLabel: 'Text showcase action',
                          child: const Text('Text action'),
                        ),
                        const PubgetPrimaryButton(
                          onPressed: null,
                          semanticLabel: 'Disabled showcase action',
                          child: Text('Disabled'),
                        ),
                        PubgetSecondaryButton(
                          onPressed: () {},
                          semanticLabel: 'Loading showcase action',
                          loading: true,
                          child: const Text('Loading'),
                        ),
                        PubgetIconButton(
                          icon: Icons.favorite_border,
                          tooltip: 'Favorite',
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  _ShowcaseSection(
                    title: 'Inputs',
                    description:
                        'Default, multiline, search, error, and disabled states.',
                    child: Column(
                      children: <Widget>[
                        const PubgetTextField(
                          label: 'Display name',
                          hint: 'How should people see you?',
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const PubgetTextArea(
                          label: 'About you',
                          hint: 'اكتب نبذة قصيرة',
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        PubgetSearchField(
                          controller: _searchController,
                          hint: 'Search / بحث',
                          onClear: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const PubgetTextField(
                          label: 'Username',
                          errorText: 'This name is already taken.',
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const PubgetTextField(
                          label: 'Disabled',
                          hint: 'Unavailable',
                          enabled: false,
                        ),
                      ],
                    ),
                  ),
                  _ShowcaseSection(
                    title: 'Cards, avatars & badges',
                    description:
                        'Composable identity pieces without rank or premium logic.',
                    child: PubgetCard(
                      onTap: () {},
                      child: Row(
                        children: <Widget>[
                          const PubgetAvatar(name: 'زكرياء'),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Zis / زكرياء',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Community host',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const PubgetBadge(
                            label: 'Gold',
                            icon: Icons.workspace_premium_outlined,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _ShowcaseSection(
                    title: 'Overlays & feedback',
                    description:
                        'Unified sheets, dialogs, snackbars, and tooltips.',
                    child: Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: <Widget>[
                        PubgetSecondaryButton(
                          onPressed: () => PubgetBottomSheet.show<void>(
                            context,
                            title: 'Bottom sheet',
                            child: const Text(
                              'A reusable surface that follows the active '
                              'theme and reading direction.',
                            ),
                          ),
                          semanticLabel: 'Open bottom sheet',
                          child: const Text('Bottom sheet'),
                        ),
                        PubgetSecondaryButton(
                          onPressed: () => PubgetConfirmationDialog.show(
                            context,
                            title: 'Confirm action',
                            message:
                                'This showcase action does not change data.',
                            confirmLabel: 'Confirm',
                            cancelLabel: 'Cancel',
                          ),
                          semanticLabel: 'Open confirmation dialog',
                          child: const Text('Confirmation'),
                        ),
                        PubgetSecondaryButton(
                          onPressed: () => PubgetAlertDialog.show(
                            context,
                            title: 'Heads up',
                            message: 'This is a consistent alert presentation.',
                            closeLabel: 'Close',
                            icon: Icons.notifications_none,
                          ),
                          semanticLabel: 'Open alert dialog',
                          child: const Text('Alert'),
                        ),
                        PubgetTextButton(
                          onPressed: () => PubgetSnackbars.showSuccess(
                            context,
                            'Saved successfully.',
                          ),
                          semanticLabel: 'Show success message',
                          child: const Text('Success snackbar'),
                        ),
                        PubgetTextButton(
                          onPressed: () => PubgetSnackbars.showError(
                            context,
                            'Could not complete the action.',
                          ),
                          semanticLabel: 'Show error message',
                          child: const Text('Error snackbar'),
                        ),
                        PubgetTooltip(
                          message: 'Helpful context without visual clutter',
                          child: Icon(
                            Icons.help_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ShowcaseSection(
                    title: 'Skeletons',
                    description:
                        'Purposeful loading feedback built with Flutter only.',
                    child: Column(
                      children: <Widget>[
                        const PubgetSkeletonListTile(),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: <Widget>[
                            const PubgetSkeleton.circle(size: 44),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: PubgetSkeleton(
                                width: double.infinity,
                                height: 44,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _ShowcaseSection(
                    title: 'LoadingState mapping',
                    description:
                        'Providers can map shared states directly to consistent UI.',
                    child: Column(
                      children: <Widget>[
                        SizedBox(
                          height: 260,
                          child: PubgetLoadingStateView(
                            state: LoadingState.empty,
                            empty: const PubgetEmptyState(
                              title: 'No stories yet',
                              message: 'ابدأ قصة جديدة عندما تكون مستعدًا.',
                              icon: Icons.auto_stories_outlined,
                            ),
                            child: const SizedBox.shrink(),
                          ),
                        ),
                        const Divider(),
                        SizedBox(
                          height: 280,
                          child: PubgetLoadingStateView(
                            state: LoadingState.error,
                            child: const SizedBox.shrink(),
                            onRetry: () {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShowcaseHero extends StatelessWidget {
  const _ShowcaseHero({
    required this.darkMode,
    required this.rightToLeft,
    required this.onDarkModeChanged,
    required this.onDirectionChanged,
  });

  final bool darkMode;
  final bool rightToLeft;
  final ValueChanged<bool> onDarkModeChanged;
  final ValueChanged<bool> onDirectionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: <Color>[
            scheme.primaryContainer,
            scheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Anime energy, premium restraint.',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'A shared visual language for every future Pubget screen.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                SizedBox(
                  width: 220,
                  child: SwitchListTile(
                    key: const Key('showcase-theme-switch'),
                    value: darkMode,
                    contentPadding: EdgeInsets.zero,
                    title: Text(darkMode ? 'Dark mode' : 'Light mode'),
                    secondary: Icon(
                      darkMode ? Icons.dark_mode : Icons.light_mode,
                    ),
                    onChanged: onDarkModeChanged,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: SwitchListTile(
                    key: const Key('showcase-direction-switch'),
                    value: rightToLeft,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      rightToLeft ? 'RTL / العربية' : 'LTR / English',
                    ),
                    secondary: const Icon(Icons.format_textdirection_r_to_l),
                    onChanged: onDirectionChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShowcaseSection extends StatelessWidget {
  const _ShowcaseSection({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(description, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}
