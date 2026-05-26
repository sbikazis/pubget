// lib/features/profile/premium_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/store_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../providers/store_provider.dart';
import '../../widgets/app_button.dart';
import 'package:pubget/widgets/shiny_coin_widget.dart';

class PremiumDetailsScreen extends StatelessWidget {
  const PremiumDetailsScreen({super.key});

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFB800FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFB800FF), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.darkTextPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    final isPremium = user?.isPremium?? false;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 25),
          const Text("انضم إلى نخبة PubGet", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary)),
          const SizedBox(height: 6),
          Text(
            isPremium? "عضويتك نشطة" : "اشتراك شهري متجدد",
            style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
          ),
          const SizedBox(height: 25),

          _buildFeatureItem(Icons.block_flipped, "تجربة بدون إعلانات", "تصفح بحرية كاملة دون فواصل إعلانية."),
          _buildFeatureItem(Icons.stars_rounded, "شارة التميز الملكية 👑", "هالة مميزة بجانب اسمك في الدردشة."),
          _buildFeatureItem(Icons.bolt_rounded, "أولوية اجتماعية", "أسبقية في طلبات الانضمام والظهور."),

          const SizedBox(height: 20),

          if (isPremium && user?.premiumExpiresAt!= null)...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "ينتهي في: ${user!.premiumExpiresAt!.day}/${user.premiumExpiresAt!.month}/${user.premiumExpiresAt!.year}",
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('تجديد تلقائي', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('سيتم خصم 900 تلقائياً عند الانتهاء', style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 11)),
              value: user.autoRenewPremium,
              activeColor: const Color(0xFF00FF87),
              onChanged: (v) async {
                await context.read<UserProvider>().updateUser(user.copyWith(autoRenewPremium: v));
              },
            ),
          ],

          const SizedBox(height: 20),

          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("التكلفة: ", style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 14)),
                  Text(
                    "${StoreConstants.premiumSubscriptionPrice}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(width: 6),
                  const ShinyCoinWidget(size: 20),
                  const Text(" / 30 يوم", style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 16),
              if (!isPremium)
                AppButton(
                  text: "تفعيل العضوية المميزة (30 يوم)",
                  icon: Icons.diamond_rounded,
                  onPressed: () async {
                    final store = context.read<StoreProvider>();
                    final success = await store.purchasePremiumSubscription();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success? "مبروك! تم تفعيل Premium لمدة 30 يوم 💎" : "رصيدك غير كافي"),
                          backgroundColor: success? const Color(0xFFB800FF) : Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
            ],
          ),

          const SizedBox(height: 15),
          const Text(
            "اشتراك شهري - يمكنك الإلغاء في أي وقت",
            style: TextStyle(fontSize: 11, color: AppColors.darkTextSecondary),
          ),
        ],
      ),
    );
  }
}