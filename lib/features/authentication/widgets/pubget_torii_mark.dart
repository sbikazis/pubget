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
    final width = size;
    final height = size * 1.28;
    return Semantics(
      label: 'Pubget torii gate',
      image: true,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: ToriiGatePainter(
            fill: color ?? scheme.secondary,
            stroke: accentColor ?? AppColors.royalPurpleDark,
            highlight: AppColors.goldSheen,
          ),
        ),
      ),
    );
  }
}

class ToriiGatePainter extends CustomPainter {
  const ToriiGatePainter({
    required this.fill,
    required this.stroke,
    required this.highlight,
  });

  final Color fill;
  final Color stroke;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          highlight.withValues(alpha: 0.55),
          fill,
          AppColors.goldDark.withValues(alpha: 0.85),
        ],
        stops: const <double>[0, 0.42, 1],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final strokePaint = Paint()
      ..color = stroke.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.028).clamp(1.2, 2.6)
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final kasagi = Path()
      ..moveTo(w * 0.02, h * 0.16)
      ..quadraticBezierTo(w * 0.16, h * 0.035, w * 0.50, h * 0.02)
      ..quadraticBezierTo(w * 0.84, h * 0.035, w * 0.98, h * 0.16)
      ..lineTo(w * 0.93, h * 0.205)
      ..quadraticBezierTo(w * 0.50, h * 0.09, w * 0.07, h * 0.205)
      ..close();

    final shimaki = RRect.fromLTRBR(
      w * 0.10,
      h * 0.21,
      w * 0.90,
      h * 0.255,
      Radius.circular(w * 0.012),
    );

    final nuki = RRect.fromLTRBR(
      w * 0.22,
      h * 0.40,
      w * 0.78,
      h * 0.445,
      Radius.circular(w * 0.01),
    );

    final leftPillar = RRect.fromLTRBR(
      w * 0.275,
      h * 0.23,
      w * 0.325,
      h * 0.98,
      Radius.circular(w * 0.018),
    );
    final rightPillar = RRect.fromLTRBR(
      w * 0.675,
      h * 0.23,
      w * 0.725,
      h * 0.98,
      Radius.circular(w * 0.018),
    );
    final gakuzuka = RRect.fromLTRBR(
      w * 0.485,
      h * 0.255,
      w * 0.515,
      h * 0.40,
      Radius.circular(w * 0.008),
    );

    canvas.drawRRect(leftPillar, highlightPaint);
    canvas.drawRRect(rightPillar, highlightPaint);
    canvas.drawRRect(gakuzuka, fillPaint);
    canvas.drawRRect(shimaki, highlightPaint);
    canvas.drawRRect(nuki, fillPaint);
    canvas.drawPath(kasagi, highlightPaint);

    canvas.drawRRect(leftPillar, strokePaint);
    canvas.drawRRect(rightPillar, strokePaint);
    canvas.drawRRect(shimaki, strokePaint);
    canvas.drawPath(kasagi, strokePaint);
  }

  @override
  bool shouldRepaint(covariant ToriiGatePainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.stroke != stroke ||
        oldDelegate.highlight != highlight;
  }
}
