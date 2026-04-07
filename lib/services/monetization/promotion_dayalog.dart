// lib/features/monetization/promotion_dialog.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';

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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50, height: 5,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.stars_rounded, color: Colors.amber, size: 50),
          const SizedBox(height: 15),
          Text(
            "ترويج مجموعة $groupName",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          const Text(
            "سيتم عرض مجموعتك في الصفحة الرئيسية لكل المستخدمين لمدة 7 أيام، مما يزيد من سرعة انضمام الأعضاء.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.amber.withOpacity(0.5)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("تكلفة العرض:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("5.00\$", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
              ],
            ),
          ),
          const SizedBox(height: 30),
          AppButton(
            text: "تأكيد الدفع والترويج",
            onPressed: onConfirm,
            icon: Icons.check_circle,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}