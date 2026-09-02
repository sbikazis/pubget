import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'pubget_torii_mark.dart';

class AuthAtmosphere extends StatelessWidget {
  const AuthAtmosphere({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.royalPurplePale,
                AppColors.lightBackground,
                AppColors.goldPale,
              ],
              stops: <double>[0, 0.52, 1],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -60,
          child: _GlowOrb(
            diameter: 220,
            color: AppColors.royalPurple.withValues(alpha: 0.16),
          ),
        ),
        Positioned(
          bottom: -40,
          left: -50,
          child: _GlowOrb(
            diameter: 180,
            color: AppColors.gold.withValues(alpha: 0.18),
          ),
        ),
        const Positioned(
          top: 36,
          right: 18,
          child: IgnorePointer(
            child: Opacity(opacity: 0.07, child: PubgetToriiMark(size: 168)),
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
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
