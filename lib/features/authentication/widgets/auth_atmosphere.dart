import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'pubget_torii_mark.dart';

class AuthAtmosphere extends StatelessWidget {
  const AuthAtmosphere({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final direction = Directionality.of(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const <Color>[
                      AppColors.royalNight,
                      AppColors.royalDusk,
                      AppColors.royalEmber,
                    ]
                  : const <Color>[
                      AppColors.royalHorizon,
                      AppColors.royalTwilight,
                      AppColors.royalViolet,
                    ],
              stops: const <double>[0, 0.46, 1],
            ),
          ),
        ),
        const CustomPaint(painter: _AuthLightRayPainter(), size: Size.infinite),
        const CustomPaint(painter: _AuthParticlePainter(), size: Size.infinite),
        Positioned.directional(
          textDirection: direction,
          top: -110,
          end: -80,
          child: _GlowOrb(
            diameter: 280,
            color: AppColors.royalPurpleLight.withValues(
              alpha: isDark ? 0.22 : 0.28,
            ),
          ),
        ),
        Positioned.directional(
          textDirection: direction,
          bottom: -70,
          start: -90,
          child: _GlowOrb(
            diameter: 240,
            color: AppColors.gold.withValues(alpha: isDark ? 0.14 : 0.18),
          ),
        ),
        Positioned.directional(
          textDirection: direction,
          bottom: 24,
          end: 12,
          child: IgnorePointer(
            child: Opacity(
              opacity: isDark ? 0.10 : 0.12,
              child: const PubgetToriiMark(size: 188),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _AuthLightRayPainter extends CustomPainter {
  const _AuthLightRayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColors.goldSheen.withValues(alpha: 0.10),
              AppColors.goldSheen.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromLTWH(
              size.width * 0.28,
              0,
              size.width * 0.44,
              size.height * 0.62,
            ),
          );
    final path = Path()
      ..moveTo(size.width * 0.42, 0)
      ..lineTo(size.width * 0.58, 0)
      ..lineTo(size.width * 0.70, size.height * 0.58)
      ..lineTo(size.width * 0.30, size.height * 0.58)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AuthParticlePainter extends CustomPainter {
  const _AuthParticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.goldSheen.withValues(alpha: 0.16);
    const seeds = <double>[
      0.12,
      0.18,
      0.27,
      0.33,
      0.41,
      0.48,
      0.56,
      0.63,
      0.71,
      0.79,
      0.86,
      0.93,
    ];
    for (var i = 0; i < seeds.length; i++) {
      final dx = size.width * ((math.sin(seeds[i] * 12) + 1) / 2);
      final dy = size.height * seeds[i];
      canvas.drawCircle(Offset(dx, dy), i.isEven ? 1.6 : 1.1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
