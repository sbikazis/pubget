// lib/features/store/screens/earn_coins_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import '../../../core/constants/app_links.dart';
import '../../../providers/store_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/group_provider.dart';
import '../../../services/monetization/ad_service.dart';
import 'package:pubget/widgets/shiny_coin_widget.dart';
import '../../groups/chat/chat_screen.dart';
import '../../edits/upload_edit_screen.dart';

class EarnCoinsScreen extends StatelessWidget {
  const EarnCoinsScreen({Key? key}) : super(key: key);

  void _showRewardSnackBar(BuildContext context, String title, int amount) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: theme.colorScheme.surface,
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
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareReferralLink(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.currentUser?.id;

    if (currentUserId == null || currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ عذراً، يجب تسجيل الدخول لتوليد رابط الدعوة الخاص بك.'))
      );
      return;
    }

    final String playStoreLink = PubgetLinks.referralStoreLink(currentUserId);
    Share.share(
      '🔥 انضم معي إلى مجتمع Pubget الأسطوري لعشاق الأنمي! حمّل التطبيق وسجّل عبر رابطي الخاص لتحصل على 30 عملة مشعة فوراً: \n$playStoreLink',
      subject: 'دعوة للانضمام إلى Pubget 🐉',
    );
  }

  void _openSocialLinks(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تابع Pubget الرسمي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.pink),
              title: const Text('Instagram @pubget_app'),
              subtitle: const Text('instagram.com/pubget_app'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () async {
                final uri = Uri.parse('https://www.instagram.com/pubget_app?igsh=MTl1aWc2dzk5ODZzOA==');
                Navigator.pop(context);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.music_note, color: Colors.white),
              title: const Text('TikTok @pubget_app'),
              subtitle: const Text('tiktok.com/@pubget_app'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () async {
                final uri = Uri.parse('https://www.tiktok.com/@pubget_app?_r=1&_t=ZS-96gYgWxhoxg');
                Navigator.pop(context);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: 10),
            const Text('تابعنا لآخر أخبار الأنمي والفعاليات', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.scaffoldBackgroundColor;
    final surfaceColor = theme.colorScheme.surface;
    final cardColor = theme.colorScheme.secondaryContainer;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.textTheme.bodyMedium?.color?? Colors.grey;
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
        'onTap': (BuildContext ctx) => _shareReferralLink(ctx)
      },
      {
        'title': 'الفوز في الفعالية اليومية',
        'subtitle': 'شارك في تخمين الشخصيات أو سلسلة الأنمي واقتنص الفوز.',
        'reward': '+10',
        'icon': Icons.emoji_events_rounded,
        'actionText': 'العب الآن',
        'isAd': false,
        'onTap': (BuildContext ctx) async {
          final userId = Provider.of<UserProvider>(ctx, listen:false).currentUser?.id;
          if (userId == null) return;
          final groups = await Provider.of<GroupProvider>(ctx, listen:false).getUserGroups(userId: userId);
          if (groups.isEmpty) {
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('انضم لمجموعة أولاً لتتمكن من اللعب')));
            return;
          }
          final randomGroup = groups[Random().nextInt(groups.length)];
          Navigator.push(ctx, MaterialPageRoute(builder: (_) => ChatScreen(groupId: randomGroup.id, openEventsOnStart: true)));
        }
      },
      {
        'title': 'نشر مقطع إديت (Edit) جديد',
        'subtitle': 'انشر مقطع فيديو إبداعي قصير في قسم الإديتات الخاص بالتطبيق.',
        'reward': '+10',
        'icon': Icons.video_collection_rounded,
        'actionText': 'نشر مقطع',
        'isAd': false,
        'onTap': (BuildContext ctx) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const UploadEditScreen()))
      },
      {
        'title': 'تابع حسابات Pubget الرسمية',
        'subtitle': 'تابعنا على Instagram و TikTok لآخر الأخبار والتحديثات',
        'reward': '', // بدون مكافأة - متوافق مع Google Play
        'icon': Icons.star_purple500_rounded,
        'actionText': 'زيارة',
        'isAd': false,
        'onTap': (BuildContext ctx) => _openSocialLinks(ctx)
      },
    ];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.close_rounded, color: textPrimary), onPressed: () => Navigator.pop(context)),
        title: Text('شحن العملات المجانية', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF5B2EFF), Color(0xFFB800FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                const ShinyCoinWidget(size: 54),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                  const Text('رصيدك الحالي: ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Text('${storeProvider.currentCoins}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(width: 4),
                  const ShinyCoinWidget(size: 16),
                ]),
                const SizedBox(height: 8),
                const Text('نفذ المهام واجمع ثروتك الأسطورية! 🐉', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
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
                final hasReward = task['reward'].toString().isNotEmpty;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isAd? const Color(0xFF00FF87).withOpacity(0.4): theme.dividerColor.withOpacity(0.2), width: isAd? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isAd? const Color(0xFF00FF87).withOpacity(0.1): theme.colorScheme.primary.withOpacity(0.12), shape: BoxShape.circle), child: Icon(task['icon'], color: isAd? const Color(0xFF00FF87) : theme.colorScheme.secondary, size: 24)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(task['title'], style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(task['subtitle'], style: TextStyle(color: textSecondary, fontSize: 11, height: 1.3)),
                        if (hasReward)...[
                          const SizedBox(height: 6),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(task['reward'], style: TextStyle(color: isAd? const Color(0xFF00FF87) : const Color(0xFFB800FF), fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 4),
                            const ShinyCoinWidget(size: 13),
                          ]),
                        ]
                      ])),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: storeProvider.isLoading? null : () => task['onTap'](context),
                        style: ElevatedButton.styleFrom(backgroundColor: isAd? const Color(0xFF00FF87) : theme.colorScheme.primary, foregroundColor: isAd? Colors.black : theme.colorScheme.onPrimary, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0, minimumSize: Size.zero),
                        child: Text(task['actionText'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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