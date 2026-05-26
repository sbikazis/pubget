// lib/features/store/screens/earn_coins_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<bool> _canEarnEditToday(String userId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).collection('daily_rewards').doc('edit_$today').get();
    return!doc.exists;
  }

  Future<int> _getEventWinsToday(String userId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).collection('daily_rewards').doc('event_$today').get();
    return doc.exists? (doc.data()?['count']?? 0) : 0;
  }

  void _showRewardSnackBar(BuildContext context, int amount) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: theme.colorScheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF00FF87), width: 1)),
        content: Row(children: [
          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00FF87)),
          const SizedBox(width: 10),
          Expanded(child: Text('تمت العملية بنجاح! مبروك حصلت على +$amount عملة مشعة.', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }

  void _shareReferralLink(BuildContext context) {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ يجب تسجيل الدخول')));
      return;
    }
    final link = PubgetLinks.referralStoreLink(userId);
    Share.share('🔥 انضم معي إلى مجتمع Pubget الأسطوري! حمّل التطبيق وسجّل عبر رابطي لتحصل على 30 عملة: \n$link', subject: 'دعوة للانضمام إلى Pubget 🐉');
  }

  void _openSocialLinks(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Theme.of(context).colorScheme.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('تابع Pubget الرسمي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      ListTile(leading: const Icon(Icons.camera_alt, color: Colors.pink), title: const Text('Instagram @pubget_app'), trailing: const Icon(Icons.open_in_new, size: 18), onTap: () async { Navigator.pop(context); final uri = Uri.parse('https://www.instagram.com/pubget_app'); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }),
      ListTile(leading: const Icon(Icons.music_note), title: const Text('TikTok @pubget_app'), trailing: const Icon(Icons.open_in_new, size: 18), onTap: () async { Navigator.pop(context); final uri = Uri.parse('https://www.tiktok.com/@pubget_app'); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }),
    ])));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storeProvider = Provider.of<StoreProvider>(context);
    final userId = context.read<UserProvider>().currentUser?.id?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(backgroundColor: theme.colorScheme.surface, elevation: 0, leading: IconButton(icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface), onPressed: () => Navigator.pop(context)), title: Text('شحن العملات المجانية', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true),
      body: Column(children: [
        Container(width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF5B2EFF), Color(0xFFB800FF)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24)), child: Column(children: [
          const ShinyCoinWidget(size: 54), const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('رصيدك الحالي: ', style: TextStyle(color: Colors.white70, fontSize: 14)), Text('${storeProvider.currentCoins}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(width: 4), const ShinyCoinWidget(size: 16)]),
          const SizedBox(height: 8), const Text('نفذ المهام واجمع ثروتك الأسطورية! 🐉', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ])),
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          // 1- إعلان
          _buildTaskCard(context, title: 'مشاهدة إعلان مكافأة', subtitle: 'شاهد إعلاناً قصيراً', reward: '+20', icon: Icons.play_circle_filled_rounded, isAd: true, actionText: 'مشاهدة', onTap: () async {
            final adService = context.read<AdService>();
            bool adShown = await adService.showCreateGroupAd(isPremium: false);
            if (adShown) { bool success = await context.read<StoreProvider>().rewardForWatchingAd(); if (success) { await context.read<UserProvider>().reloadUser(); _showRewardSnackBar(context, 20); } }
          }),
          // 2- دعوة
          _buildTaskCard(context, title: 'دعوة صديق', subtitle: 'يحصل هو على 30 وأنت 70', reward: '+70', icon: Icons.person_add_alt_1_rounded, actionText: 'دعوة صديق', onTap: () => _shareReferralLink(context)),
          // 3- فعالية مع FutureBuilder
          FutureBuilder<int>(future: _getEventWinsToday(userId), builder: (ctx, snap) {
            final wins = snap.data?? 0;
            final canPlay = wins < 3;
            return _buildTaskCard(context, title: 'الفوز في الفعالية', subtitle: 'شارك واربح ($wins/3 اليوم)', reward: '+10', icon: Icons.emoji_events_rounded, actionText: canPlay? 'العب الآن' : 'مكتمل', enabled: canPlay, onTap: canPlay? () async {
              final groups = await context.read<GroupProvider>().getUserGroups(userId: userId);
              if (groups.isEmpty) return;
              final randomGroup = groups[Random().nextInt(groups.length)];
              Navigator.push(ctx, MaterialPageRoute(builder: (_) => ChatScreen(groupId: randomGroup.id, openEventsOnStart: true)));
            } : null);
          }),
          // 4- إديت مع FutureBuilder
          FutureBuilder<bool>(future: _canEarnEditToday(userId), builder: (ctx, snap) {
            final canEarn = snap.data?? true;
            return _buildTaskCard(context, title: 'نشر مقطع إديت', subtitle: canEarn? 'انشر واربح +10' : 'تم أخذ مكافأة اليوم', reward: '+10', icon: Icons.video_collection_rounded, actionText: canEarn? 'نشر مقطع' : 'مكتمل', enabled: true, onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const UploadEditScreen())));
          }),
          // 5- سوشيال
          _buildTaskCard(context, title: 'تابع حسابات Pubget', subtitle: 'Instagram و TikTok', reward: '', icon: Icons.star_purple500_rounded, actionText: 'زيارة', onTap: () => _openSocialLinks(context)),
        ])),
      ]),
    );
  }

  Widget _buildTaskCard(BuildContext context, {required String title, required String subtitle, required String reward, required IconData icon, String actionText = '', bool isAd = false, bool enabled = true, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return Container(margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(18), border: Border.all(color: isAd? const Color(0xFF00FF87).withOpacity(0.4) : theme.dividerColor.withOpacity(0.2))), child: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isAd? const Color(0xFF00FF87).withOpacity(0.1) : theme.colorScheme.primary.withOpacity(0.12), shape: BoxShape.circle), child: Icon(icon, color: isAd? const Color(0xFF00FF87) : theme.colorScheme.secondary, size: 24)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: theme.textTheme.bodyMedium?.color?? Colors.grey, fontSize: 11)),
        if (reward.isNotEmpty)...[const SizedBox(height: 6), Row(children: [Text(reward, style: TextStyle(color: isAd? const Color(0xFF00FF87) : const Color(0xFFB800FF), fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(width: 4), const ShinyCoinWidget(size: 13)])]
      ])),
      ElevatedButton(onPressed: enabled? onTap : null, style: ElevatedButton.styleFrom(backgroundColor: enabled? (isAd? const Color(0xFF00FF87) : theme.colorScheme.primary) : Colors.grey, foregroundColor: isAd? Colors.black : theme.colorScheme.onPrimary), child: Text(actionText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
    ]));
  }
}
