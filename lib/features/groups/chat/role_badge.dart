import 'package:flutter/material.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/theme/role_colors.dart';
import '../../../../core/theme/app_text_theme.dart';

class RoleBadge extends StatelessWidget {
  final Roles role;

  const RoleBadge({
    super.key,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color roleColor = RoleColors.getColor(role, isDark: isDark);
    final Color badgeBg = RoleColors.getBadgeBackground(role, isDark: isDark);

    return Container(
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

          Text(
            role.label,
            style: (isDark
                    ? AppTextTheme.darkTextTheme.labelMedium
                    : AppTextTheme.lightTextTheme.labelMedium)!
                .copyWith(
              color: roleColor,
              fontWeight: FontWeight.w600,
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