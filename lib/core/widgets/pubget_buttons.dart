import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class PubgetPrimaryButton extends StatelessWidget {
  const PubgetPrimaryButton({
    required this.onPressed,
    required this.child,
    required this.semanticLabel,
    this.loading = false,
    this.leadingIcon,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final String semanticLabel;
  final bool loading;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onPrimary;
    return Semantics(
      button: true,
      enabled: !loading && onPressed != null,
      liveRegion: loading,
      label: semanticLabel,
      onTap: loading ? null : onPressed,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: _ButtonContent(
          loading: loading,
          color: foreground,
          leadingIcon: leadingIcon,
          child: child,
        ),
      ),
    );
  }
}

class PubgetSecondaryButton extends StatelessWidget {
  const PubgetSecondaryButton({
    required this.onPressed,
    required this.child,
    required this.semanticLabel,
    this.loading = false,
    this.leadingIcon,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final String semanticLabel;
  final bool loading;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      enabled: !loading && onPressed != null,
      liveRegion: loading,
      label: semanticLabel,
      onTap: loading ? null : onPressed,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        child: _ButtonContent(
          loading: loading,
          color: foreground,
          leadingIcon: leadingIcon,
          child: child,
        ),
      ),
    );
  }
}

class PubgetTextButton extends StatelessWidget {
  const PubgetTextButton({
    required this.onPressed,
    required this.child,
    required this.semanticLabel,
    this.loading = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final String semanticLabel;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      enabled: !loading && onPressed != null,
      liveRegion: loading,
      label: semanticLabel,
      onTap: loading ? null : onPressed,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        child: _ButtonContent(
          loading: loading,
          color: foreground,
          child: child,
        ),
      ),
    );
  }
}

class PubgetIconButton extends StatelessWidget {
  const PubgetIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.loading = false,
    this.iconSize,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool loading;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: loading ? null : onPressed,
      tooltip: tooltip,
      iconSize: iconSize,
      icon: loading
          ? SizedBox.square(
              dimension: iconSize ?? 24,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: button,
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.loading,
    required this.color,
    required this.child,
    this.leadingIcon,
  });

  final bool loading;
  final Color color;
  final Widget child;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: 18),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: child),
      ],
    );
  }
}
