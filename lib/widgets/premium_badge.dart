import 'package:flutter/material.dart';

class PremiumBadge extends StatelessWidget {
  final double size;
  final bool showText;

  const PremiumBadge({
    super.key,
    this.size = 18.0,
    this.showText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showText ? 8 : 4,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        // تدرج لوني فاخر (أرجواني مع ذهبي خفيف)
        gradient: const LinearGradient(
          colors: [
            Color(0xFF8E24AA), // Purple Deep
            Color(0xFFD4AF37), // Metallic Gold
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size / 2),
        // تأثير التوهج (Glow Effect)
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.4),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.diamond_rounded, // أيقونة الألماسة
            size: size,
            color: Colors.white,
          ),
          if (showText) ...[
            const SizedBox(width: 4),
            const Text(
              'PREMIUM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}