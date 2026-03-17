import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_theme.dart';

/// WIDGET: InfoTooltip
/// يظهر تلميح قصير للمستخدم فوق عنصر معين.
/// يدعم:
/// - أيقونة اختيارية (default: info_outline)
/// - ألوان متوافقة مع الوضع الداكن والفاتح
/// - عرض تلقائي متناسق
class InfoTooltip extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;

  const InfoTooltip({
    Key? key,
    required this.message,
    this.icon = Icons.info_outline,
    this.backgroundColor,
    this.textColor,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor = backgroundColor ??
        (brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface);
    final fgColor = textColor ??
        (brightness == Brightness.dark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width ?? 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fgColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: AppTextTheme.lightTextTheme.bodyMedium!.copyWith(color: fgColor)
              ),
            ),
          ],
        ),
      ),
    );
  }
}