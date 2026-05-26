// lib/features/store/screens/earn_coins_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_links.dart';
import '../../../providers/store_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/monetization/ad_service.dart';
import 'package:pubget/widgets/shiny_coin_widget.dart';

class EarnCoinsScreen extends StatelessWidget {
  const EarnCoinsScreen({Key? key}) : super(key: key);

  void _showRewardSnackBar(BuildContext context, String title, int amount) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF12121A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF00FF87), width: 1),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00FF87)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'تمت العملية بنجاح! مبروك حصلت على +$amount عملة مشعة.',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📥 دالة توليد رابط المتجر الذكي ومشاركته فوراً
  void _shareReferralLink(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.currentUser?.id;

    if (currentUserId == null || currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ عذراً، يجب تسجيل الدخول لتوليد رابط الدعوة الخاص بك.'))
      );
      return;
    }

    // توليد الرابط الموجه لمتجر جوجل بلاي مباشرة مع حقن معرف الداعي الفريد
    final String playStoreLink = PubgetLinks.referralStoreLink(currentUserId);

    Share.share(
      '🔥 انضم معي إلى مجتمع Pubget الأسطوري لعشاق الأنمي! حمّل التطبيق وسجّل عبر رابطي الخاص لتحصل على 30 عملة مشعة فوراً: \n$playStoreLink',
      subject: 'دعوة للانضمام إلى Pubget 🐉',
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = AppColors.darkBackground;
    const surfaceColor = AppColors.darkSurface;
    const cardColor = AppColors.darkCard;
    const textPrimary = AppColors.darkTextPrimary;
    const textSecondary = AppColors.darkTextSecondary;

    final storeProvider = Provider.of<StoreProvider>(context);

    final List<Map<String, dynamic>> tasks = [
      {
        'title': 'مشاهدة إعلان مكافأة (اختياري)',
        'subtitle': 'شاهد إعلاناً قصيراً لزيادة رصيدك ودعم التطبيق.',
        'reward': '+20',
        'icon': Icons.play_circle_filled_rounded,
        'actionText': 'مشاهدة',
        'isAd': true,
        'onTap': (BuildContext ctx) async {
          final adService = Provider.of<AdService>(ctx, listen: false);
          bool adShown = await adService.showCreateGroupAd(isPremium: false);
          
          if (adShown) {
            bool success = await Provider.of<StoreProvider>(ctx, listen: false).rewardForWatchingAd();
            if (success) {
              _showRewardSnackBar(ctx, 'إعلان مكافأة', 20);
            } else {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('🛡️ حماية ضد الغش: يرجى الانتظار قليلاً قبل مشاهدة الإعلان التالي.'))
              );
            }
          } else {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('⚠️ الإعلان غير جاهز حالياً، يرجى المحاولة بعد قليل.'))
            );
          }
        }
      },
      {
        'title': 'دعوة صديق جديد لمجموعتك',
        'subtitle': 'عند تسجيله من طرفك يحصل هو على 30 وأنت على 70 عملة.',
        'reward': '+70',
        'icon': Icons.person_add_alt_1_rounded,
        'actionText': 'دعوة صديق',
        'isAd': false,
        'onTap': (BuildContext ctx) {
          _shareReferralLink(ctx); // استدعاء دالة التوليد والمشاركة الفركتالية
        }
      },
      {
        'title': 'الفوز في الفعالية اليومية',
        'subtitle': 'شارك في تخمين الشخصيات أو سلسلة الأنمي واقتنص الفوز.',
        'reward': '+10',
        'icon': Icons.emoji_events_rounded,
        'actionText': 'العب الآن',
        'isAd': false,
        'onTap': (BuildContext ctx) async {
          await Provider.of<StoreProvider>(ctx, listen: false).rewardForEventWin();
          _showRewardSnackBar(ctx, 'الفوز بالفعالية', 10);
        }
      },
      {
        'title': 'نشر مقطع إديت (Edit) جديد',
        'subtitle': 'انشر مقطع فيديو إبداعي قصير في قسم الإديتات الخاص بالتطبيق.',
        'reward': '+10',
        'icon': Icons.video_collection_rounded,
        'actionText': 'نشر مقطع',
        'isAd': false,
        'onTap': (BuildContext ctx) async {
          await Provider.of<StoreProvider>(ctx, listen: false).rewardForPublishingEdit();
          _showRewardSnackBar(ctx, 'نشر إديت', 10);
        }
      },
      {
        'title': 'متابعة حساب التطبيق الرسمي',
        'subtitle': 'تابع حسابات Pubget الرسمية على شبكات التواصل لتبقى على اطلاع.',
        'reward': '+50',
        'icon': Icons.star_purple500_rounded,
        'actionText': 'متابعة',
        'isAd': false,
        'onTap': (BuildContext ctx) async {
          await Provider.of<StoreProvider>(ctx, listen: false).rewardForFollowingAccount();
          _showRewardSnackBar(ctx, 'متابعة الحساب الرسمي', 50);
        }
      },
    ];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'شحن العملات المجانية',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5B2EFF), Color(0xFFB800FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              children: [
                const ShinyCoinWidget(size: 54),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'رصيدك الحالي: ',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '${storeProvider.currentCoins}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(width: 4),
                    const ShinyCoinWidget(size: 16),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'نفذ المهام واجمع ثروتك الأسطورية! 🐉',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                final isAd = task['isAd'] as bool;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isAd 
                          ? const Color(0xFF00FF87).withOpacity(0.4)
                          : AppColors.darkBorder.withOpacity(0.5),
                      width: isAd ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isAd 
                              ? const Color(0xFF00FF87).withOpacity(0.1)
                              : AppColors.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          task['icon'],
                          color: isAd ? const Color(0xFF00FF87) : AppColors.primaryLight,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task['title'],
                              style: const TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              task['subtitle'],
                              style: const TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  task['reward'],
                                  style: TextStyle(
                                    color: isAd ? const Color(0xFF00FF87) : const Color(0xFFB800FF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const ShinyCoinWidget(size: 13),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: storeProvider.isLoading 
                            ? null 
                            : () => task['onTap'](context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAd ? const Color(0xFF00FF87) : AppColors.primary,
                          foregroundColor: isAd ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          task['actionText'],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
