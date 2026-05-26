// lib/features/monetization/promotion_dialog.dart

import 'package:flutter/material.dart';
import '../../core/constants/store_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';
import 'package:pubget/widgets/shiny_coin_widget.dart';

class PromotionDialog extends StatelessWidget {
  final String groupName;
  final VoidCallback onConfirm;

  const PromotionDialog({
    Key? key, 
    required this.groupName, 
    required this.onConfirm
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const textPrimary = AppColors.darkTextPrimary;
    const textSecondary = AppColors.darkTextSecondary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface, // توحيد التصاميم بالثيم الداكن الأنيق للعملة
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50, 
            height: 5,
            decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 20),
          // تحويل اللون ليتطابق مع الأخضر النيون الخاص بالترويج والأرباح في عملتنا
          const Icon(Icons.stars_rounded, color: Color(0xFF00FF87), size: 50),
          const SizedBox(height: 15),
          Text(
            "ترويج مجموعة $groupName",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 12),
          const Text(
            "سيتم ترويج وعرض مجموعتك في الساحة والصفحة الرئيسية لكل المستخدمين لمدة 7 أيام متواصلة، مما يضمن تدفق الأعضاء بكثافة.",
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 25),
          
          // كارت الفاتورة والتحصيل الجديد بالعملات بدلاً من رمز الدولار الملغي
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFF00FF87).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "رسوم ترويج العملة:", 
                  style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 14),
                ),
                Row(
                  children: const [
                    Text(
                      "${StoreConstants.groupPromotionPrice}", // 150 عملة
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00FF87)),
                    ),
                    SizedBox(width: 6),
                    ShinyCoinWidget(size: 18),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          AppButton(
            text: "تأكيد سداد الـ 150 عملة والترويج",
            onPressed: onConfirm,
            icon: Icons.check_circle_rounded,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
