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
import '../../../core/theme/app_colors.dart';

class EarnCoinsScreen extends StatefulWidget {
  const EarnCoinsScreen({Key? key}) : super(key: key);

  @override
  State<EarnCoinsScreen> createState() => _EarnCoinsScreenState();
}

class _EarnCoinsScreenState extends State<EarnCoinsScreen> {
  bool _isAdLoading = false;

  Future<bool> _canEarnEditToday(String userId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('daily_rewards')
        .doc('edit_$today')
        .get();
    return !doc.exists;
  }

  Future<int> _getEventWinsToday(String userId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('daily_rewards')
        .doc('event_$today')
        .get();
    return doc.exists ? (doc.data()?['count'] ?? 0) : 0;
  }

  void _showRewardSnackBar(BuildContext context, int amount) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: theme.colorScheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF00FF87), width: 1)),
        content: Row(children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: Color(0xFF00FF87)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
            'تمت العملية بنجاح! مبروك حصلت على +$amount عملة مشعة.',
            style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.bold),
          )),
        ]),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating),
    );
  }

  void _shareReferralLink(BuildContext context) {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _showErrorSnackBar(context, '⚠️ يجب تسجيل الدخول');
      return;
    }
    final link = PubgetLinks.referralStoreLink(userId);
    Share.share(
        '🔥 انضم معي إلى مجتمع Pubget الأسطوري! حمّل التطبيق وسجّل عبر رابطي لتحصل على 30 عملة: \n$link',
        subject: 'دعوة للانضمام إلى Pubget 🐉');
  }

  void _openSocialLinks(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
        context: context,
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('تابع Pubget الرسمي',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary)),
              const SizedBox(height: 16),
              ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.pink),
                  title: Text('Instagram @pubget_app',
                      style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary)),
                  trailing: Icon(Icons.open_in_new,
                      size: 18,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                  onTap: () async {
                    Navigator.pop(context);
                    final uri =
                        Uri.parse('https://www.instagram.com/pubget_app');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  }),
              ListTile(
                  leading: Icon(Icons.music_note,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary),
                  title: Text('TikTok @pubget_app',
                      style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary)),
                  trailing: Icon(Icons.open_in_new,
                      size: 18,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                  onTap: () async {
                    Navigator.pop(context);
                    final uri =
                        Uri.parse('https://www.tiktok.com/@pubget_app');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  }),
            ])));
  }

  Widget _buildSkeletonCard(bool isDark) {
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final shimmerColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: shimmerColor)),
      child: Row(children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: shimmerColor, shape: BoxShape.circle)),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Container(
                  height: 13,
                  width: 120,
                  decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 8),
              Container(
                  height: 11,
                  width: 80,
                  decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(6))),
            ])),
        const SizedBox(width: 8),
        Container(
            width: 72,
            height: 36,
            decoration: BoxDecoration(
                color: shimmerColor,
                borderRadius: BorderRadius.circular(10))),
      ]),
    );
  }

  // ✅ دالة منفصلة لمنطق الإعلان — أوضح وأسهل للصيانة
  Future<void> _handleWatchAd(BuildContext context) async {
    setState(() => _isAdLoading = true);

    // ✅ capture providers قبل أي await لتجنب مشكلة context بعد dismiss الإعلان
    final adService = context.read<AdService>();
    final storeProvider = context.read<StoreProvider>();
    final userProvider = context.read<UserProvider>();

    bool rewardGranted = false;

    final bool adShown = await adService.showSingleRewardedAd(
      // ✅ التعديل الجوهري: المكافأة تُمنح هنا فقط — بعد مشاهدة الإعلان فعلاً
      onReward: () async {
        final success = await storeProvider.rewardForWatchingAd();
        if (success) {
          await userProvider.reloadUser();
          rewardGranted = true;
        }
      },
    );

    if (!mounted) return;

    if (!adShown) {
      // الإعلان لم يُعرض (timeout أو فشل التحميل)
      _showErrorSnackBar(context, 'تعذر تحميل الإعلان، حاول مجدداً');
    } else if (rewardGranted) {
      // ✅ الإعلان عُرض والمستخدم شاهده حتى النهاية
      _showRewardSnackBar(context, 20);
    } else if (adShown && !rewardGranted) {
      // الإعلان عُرض لكن المستخدم أغلقه قبل الحصول على المكافأة
      // أو cooldown نشط
      _showErrorSnackBar(context, 'انتظر 30 ثانية قبل مشاهدة إعلان آخر');
    }

    if (mounted) setState(() => _isAdLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storeProvider = context.watch<StoreProvider>();
    final userId = context.read<UserProvider>().currentUser?.id ?? '';
    final isDark = theme.brightness == Brightness.dark;

    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
            backgroundColor: surfaceColor,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
                icon: Icon(Icons.close_rounded, color: textPrimary),
                onPressed: () => Navigator.pop(context)),
            title: Text('شحن العملات المجانية',
                style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            centerTitle: true),
        body: Column(children: [
          // ── Header Card ──
          Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF5B2EFF), Color(0xFFB800FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24)),
              child: Column(children: [
                const ShinyCoinWidget(size: 54),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('رصيدك الحالي: ',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Text('${storeProvider.currentCoins}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  const SizedBox(width: 4),
                  const ShinyCoinWidget(size: 16)
                ]),
                const SizedBox(height: 8),
                const Text('نفذ المهام واجمع ثروتك الأسطورية! 🐉',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ])),

          // ── Task List ──
          Expanded(
              child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [

                // 1- إعلان
                _buildTaskCard(
                  context,
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  title: 'مشاهدة إعلان مكافأة',
                  subtitle: _isAdLoading
                      ? 'جاري تحميل الإعلان...'
                      : 'شاهد إعلاناً قصيراً واربح',
                  reward: '+20',
                  icon: Icons.play_circle_filled_rounded,
                  isAd: true,
                  // ✅ النص يعكس الحالة: تحميل أو مشاهدة
                  actionText: _isAdLoading ? 'جاري التحميل...' : 'مشاهدة',
                  enabled: !_isAdLoading,
                  onTap: () => _handleWatchAd(context),
                ),

                // 2- دعوة
                _buildTaskCard(
                  context,
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  title: 'دعوة صديق',
                  subtitle: 'يحصل هو على 30 وأنت 70',
                  reward: '+70',
                  icon: Icons.person_add_alt_1_rounded,
                  actionText: 'دعوة صديق',
                  onTap: () => _shareReferralLink(context),
                ),

                // 3- فعالية
                FutureBuilder<int>(
                    future: _getEventWinsToday(userId),
                    builder: (_, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return _buildSkeletonCard(isDark);
                      }
                      final wins = snap.data ?? 0;
                      final canPlay = wins < 3;
                      return _buildTaskCard(
                        context,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        title: 'الفوز في الفعالية',
                        subtitle: 'شارك واربح ($wins/3 اليوم)',
                        reward: '+10',
                        icon: Icons.emoji_events_rounded,
                        actionText: canPlay ? 'العب الآن' : 'مكتمل',
                        enabled: canPlay,
                        onTap: canPlay
                            ? () async {
                                final groups = await context
                                    .read<GroupProvider>()
                                    .getUserGroups(userId: userId);
                                if (groups.isEmpty) {
                                  if (mounted) {
                                    _showErrorSnackBar(
                                        context, 'انضم لمجموعة أولاً');
                                  }
                                  return;
                                }
                                final randomGroup =
                                    groups[Random().nextInt(groups.length)];
                                if (mounted) {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => ChatScreen(
                                              groupId: randomGroup.id,
                                              openEventsOnStart: true)));
                                }
                              }
                            : null,
                      );
                    }),

                // 4- إديت
                FutureBuilder<bool>(
                    future: _canEarnEditToday(userId),
                    builder: (_, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return _buildSkeletonCard(isDark);
                      }
                      final canEarn = snap.data ?? true;
                      return _buildTaskCard(
                        context,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        title: 'نشر مقطع إديت',
                        subtitle: canEarn
                            ? 'انشر واربح +10'
                            : 'تم أخذ مكافأة اليوم',
                        reward: '+10',
                        icon: Icons.video_collection_rounded,
                        actionText: canEarn ? 'نشر مقطع' : 'مكتمل',
                        enabled: canEarn,
                        onTap: canEarn
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const UploadEditScreen()))
                            : null,
                      );
                    }),

                // 5- سوشيال
                _buildTaskCard(
                  context,
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  title: 'تابع حسابات Pubget',
                  subtitle: 'Instagram و TikTok',
                  reward: '',
                  icon: Icons.star_purple500_rounded,
                  actionText: 'زيارة',
                  onTap: () => _openSocialLinks(context),
                ),

                const SizedBox(height: 16),
              ])),
        ]),
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context, {
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required String title,
    required String subtitle,
    required String reward,
    required IconData icon,
    String actionText = '',
    bool isAd = false,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    const adGreen = Color(0xFF00FF87);
    const purpleAccent = Color(0xFF7C4DFF);
    const rewardPurple = Color(0xFFB800FF);

    return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: isAd ? adGreen.withOpacity(0.4) : borderColor)),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: isAd
                      ? adGreen.withOpacity(0.15)
                      : purpleAccent.withOpacity(0.12),
                  shape: BoxShape.circle),
              child: Icon(icon,
                  color: isAd ? adGreen : purpleAccent, size: 24)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(color: textSecondary, fontSize: 12)),
                if (reward.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(reward,
                        style: TextStyle(
                            color: isAd ? adGreen : rewardPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    const SizedBox(width: 4),
                    const ShinyCoinWidget(size: 13)
                  ])
                ]
              ])),
          const SizedBox(width: 8),
          ElevatedButton(
              onPressed: enabled ? onTap : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: enabled
                      ? (isAd ? adGreen : purpleAccent)
                      : Colors.grey.shade700,
                  foregroundColor: isAd ? Colors.black : Colors.white,
                  disabledBackgroundColor: isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade300,
                  disabledForegroundColor: isDark
                      ? Colors.grey.shade500
                      : Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: Text(actionText,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold))),
        ]));
  }
}