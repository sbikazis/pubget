import 'package:flutter/material.dart';

import '../branding/pubget_logo.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'pubget_tooltip.dart';

/// Settings control: user-supplied Japanese emblem.
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
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.goldSheen.withValues(alpha: 0.78),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.royalPurple.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                PubgetLogo.settingsAsset,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.royalDusk,
                  child: Icon(
                    Icons.settings_outlined,
                    color: AppColors.goldPale,
                    size: 22,
                  ),
                ),
              ),
            ),
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
          customBorder: const CircleBorder(),
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
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
                const CustomPaint(
                  size: Size(22, 22),
                  painter: _LuxuryBellPainter(),
                ),
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

/// Japanese-inspired currency mark: dragon + katana with a gloss streak.
/// Use this everywhere a coin amount is shown.
class PubgetCoinIcon extends StatelessWidget {
  const PubgetCoinIcon({this.size = 22, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        PubgetLogo.coinAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => CustomPaint(
          size: Size(size, size),
          painter: const PubgetCoinPainter(),
        ),
      ),
    );
  }
}

class PubgetCoinAmount extends StatelessWidget {
  const PubgetCoinAmount({
    required this.amount,
    this.size = 18,
    this.color,
    super.key,
  });

  final int amount;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PubgetCoinIcon(size: size),
        SizedBox(width: size * 0.28),
        Text(
          '$amount',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color ?? AppColors.goldPale,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// Japanese-style coin plate: gold disc, dragon arc, katana.
class PubgetKatanaCoinChip extends StatelessWidget {
  const PubgetKatanaCoinChip({
    required this.balance,
    required this.tooltip,
    required this.onPressed,
    this.compact = false,
    super.key,
  });

  final int balance;
  final String tooltip;
  final VoidCallback onPressed;
  final bool compact;

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
            padding: EdgeInsetsDirectional.only(
              start: compact ? 3 : 4,
              end: compact ? AppSpacing.sm : AppSpacing.md,
              top: compact ? 3 : 4,
              bottom: compact ? 3 : 4,
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
                PubgetCoinIcon(size: compact ? 22 : 34),
                SizedBox(width: compact ? 6 : AppSpacing.sm),
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

class _LuxuryBellPainter extends CustomPainter {
  const _LuxuryBellPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFF3A2300)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    final bell = Path()
      ..moveTo(w * 0.32, h * 0.38)
      ..quadraticBezierTo(w * 0.32, h * 0.16, w * 0.50, h * 0.14)
      ..quadraticBezierTo(w * 0.68, h * 0.16, w * 0.68, h * 0.38)
      ..quadraticBezierTo(w * 0.78, h * 0.62, w * 0.84, h * 0.72)
      ..lineTo(w * 0.16, h * 0.72)
      ..quadraticBezierTo(w * 0.22, h * 0.62, w * 0.32, h * 0.38)
      ..close();
    canvas.drawPath(bell, stroke);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.72),
        width: w * 0.42,
        height: h * 0.22,
      ),
      0.15,
      2.84,
      false,
      stroke,
    );
    canvas.drawCircle(Offset(w * 0.50, h * 0.88), 1.15, stroke);
    canvas.drawLine(
      Offset(w * 0.50, h * 0.10),
      Offset(w * 0.50, h * 0.16),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PubgetCoinPainter extends CustomPainter {
  const PubgetCoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final disc = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[
          Color(0xFFFFF8D0),
          Color(0xFFFFF3B0),
          AppColors.goldLight,
          AppColors.gold,
          AppColors.goldDark,
        ],
        stops: <double>[0, 0.22, 0.48, 0.78, 1],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, radius, disc);
    canvas.drawCircle(
      center,
      radius * 0.88,
      Paint()
        ..color = const Color(0xFF5A3A08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    final dragon = Paint()
      ..color = AppColors.royalPurpleDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round;
    final body = Path()
      ..moveTo(size.width * 0.22, size.height * 0.70)
      ..cubicTo(
        size.width * 0.06,
        size.height * 0.42,
        size.width * 0.28,
        size.height * 0.10,
        size.width * 0.52,
        size.height * 0.22,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.34,
        size.width * 0.70,
        size.height * 0.62,
        size.width * 0.78,
        size.height * 0.52,
      );
    canvas.drawPath(body, dragon);
    canvas.drawCircle(
      Offset(size.width * 0.80, size.height * 0.48),
      1.5,
      Paint()..color = AppColors.royalPurpleDark,
    );
    canvas.drawLine(
      Offset(size.width * 0.78, size.height * 0.44),
      Offset(size.width * 0.86, size.height * 0.38),
      dragon,
    );

    final blade = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFFF8F3E4), Color(0xFF8A6A20)],
      ).createShader(Offset.zero & size)
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.78),
      Offset(size.width * 0.84, size.height * 0.30),
      blade,
    );
    canvas.drawLine(
      Offset(size.width * 0.20, size.height * 0.74),
      Offset(size.width * 0.28, size.height * 0.82),
      Paint()
        ..color = AppColors.royalPurple
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );

    final gloss = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.72),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.24),
      Offset(size.width * 0.62, size.height * 0.16),
      gloss,
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
