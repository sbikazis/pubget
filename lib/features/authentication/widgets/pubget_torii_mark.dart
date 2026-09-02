import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class PubgetToriiMark extends StatelessWidget {
  const PubgetToriiMark({
    this.size = 72,
    this.color,
    this.accentColor,
    super.key,
  });

  final double size;
  final Color? color;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Pubget torii gate',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: ToriiGatePainter(
            fill: color ?? scheme.secondary,
            stroke: accentColor ?? AppColors.royalPurpleDark,
          ),
        ),
      ),
    );
  }
}

class ToriiGatePainter extends CustomPainter {
  const ToriiGatePainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final strokePaint = Paint()
      ..color = stroke.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.018).clamp(1.0, 2.2)
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final kasagi = Path()
      ..moveTo(w * 0.04, h * 0.20)
      ..quadraticBezierTo(w * 0.18, h * 0.08, w * 0.50, h * 0.06)
      ..quadraticBezierTo(w * 0.82, h * 0.08, w * 0.96, h * 0.20)
      ..lineTo(w * 0.90, h * 0.26)
      ..quadraticBezierTo(w * 0.50, h * 0.16, w * 0.10, h * 0.26)
      ..close();

    final shimaki = RRect.fromLTRBR(
      w * 0.12,
      h * 0.27,
      w * 0.88,
      h * 0.34,
      Radius.circular(w * 0.02),
    );

    final nuki = RRect.fromLTRBR(
      w * 0.20,
      h * 0.46,
      w * 0.80,
      h * 0.53,
      Radius.circular(w * 0.018),
    );

    final leftPillar = RRect.fromLTRBR(
      w * 0.22,
      h * 0.30,
      w * 0.34,
      h * 0.96,
      Radius.circular(w * 0.03),
    );
    final rightPillar = RRect.fromLTRBR(
      w * 0.66,
      h * 0.30,
      w * 0.78,
      h * 0.96,
      Radius.circular(w * 0.03),
    );
    final gakuzuka = RRect.fromLTRBR(
      w * 0.47,
      h * 0.34,
      w * 0.53,
      h * 0.46,
      Radius.circular(w * 0.012),
    );

    canvas.drawRRect(leftPillar, fillPaint);
    canvas.drawRRect(rightPillar, fillPaint);
    canvas.drawRRect(gakuzuka, fillPaint);
    canvas.drawRRect(shimaki, fillPaint);
    canvas.drawRRect(nuki, fillPaint);
    canvas.drawPath(kasagi, fillPaint);

    canvas.drawRRect(leftPillar, strokePaint);
    canvas.drawRRect(rightPillar, strokePaint);
    canvas.drawPath(kasagi, strokePaint);
  }

  @override
  bool shouldRepaint(covariant ToriiGatePainter oldDelegate) {
    return oldDelegate.fill != fill || oldDelegate.stroke != stroke;
  }
}
