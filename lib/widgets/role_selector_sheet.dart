// lib/widgets/role_selector_sheet.dart
import 'package:flutter/material.dart';
import '../core/constants/roles.dart';
import '../core/theme/role_colors.dart';
import '../models/member_model.dart';

class RoleSelectorSheet extends StatelessWidget {
  final List<MemberModel> allMembers;
  final MemberModel targetMember;
  final Function(Roles) onRoleSelected;

  const RoleSelectorSheet({
    Key? key,
    required this.allMembers,
    required this.targetMember,
    required this.onRoleSelected,
  }) : super(key: key);

  // ✅ دالة داخلية لتحديد الأيقونة بناءً على الرتبة لتجنب الخطأ
  IconData _getRoleIcon(Roles role) {
    if (role == Roles.founder) return Icons.stars;
    if (role == Roles.sensei) return Icons.psychology;
    if (role == Roles.hakusho) return Icons.shield;
    if (role == Roles.senpai) return Icons.workspace_premium;
    return Icons.person; // الرتبة العادية
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final availableRoles = [
      Roles.sensei,
      Roles.hakusho,
      Roles.senpai,
      Roles.member,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'تعيين رتبة جديدة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'اختر رتبة لـ ${targetMember.displayName}',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: availableRoles.length,
            itemBuilder: (context, index) {
              final role = availableRoles[index];
              final color = RoleColors.getColor(role, isDark: isDark);
              final bg = RoleColors.getBadgeBackground(role, isDark: isDark);
              
              int currentCount = allMembers.where((m) => m.role == role).length;
              bool isFull = role.isLimited && currentCount >= (role.maxCount ?? 0);

              return InkWell(
                onTap: isFull ? null : () => onRoleSelected(role),
                child: Opacity(
                  opacity: isFull ? 0.5 : 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg.withOpacity(isDark ? 0.1 : 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ✅ تم استدعاء الدالة الداخلية هنا لإصلاح الخطأ
                        Icon(_getRoleIcon(role), color: color, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          role.label,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (role.isLimited)
                          Text(
                            '$currentCount/${role.maxCount}',
                            style: TextStyle(
                              color: isFull ? Colors.red : Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}