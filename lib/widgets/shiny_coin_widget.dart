// lib/features/store/widgets/shiny_coin_widget.dart

import 'package:flutter/material.dart';

class ShinyCoinWidget extends StatelessWidget {
  final double size;

  const ShinyCoinWidget({Key? key, this.size = 24.0}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            Color(0xFFB800FF), // بنفسجي ميتاليك
            Color(0xFF00FF87), // أخضر نيون براق
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF87).withOpacity(0.6),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: const Color(0xFFB800FF).withOpacity(0.4),
            blurRadius: 6,
            spreadRadius: -1,
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.9),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.brightness_high, 
          size: size * 0.65,
          color: Colors.white,
        ),
      ),
    );
  }
}