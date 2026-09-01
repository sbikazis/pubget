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
    this.compactBrand = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final Widget? footer;
  final bool compactBrand;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
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
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.sm,
                      AppSpacing.xl,
                      AppSpacing.xl,
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
                          const SizedBox(height: AppSpacing.xl),
                          _AuthGlassPanel(child: child),
                          if (footer != null) ...[
                            const SizedBox(height: AppSpacing.lg),
                            footer!,
                          ],
                        ],
                      ),
                    ),
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

class _AuthGlassPanel extends StatelessWidget {
  const _AuthGlassPanel({required this.child});

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
            AppColors.gold.withValues(alpha: 0.55),
            AppColors.royalPurple.withValues(alpha: 0.35),
          ],
        ),
        boxShadow: AppShadows.lightCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.lightSurface.withValues(alpha: 0.94),
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
