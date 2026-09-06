import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'app_image_loader.dart';
import 'pubget_avatar.dart';
import 'pubget_badge.dart';
import 'pubget_card.dart';

/// Premium welcome / identity surface used by Home and Profile.
class PubgetHeroBanner extends StatelessWidget {
  const PubgetHeroBanner({
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return PubgetCard(
      highlighted: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: isDark ? AppColors.royalViolet : AppColors.royalPurplePale,
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

final class PubgetNowActionData {
  const PubgetNowActionData({
    required this.id,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

/// Compact first-session destinations. Every action must already exist.
class PubgetNowActions extends StatelessWidget {
  const PubgetNowActions({required this.actions, super.key});

  final List<PubgetNowActionData> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final action = actions[index];
          return SizedBox(
            width: 108,
            child: PubgetCard(
              key: Key('home-now-action-${action.id}'),
              padding: const EdgeInsets.all(AppSpacing.sm),
              onTap: action.onPressed,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(action.icon, color: AppColors.gold),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PubgetReasonChip extends StatelessWidget {
  const PubgetReasonChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return PubgetBadge(
      label: label,
      compact: true,
      icon: Icons.auto_awesome_outlined,
    );
  }
}

class PubgetMediaTile extends StatelessWidget {
  const PubgetMediaTile({
    required this.title,
    required this.onTap,
    this.imageUrl,
    this.subtitle,
    this.reason,
    this.width = 148,
    this.height = 168,
    this.fallbackIcon = Icons.movie_filter_outlined,
    super.key,
  });

  final String title;
  final VoidCallback onTap;
  final String? imageUrl;
  final String? subtitle;
  final String? reason;
  final double width;
  final double height;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      height: height,
      child: PubgetCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
                child: imageUrl == null || imageUrl!.isEmpty
                    ? ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(fallbackIcon, color: AppColors.gold),
                      )
                    : AppImageLoader(imageUrl: imageUrl!, fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  if (reason != null && reason!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    PubgetReasonChip(label: reason!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PubgetGroupTile extends StatelessWidget {
  const PubgetGroupTile({
    required this.name,
    required this.onTap,
    this.imageUrl,
    this.description,
    this.meta,
    this.typeLabel,
    this.reason,
    this.highlighted = false,
    this.width = 248,
    super.key,
  });

  final String name;
  final VoidCallback onTap;
  final String? imageUrl;
  final String? description;
  final String? meta;
  final String? typeLabel;
  final String? reason;
  final bool highlighted;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppStrings.of(context);
    return SizedBox(
      width: width,
      child: PubgetCard(
        highlighted: highlighted,
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 78,
              child: imageUrl == null || imageUrl!.isEmpty
                  ? ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.groups_outlined),
                    )
                  : AppImageLoader(imageUrl: imageUrl!, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description == null || description!.isEmpty
                          ? copy.communityFallback
                          : description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        if (typeLabel != null && typeLabel!.isNotEmpty)
                          PubgetBadge(label: typeLabel!, compact: true),
                        if (reason != null && reason!.isNotEmpty)
                          PubgetReasonChip(label: reason!),
                      ],
                    ),
                    if (meta != null && meta!.isNotEmpty)
                      Text(meta!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PubgetPersonTile extends StatelessWidget {
  const PubgetPersonTile({
    required this.name,
    required this.onTap,
    this.avatarUrl,
    this.width = 176,
    super.key,
  });

  final String name;
  final VoidCallback onTap;
  final String? avatarUrl;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: PubgetCard(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            PubgetAvatar(
              imageUrl: avatarUrl,
              name: name,
              size: PubgetAvatarSize.medium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
