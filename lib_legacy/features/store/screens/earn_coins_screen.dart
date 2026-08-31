// lib/features/store/screens/earn_coins_screen.dart

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_links.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/group_provider.dart';
import '../../../providers/store_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/monetization/ad_service.dart';
import '../../../widgets/shiny_coin_widget.dart';
import '../../edits/upload_edit_screen.dart';
import '../../groups/chat/chat_screen.dart';

class EarnCoinsScreen extends StatefulWidget {
  const EarnCoinsScreen({super.key});

  @override
  State<EarnCoinsScreen> createState() => _EarnCoinsScreenState();
}

class _EarnCoinsScreenState extends State<EarnCoinsScreen> {
  bool _isAdLoading = false;

  String _userId = '';

  Future<bool>? _canEarnEditFuture;
  Future<int>? _eventWinsFuture;

  bool _isFuturesInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final user = context.watch<UserProvider>().currentUser;

    if (user != null &&
        user.id.isNotEmpty &&
        user.id != _userId) {
      _userId = user.id;
      _initializeFutures();
    }
  }

  void _initializeFutures() {
    _canEarnEditFuture = _canEarnEditToday(_userId);
    _eventWinsFuture = _getEventWinsToday(_userId);

    setState(() {
      _isFuturesInitialized = true;
    });
  }

  Future<bool> _canEarnEditToday(String userId) async {
    if (userId.isEmpty) return true;

    try {
      final today =
          DateTime.now().toIso8601String().split('T')[0];

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('daily_rewards')
          .doc('edit_$today')
          .get();

      return !doc.exists;
    } catch (_) {
      return true;
    }
  }

  Future<int> _getEventWinsToday(String userId) async {
    if (userId.isEmpty) return 0;

    try {
      final today =
          DateTime.now().toIso8601String().split('T')[0];

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('daily_rewards')
          .doc('event_$today')
          .get();

      if (!doc.exists) return 0;

      return (doc.data()?['count'] ?? 0) as int;
    } catch (_) {
      return 0;
    }
  }

  void _showRewardSnackBar(
    BuildContext context,
    int amount,
  ) {
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: theme.colorScheme.surface,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(
            color: Color(0xFF00FF87),
            width: 1,
          ),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF00FF87),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'تمت العملية بنجاح! حصلت على +$amount عملة.',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareReferralLink(BuildContext context) {
    if (_userId.isEmpty) {
      _showErrorSnackBar(
        context,
        '⚠️ يجب تسجيل الدخول',
      );
      return;
    }

    final link =
        PubgetLinks.referralStoreLink(_userId);

    Share.share(
      '🔥 انضم إلى Pubget عبر رابطي واحصل على 30 عملة:\n$link',
      subject: 'دعوة إلى Pubget',
    );
  }

  void _openSocialLinks(BuildContext context) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'تابع حسابات Pubget الرسمية',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 18),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.camera_alt,
                    color: Colors.pink,
                  ),
                  title: Text(
                    'Instagram @pubget_app',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.open_in_new_rounded,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  onTap: () async {
                    Navigator.pop(context);

                    final uri = Uri.parse(
                      'https://www.instagram.com/pubget_app',
                    );

                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode:
                            LaunchMode.externalApplication,
                      );
                    }
                  },
                ),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.music_note,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  title: Text(
                    'TikTok @pubget_app',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.open_in_new_rounded,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  onTap: () async {
                    Navigator.pop(context);

                    final uri = Uri.parse(
                      'https://www.tiktok.com/@pubget_app',
                    );

                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode:
                            LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonCard(bool isDark) {
    final cardColor = isDark
        ? AppColors.darkCard
        : AppColors.lightSurface;

    final shimmerColor = isDark
        ? Colors.white.withOpacity(0.08)
        : AppColors.lightBorder;

    final borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: shimmerColor,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  height: 13,
                  width: 120,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius:
                        BorderRadius.circular(6),
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  height: 11,
                  width: 80,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius:
                        BorderRadius.circular(6),
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  height: 11,
                  width: 50,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius:
                        BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Container(
            width: 72,
            height: 36,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius:
                  BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleWatchAd(
    BuildContext context,
  ) async {
    if (_isAdLoading) return;

    setState(() {
      _isAdLoading = true;
    });

    final adService = context.read<AdService>();
    final storeProvider =
        context.read<StoreProvider>();
    final userProvider =
        context.read<UserProvider>();

    try {
      bool rewardGranted = false;

      final bool adShown =
          await adService.showSingleRewardedAd(
        onReward: () async {
          final success =
              await storeProvider
                  .rewardForWatchingAd();

          if (success) {
            await userProvider.reloadUser();
            rewardGranted = true;
          }
        },
      );

      if (!mounted) return;

      if (!adShown) {
        _showErrorSnackBar(
          context,
          'تعذر تحميل الإعلان',
        );
      } else if (rewardGranted) {
        _showRewardSnackBar(context, 20);
      } else {
        _showErrorSnackBar(
          context,
          'انتظر قليلاً قبل مشاهدة إعلان جديد',
        );
      }
    } catch (_) {
      if (mounted) {
        _showErrorSnackBar(
          context,
          'حدث خطأ أثناء تشغيل الإعلان',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final storeProvider =
        context.watch<StoreProvider>();

    final isDark =
        theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;

    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,

        appBar: AppBar(
          backgroundColor: surfaceColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: textPrimary,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text(
            'شحن العملات المجانية',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),

        body: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF5B2EFF),
                    Color(0xFFB800FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(
                  Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const ShinyCoinWidget(size: 54),

                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const Text(
                        'رصيدك الحالي: ',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),

                      Text(
                        '${storeProvider.currentCoins}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
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
              child: _userId.isEmpty ||
                      !_isFuturesInitialized
                  ? Center(
                      child:
                          CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : ListView(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      children: [
                        _buildTaskCard(
                          context,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary:
                              textSecondary,
                          title:
                              'مشاهدة إعلان مكافأة',
                          subtitle: _isAdLoading
                              ? 'جاري تحميل الإعلان...'
                              : 'شاهد إعلاناً قصيراً واربح',
                          reward: '+20',
                          icon: Icons
                              .play_circle_filled_rounded,
                          isAd: true,
                          actionText: _isAdLoading
                              ? 'جاري...'
                              : 'مشاهدة',
                          enabled: !_isAdLoading,
                          onTap: () =>
                              _handleWatchAd(
                            context,
                          ),
                        ),

                        _buildTaskCard(
                          context,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary:
                              textSecondary,
                          title: 'دعوة صديق',
                          subtitle:
                              'يحصل هو على 30 وأنت 70',
                          reward: '+70',
                          icon: Icons
                              .person_add_alt_1_rounded,
                          actionText: 'دعوة صديق',
                          onTap: () =>
                              _shareReferralLink(
                            context,
                          ),
                        ),

                        FutureBuilder<int>(
                          future: _eventWinsFuture,
                          builder: (_, snapshot) {
                            if (snapshot
                                    .connectionState ==
                                ConnectionState
                                    .waiting) {
                              return _buildSkeletonCard(
                                isDark,
                              );
                            }

                            final wins =
                                snapshot.data ?? 0;

                            final canPlay =
                                wins < 3;

                            return _buildTaskCard(
                              context,
                              isDark: isDark,
                              textPrimary:
                                  textPrimary,
                              textSecondary:
                                  textSecondary,
                              title:
                                  'الفوز في الفعالية',
                              subtitle:
                                  'شارك واربح ($wins/3 اليوم)',
                              reward: '+10',
                              icon: Icons
                                  .emoji_events_rounded,
                              actionText: canPlay
                                  ? 'العب الآن'
                                  : 'مكتمل',
                              enabled: canPlay,
                              onTap: canPlay
                                  ? () async {
                                      final groups =
                                          await context
                                              .read<
                                                  GroupProvider>()
                                              .getUserGroups(
                                                userId:
                                                    _userId,
                                              );

                                      if (groups
                                          .isEmpty) {
                                        if (mounted) {
                                          _showErrorSnackBar(
                                            context,
                                            'انضم لمجموعة أولاً',
                                          );
                                        }

                                        return;
                                      }

                                      final randomGroup =
                                          groups[
                                              Random()
                                                  .nextInt(
                                                groups
                                                    .length,
                                              )];

                                      if (mounted) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) =>
                                                    ChatScreen(
                                              groupId:
                                                  randomGroup
                                                      .id,
                                              openEventsOnStart:
                                                  true,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                            );
                          },
                        ),

                        FutureBuilder<bool>(
                          future:
                              _canEarnEditFuture,
                          builder: (_, snapshot) {
                            if (snapshot
                                    .connectionState ==
                                ConnectionState
                                    .waiting) {
                              return _buildSkeletonCard(
                                isDark,
                              );
                            }

                            final canEarn =
                                snapshot.data ??
                                    true;

                            return _buildTaskCard(
                              context,
                              isDark: isDark,
                              textPrimary:
                                  textPrimary,
                              textSecondary:
                                  textSecondary,
                              title:
                                  'نشر مقطع إديت',
                              subtitle: canEarn
                                  ? 'انشر واربح +10'
                                  : 'تم أخذ مكافأة اليوم',
                              reward: '+10',
                              icon: Icons
                                  .video_collection_rounded,
                              actionText: canEarn
                                  ? 'نشر مقطع'
                                  : 'مكتمل',
                              enabled: canEarn,
                              onTap: canEarn
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) =>
                                                  const UploadEditScreen(),
                                        ),
                                      );
                                    }
                                  : null,
                            );
                          },
                        ),

                        _buildTaskCard(
                          context,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary:
                              textSecondary,
                          title:
                              'تابع حسابات Pubget',
                          subtitle:
                              'Instagram و TikTok',
                          reward: '',
                          icon: Icons
                              .star_purple500_rounded,
                          actionText: 'زيارة',
                          onTap: () =>
                              _openSocialLinks(
                            context,
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
            ),
          ],
        ),
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
    final cardColor = isDark
        ? AppColors.darkCard
        : AppColors.lightSurface;

    final borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

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
          color: isAd
              ? adGreen.withOpacity(0.35)
              : borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isAd
                  ? adGreen.withOpacity(0.15)
                  : purpleAccent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isAd
                  ? adGreen
                  : purpleAccent,
              size: 24,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                  ),
                ),

                if (reward.isNotEmpty) ...[
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Text(
                        reward,
                        style: TextStyle(
                          color: isAd
                              ? adGreen
                              : rewardPurple,
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(width: 4),

                      const ShinyCoinWidget(
                        size: 13,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 10),

          ElevatedButton(
            onPressed: enabled ? onTap : null,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: enabled
                  ? (isAd
                      ? adGreen
                      : purpleAccent)
                  : (isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade300),

              foregroundColor:
                  isAd ? Colors.black : Colors.white,

              disabledForegroundColor: isDark
                  ? Colors.grey.shade500
                  : Colors.grey.shade600,

              disabledBackgroundColor: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade300,

              surfaceTintColor:
                  Colors.transparent,

              shadowColor: Colors.transparent,

              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),

              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(10),
              ),
            ),
            child: Text(
              actionText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}