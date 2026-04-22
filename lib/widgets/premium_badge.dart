import 'package:flutter/material.dart';

class PremiumBadge extends StatelessWidget {
  final double size;
  final bool showText;
  // ✅ التعديل: إضافة خاصية النمط المصغر للتحكم في التوهج والحواف
  final bool isMini;

  const PremiumBadge({
    super.key,
    this.size = 18.0,
    this.showText = false,
    this.isMini = false, // القيمة الافتراضية تعطيك الشكل الكامل
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showText ? 8 : (isMini ? 3 : 4), // تقليل الحواف في النمط المصغر
        vertical: isMini ? 1 : 2, // تقليل الارتفاع في النمط المصغر
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
        // ✅ التعديل: إظهار التوهج (Shadow) فقط إذا لم يكن في النمط المصغر لمنع التداخل في الدردشة
        boxShadow: isMini 
          ? null 
          : [
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