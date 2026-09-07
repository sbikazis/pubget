import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
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
            child: const CustomPaint(
              size: Size(22, 22),
              painter: _LuxuryGearPainter(),
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
      child: const CustomPaint(painter: PubgetCoinPainter()),
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
                const PubgetCoinIcon(size: 34),
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

class _LuxuryGearPainter extends CustomPainter {
  const _LuxuryGearPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..color = const Color(0xFF1B1028)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final outer = Path();
    const teeth = 8;
    for (var i = 0; i < teeth; i++) {
      final angle = (i / teeth) * 6.28318530718 - 0.2;
      final next = ((i + 0.45) / teeth) * 6.28318530718 - 0.2;
      final valley = ((i + 0.72) / teeth) * 6.28318530718 - 0.2;
      final outerR = size.shortestSide * 0.46;
      final innerR = size.shortestSide * 0.34;
      final p1 = center + Offset.fromDirection(angle, innerR);
      final p2 = center + Offset.fromDirection(angle + 0.08, outerR);
      final p3 = center + Offset.fromDirection(next, outerR);
      final p4 = center + Offset.fromDirection(valley, innerR);
      if (i == 0) {
        outer.moveTo(p1.dx, p1.dy);
      }
      outer.lineTo(p2.dx, p2.dy);
      outer.lineTo(p3.dx, p3.dy);
      outer.lineTo(p4.dx, p4.dy);
    }
    outer.close();
    canvas.drawPath(outer, stroke);
    canvas.drawCircle(center, size.shortestSide * 0.16, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
