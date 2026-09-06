import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'pubget_tooltip.dart';

/// Settings control: silver → royal purple metallic wash.
class PubgetLuxurySettingsButton extends StatelessWidget {
  const PubgetLuxurySettingsButton({
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PubgetTooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          key: const Key('home-settings'),
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFFF4F1F8),
                  Color(0xFFB7A9C9),
                  AppColors.royalPurpleLight,
                  AppColors.royalPurple,
                ],
              ),
            ),
            child: const Icon(Icons.settings_rounded, color: Color(0xFF1B1028)),
          ),
        ),
      ),
    );
  }
}

/// Notifications control: one-off luxury gold faceted bell.
class PubgetLuxuryNotifyButton extends StatelessWidget {
  const PubgetLuxuryNotifyButton({
    required this.tooltip,
    required this.onPressed,
    this.badge = 0,
    super.key,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return PubgetTooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          key: const Key('home-notifications'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            width: 44,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFFFFF1A8),
                  AppColors.goldLight,
                  AppColors.gold,
                  AppColors.goldDark,
                ],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.42),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: const Color(0xFFFFF6C8)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                const Icon(Icons.notifications_active_rounded, color: Color(0xFF3A2300)),
                if (badge > 0)
                  PositionedDirectional(
                    top: 4,
                    end: 5,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFB42318),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Japanese-style coin plate: gold disc, dragon arc, katana.
class PubgetKatanaCoinChip extends StatelessWidget {
  const PubgetKatanaCoinChip({
    required this.balance,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final int balance;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('home-coins'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: const EdgeInsetsDirectional.only(
              start: 4,
              end: AppSpacing.md,
              top: 4,
              bottom: 4,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: <Color>[
                  Color(0xFF3A2460),
                  Color(0xFF1A1028),
                ],
              ),
              border: Border.all(color: AppColors.goldSheen.withValues(alpha: 0.7)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.28),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _KatanaCoinDisc(),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$balance',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.goldPale,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KatanaCoinDisc extends StatelessWidget {
  const _KatanaCoinDisc();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: CustomPaint(painter: _KatanaCoinPainter()),
    );
  }
}

class _KatanaCoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final disc = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[
          Color(0xFFFFF3B0),
          AppColors.goldLight,
          AppColors.gold,
          AppColors.goldDark,
        ],
        stops: <double>[0, 0.35, 0.72, 1],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, radius, disc);
    canvas.drawCircle(
      center,
      radius * 0.86,
      Paint()
        ..color = const Color(0xFF5A3A08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    final dragon = Paint()
      ..color = AppColors.royalPurpleDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    final arc = Path()
      ..moveTo(size.width * 0.22, size.height * 0.62)
      ..cubicTo(
        size.width * 0.08,
        size.height * 0.18,
        size.width * 0.78,
        size.height * 0.04,
        size.width * 0.80,
        size.height * 0.48,
      );
    canvas.drawPath(arc, dragon);

    final blade = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFFF8F3E4), Color(0xFF8A6A20)],
      ).createShader(Offset.zero & size)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.78),
      Offset(size.width * 0.84, size.height * 0.28),
      blade,
    );
    canvas.drawCircle(
      Offset(size.width * 0.20, size.height * 0.80),
      1.6,
      Paint()..color = AppColors.royalPurple,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PubgetCenterCreateButton extends StatelessWidget {
  const PubgetCenterCreateButton({
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        key: const Key('shell-create'),
        onTap: onPressed,
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.goldPale,
                AppColors.gold,
                AppColors.royalPurple,
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.royalPurple.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: AppColors.goldPale, width: 2),
          ),
          child: const Icon(Icons.add_rounded, size: 34, color: Colors.white),
        ),
      ),
    );
  }
}
