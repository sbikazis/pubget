import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Isolated feed action control — bounce + optional filled identity color.
/// Parent should pass already-resolved [active]/[label] so this widget never
/// watches a broad provider (avoids rebuilding the video tree).
class EditActionButton extends StatefulWidget {
  const EditActionButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.active = false,
    this.activeColor = AppColors.royalPurpleLight,
    this.animateCount = false,
    super.key,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool active;
  final Color activeColor;
  final bool animateCount;

  @override
  State<EditActionButton> createState() => _EditActionButtonState();
}

class _EditActionButtonState extends State<EditActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.28), weight: 45),
    TweenSequenceItem(tween: Tween(begin: 1.28, end: 0.92), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 0.92, end: 1), weight: 30),
  ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant EditActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active || oldWidget.label != widget.label) {
      _bounce.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    _bounce.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? widget.activeColor : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              onPressed: _handleTap,
              tooltip: widget.semanticLabel,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.22),
                foregroundColor: color,
                minimumSize: const Size(48, 48),
              ),
              icon: PhosphorIcon(
                widget.active ? widget.activeIcon : widget.icon,
                size: 28,
                color: color,
              ),
            ),
            AnimatedSwitcher(
              duration: widget.animateCount
                  ? const Duration(milliseconds: 220)
                  : Duration.zero,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.35),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                widget.label,
                key: ValueKey<String>(widget.label),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: const <Shadow>[
                    Shadow(blurRadius: 6, color: Colors.black54),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Canonical Phosphor pairings for the Edits rail.
abstract final class EditActionIcons {
  static const like = PhosphorIconsRegular.heart;
  static const likeActive = PhosphorIconsFill.heart;
  static const comment = PhosphorIconsRegular.chatCircle;
  static const share = PhosphorIconsRegular.shareNetwork;
  static const save = PhosphorIconsRegular.bookmarkSimple;
  static const saveActive = PhosphorIconsFill.bookmarkSimple;
  static const respect = PhosphorIconsRegular.crownSimple;
  static const respectActive = PhosphorIconsFill.crownSimple;
  static const repost = PhosphorIconsRegular.arrowsClockwise;
  static const more = PhosphorIconsRegular.dotsThreeOutline;
  static const play = PhosphorIconsFill.play;
  static const pause = PhosphorIconsFill.pause;
}
