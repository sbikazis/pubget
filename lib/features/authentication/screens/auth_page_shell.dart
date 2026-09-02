import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../widgets/auth_atmosphere.dart';
import '../widgets/auth_brand_header.dart';

class AuthPageShell extends StatelessWidget {
  const AuthPageShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.leading,
    this.trailing,
    this.footer,
    this.primaryAction,
    this.compactBrand = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final Widget? footer;
  final Widget? primaryAction;
  final bool compactBrand;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.royalNight : AppColors.royalDusk,
      resizeToAvoidBottomInset: true,
      body: AuthAtmosphere(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.sm,
                  0,
                ),
                child: Theme(
                  data: _atmosphereChromeTheme(context),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 48,
                        child: leading ?? const SizedBox.shrink(),
                      ),
                      const Spacer(),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      compactBrand ? AppSpacing.xs : AppSpacing.sm,
                      AppSpacing.xl,
                      AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          AuthBrandHeader(
                            title: title,
                            subtitle: subtitle,
                            compact: compactBrand,
                          ),
                          SizedBox(
                            height: compactBrand
                                ? AppSpacing.lg
                                : AppSpacing.xl,
                          ),
                          _AuthPanel(child: child),
                          if (footer != null) ...[
                            const SizedBox(height: AppSpacing.lg),
                            Theme(
                              data: _atmosphereChromeTheme(context),
                              child: footer!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (primaryAction != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: primaryAction,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

ThemeData _atmosphereChromeTheme(BuildContext context) {
  final theme = Theme.of(context);
  return theme.copyWith(
    colorScheme: theme.colorScheme.copyWith(
      primary: AppColors.goldSheen,
      onSurface: AppColors.goldPale,
    ),
    iconTheme: const IconThemeData(color: AppColors.goldPale),
  );
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.92)
        : AppColors.lightSurface.withValues(alpha: 0.94);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.goldSheen.withValues(alpha: 0.70),
            AppColors.royalPurpleLight.withValues(alpha: 0.45),
          ],
        ),
        boxShadow: isDark ? AppShadows.darkCard : AppShadows.lightCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadius.xl - 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: child,
          ),
        ),
      ),
    );
  }
}

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({
    required this.onPressed,
    this.tooltip = 'Back',
    super.key,
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return PubgetIconButton(
      icon: Icons.arrow_back,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
