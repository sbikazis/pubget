// lib/features/groups/chat/role_badge.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/theme/role_colors.dart';
import '../../../../core/theme/app_text_theme.dart';

class RoleBadge extends StatelessWidget {
  final Roles role;
  // ✅ التعديل: إضافة عرض محدود اختياري للرتبة لضمان استقرار التصميم في الدردشة
  final double? maxWidth;

  const RoleBadge({
    super.key,
    required this.role,
    this.maxWidth, // يمرر عند الرغبة في تقليص الرتبة ذكياً
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color roleColor = RoleColors.getColor(role, isDark: isDark);
    final Color badgeBg = RoleColors.getBadgeBackground(role, isDark: isDark);

    return Container(
      // ✅ استخدام constraints لمنع التمدد الزائد في حال كانت الأسماء والجوهرة تشغل مساحة كبيرة
      constraints: maxWidth != null ? BoxConstraints(maxWidth: maxWidth!) : null,
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getRoleIcon(role),
            size: 14,
            color: roleColor,
          ),

          const SizedBox(width: 4),

          // ✅ استخدام Flexible مع نص متقلص لضمان عدم حدوث خطأ Overflow
          Flexible(
            child: Text(
              role.label,
              overflow: TextOverflow.ellipsis, // يضع نقاط عند ضيق المساحة
              maxLines: 1,
              style: (isDark
                      ? AppTextTheme.darkTextTheme.labelMedium
                      : AppTextTheme.lightTextTheme.labelMedium)!
                  .copyWith(
                color: roleColor,
                fontWeight: FontWeight.w600,
                fontSize: 11, // تصغير طفيف جداً للتناسب مع الجوهرة
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Role icon resolver
  IconData _getRoleIcon(Roles role) {
    switch (role) {
      case Roles.founder:
        return Icons.workspace_premium;

      case Roles.sensei:
        return Icons.school;

      case Roles.hakusho:
        return Icons.verified;

      case Roles.senpai:
        return Icons.military_tech;

      case Roles.member:
        return Icons.person;
    }
  }
}