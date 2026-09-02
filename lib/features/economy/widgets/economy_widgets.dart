import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/economy_models.dart';
import '../models/economy_types.dart';

class CoinBalanceChip extends StatelessWidget {
  const CoinBalanceChip({
    required this.balance,
    this.onPressed,
    this.cached = false,
    super.key,
  });

  final int balance;
  final VoidCallback? onPressed;
  final bool cached;

  @override
  Widget build(BuildContext context) {
    final tooltip = cached ? EconomyStrings.cached : EconomyStrings.coins;
    final chip = Chip(
      avatar: const Icon(Icons.monetization_on_outlined, size: 18),
      label: Text('$balance'),
    );
    return Semantics(
      button: onPressed != null,
      label: '${EconomyStrings.coins}: $balance',
      child: onPressed == null
          ? Tooltip(message: tooltip, child: chip)
          : Tooltip(
              message: tooltip,
              child: ActionChip(
                avatar: const Icon(Icons.monetization_on_outlined, size: 18),
                label: Text('$balance'),
                onPressed: onPressed,
              ),
            ),
    );
  }
}

class EquippedAvatar extends StatelessWidget {
  const EquippedAvatar({
    this.imageUrl,
    this.name,
    this.frameId,
    this.size = PubgetAvatarSize.large,
    super.key,
  });

  final String? imageUrl;
  final String? name;
  final String? frameId;
  final PubgetAvatarSize size;

  @override
  Widget build(BuildContext context) {
    final avatar = PubgetAvatar(imageUrl: imageUrl, name: name, size: size);
    if (frameId == null || frameId!.isEmpty) return avatar;
    final scheme = Theme.of(context).colorScheme;
    final color = frameId == 'frame_gold' ? scheme.tertiary : scheme.primary;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
      ),
      child: avatar,
    );
  }
}

class StoreItemCard extends StatelessWidget {
  const StoreItemCard({
    required this.item,
    required this.owned,
    this.equipped = false,
    this.onTap,
    super.key,
  });

  final StoreItem item;
  final bool owned;
  final bool equipped;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PubgetCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(_iconFor(item.type)),
              const Spacer(),
              if (item.premiumOnly)
                PubgetBadge(label: EconomyStrings.premium, compact: true),
              if (owned)
                PubgetBadge(
                  label: equipped ? EconomyStrings.equipped : EconomyStrings.owned,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(item.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            owned ? EconomyStrings.alreadyOwned : '${item.price} ${EconomyStrings.coins}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class AdPlacementView extends StatelessWidget {
  const AdPlacementView({
    required this.visible,
    this.adFree = false,
    super.key,
  });

  final bool visible;
  final bool adFree;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      if (!adFree) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Text(
          EconomyStrings.adHidden,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return Semantics(
      label: EconomyStrings.adPlaceholder,
      child: PubgetCard(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.campaign_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                EconomyStrings.adPlaceholder,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(StoreItemType type) {
  return switch (type) {
    StoreItemType.frame => Icons.crop_square_outlined,
    StoreItemType.badge => Icons.military_tech_outlined,
    StoreItemType.nameplate => Icons.badge_outlined,
    StoreItemType.theme => Icons.palette_outlined,
  };
}
