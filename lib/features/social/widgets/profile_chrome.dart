import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_snackbars.dart';
import '../models/profile_social_link.dart';

IconData profileSocialIcon(String platform) => switch (platform) {
  'x' || 'twitter' => Icons.alternate_email_rounded,
  'instagram' => Icons.camera_alt_outlined,
  'tiktok' => Icons.music_note_outlined,
  'youtube' => Icons.play_circle_outline,
  'discord' => Icons.forum_outlined,
  'telegram' => Icons.send_outlined,
  'mal' || 'anilist' => Icons.movie_filter_outlined,
  _ => Icons.link_rounded,
};

class ProfileSocialLinkChips extends StatelessWidget {
  const ProfileSocialLinkChips({required this.links, super.key});

  final List<ProfileSocialLink> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: links.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final link = links[index];
          return ActionChip(
            avatar: Icon(profileSocialIcon(link.resolvedPlatform), size: 16),
            label: Text(link.displayLabel),
            onPressed: () => _open(context, link.url),
          );
        },
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    try {
      await SharePlus.instance.share(ShareParams(uri: uri, text: url));
    } on Object {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        PubgetSnackbars.showInfo(context, 'Link copied');
      }
    }
  }
}

class ProfileSectionHeader extends StatelessWidget {
  const ProfileSectionHeader({
    required this.title,
    this.onViewAll,
    this.viewAllLabel = 'View all',
    super.key,
  });

  final String title;
  final VoidCallback? onViewAll;
  final String viewAllLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.royalPurpleDark,
              ),
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: Text(viewAllLabel),
            ),
        ],
      ),
    );
  }
}

class ProfileStatPill extends StatelessWidget {
  const ProfileStatPill({
    required this.label,
    required this.value,
    this.icon,
    super.key,
  });

  final String label;
  final int value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.royalPurplePale,
              AppColors.goldPale,
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          children: <Widget>[
            if (icon != null) ...[
              Icon(icon, color: AppColors.royalPurple, size: 18),
              const SizedBox(height: 4),
            ],
            Text(
              '$value',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.royalPurpleDark,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePremiumChip extends StatelessWidget {
  const ProfilePremiumChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.goldDark.withValues(alpha: 0.45)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.workspace_premium_rounded, size: 14, color: AppColors.goldDark),
          SizedBox(width: 4),
          Text(
            'Premium',
            style: TextStyle(
              color: AppColors.goldDark,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileAchievementBadge extends StatelessWidget {
  const ProfileAchievementBadge({
    required this.title,
    required this.unlocked,
    this.icon = Icons.emoji_events_outlined,
    super.key,
  });

  final String title;
  final bool unlocked;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? AppColors.goldDark : AppColors.lightTextMuted;
    return SizedBox(
      width: 88,
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked
                  ? AppColors.goldPale
                  : AppColors.lightSurfaceMuted,
              border: Border.all(
                color: unlocked
                    ? AppColors.gold
                    : AppColors.lightOutline.withValues(alpha: 0.4),
              ),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
