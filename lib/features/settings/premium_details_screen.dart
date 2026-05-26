// lib/features/profile/premium_details_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/store_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_button.dart';
import 'package:pubget/widgets/shiny_coin_widget.dart';

class PremiumDetailsScreen extends StatelessWidget {
  const PremiumDetailsScreen({super.key});

  // دالة مساعدة لبناء سطر المميزات متوافقة مع ألوان البريميوم الملكية والعملة الجديدة
  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFB800FF).withValues(alpha: 0.1), // خلفية بنفسجية خفيفة متناسقة مع التنين
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFB800FF), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.darkTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface, // تحويلها للمظهر الداكن الفخم لبروز التوهج
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // خط السحب العلوي
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 25),

          const Text(
            "انضم إلى نخبة PubGet",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: AppColors.darkTextPrimary,
            ),
          ),
          
          const SizedBox(height: 6),
          const Text(
            "احصل على القوة الكاملة والتميز الدائم",
            style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
          ),
          const SizedBox(height: 25),

          // قائمة المميزات الحصرية المتبقية بعد تجريد الخصائص التقنية الثلاث ونقلها للستور
          _buildFeatureItem(
            Icons.block_flipped,
            "تجربة بدون إعلانات",
            "استمتع بالتطبيق وتصفح بحرية كاملة دون أي فواصل إعلانية منبثقة مزعجة.",
          ),
          _buildFeatureItem(
            Icons.stars_rounded,
            "شارة التميز الملكية 👑",
            "تظهر هالة التميز بجانب اسمك في غرف الدردشة والملفات الشخصية لتمنحك هيبة أسطورية.",
          ),
          _buildFeatureItem(
            Icons.bolt_rounded,
            "أولوية اجتماعية خارقة",
            "احصل على أسبقية المعالجة في الخوادم والظهور، وأولوية مطلقة في طلبات الانضمام.",
          ),

          const SizedBox(height: 30),

          // حاوية السعر الجديدة المدمجة بالعملة اللامعة والزر الملكي المحدث
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    "التكلفة الحالية: ",
                    style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
                  ),
                  Text(
                    "${StoreConstants.premiumSubscriptionPrice}", // 500 عملة
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(width: 6),
                  ShinyCoinWidget(size: 20),
                ],
              ),
              const SizedBox(height: 16),
              AppButton(
                text: "تفعيل العضوية المميزة للأبد",
                icon: Icons.diamond_rounded,
                onPressed: () async {
                  await Provider.of<UserProvider>(context, listen: false)
                      .activatePremiumSubscription();
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("مبروك! أنت الآن عضو بريميوم أسطوري 💎"),
                        backgroundColor: Color(0xFFB800FF),
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
            "شحن مرة واحدة، ميزات دائمة للأبد لحسابك",
            style: TextStyle(fontSize: 11, color: AppColors.darkTextSecondary),
          ),
        ],
      ),
    );
  }
}