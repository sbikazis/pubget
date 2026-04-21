import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/limits.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_button.dart';

class PremiumDetailsScreen extends StatelessWidget {
  const PremiumDetailsScreen({super.key});

  // دالة مساعدة لبناء سطر المميزات
  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.amber, size: 28),
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
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
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
        color: Colors.white,
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
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 25),

          // تم إزالة const هنا لحل مشكلة FontWeight.black
          Text(
            "انضم إلى نخبة PubGet",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.values[8], // طريقة بديلة لـ Black (أقصى ثقل)
              letterSpacing: 0.5,
              color: Colors.black,
            ),
          ),
          
          const SizedBox(height: 8),
          const Text(
            "احصل على القوة الكاملة والتميز الدائم",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),

          // قائمة المميزات مع أيقونات أكثر توافقاً
          _buildFeatureItem(
            Icons.block_flipped, // بديل متوافق لتعطيل الإعلانات
            "تجربة بدون إعلانات",
            "استمتع بالتطبيق دون أي فواصل إعلانية مزعجة",
          ),
          _buildFeatureItem(
            Icons.groups_rounded,
            "مجموعات أضخم",
            "ارفع حد الأعضاء إلى ${Limits.maxMembersPremium} عضو في مجموعتك",
          ),
          _buildFeatureItem(
            Icons.stars_rounded, // أيقونة النجوم للتميز
            "شارة التميز ${Limits.premiumBadge}",
            "تظهر بجانب اسمك في الدردشة والبروفايل لتعطيك هيبة خاصة",
          ),
          _buildFeatureItem(
            Icons.bolt_rounded,
            "أولوية اجتماعية",
            " وأولوية في طلبات الانضمام",
          ),
          _buildFeatureItem(
            Icons.group_add,
            "مجال أوسع",
            "إنظم ل${Limits.maxJoinedPremium} بدل ${Limits.maxJoinedFree}",
          ),
          _buildFeatureItem(
            Icons.group_add,
            "أسس إمبراطوريات جديدة",
            "أنشئ ${Limits.maxGroupsPremium} بدل ${Limits.maxGroupsFree}",
          ),
          


          const SizedBox(height: 30),

          // استخدام AppButton
          AppButton(
            text: "ترقية الآن مقابل ${Limits.premiumPrice} للأبد",
            icon: Icons.diamond_outlined,
            onPressed: () async {
              await Provider.of<UserProvider>(context, listen: false)
                  .activatePremiumSubscription();
              
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("مبروك! أنت الآن عضو بريميوم 💎"),
                    backgroundColor: Colors.amber,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          
          const SizedBox(height: 15),
          const Text(
            "دفع مرة واحدة، ميزات دائمة للأبد",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}