import 'package:flutter/material.dart';

class AuthGoogleMark extends StatelessWidget {
  const AuthGoogleMark({this.size = 18, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Google',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _GoogleMarkPainter()),
      ),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.12,
      size.width * 0.76,
      size.height * 0.76,
    );

    stroke.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.35, 1.6, false, stroke);
    stroke.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 1.25, 1.15, false, stroke);
    stroke.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.4, 0.9, false, stroke);
    stroke.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.45, 1.2, false, stroke);

    final bar = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.width * 0.16
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(
      Offset(size.width * 0.52, size.height * 0.50),
      Offset(size.width * 0.88, size.height * 0.50),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
