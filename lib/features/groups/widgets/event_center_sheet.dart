import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../games/models/game_models.dart';
import '../../games/models/game_type_registry.dart';
import '../../games/providers/game_providers.dart';

/// Unified Event Center — single entry for featured / available / active games.
class EventCenterSheet extends StatelessWidget {
  const EventCenterSheet({required this.groupId, super.key});

  final String groupId;

  static Future<void> show(BuildContext context, {required String groupId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => EventCenterSheet(groupId: groupId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.86;
    List<PubgetGame> active = const <PubgetGame>[];
    List<PubgetGame> waiting = const <PubgetGame>[];
    try {
      final games = context.watch<GameListProvider>();
      active = games.active
          .where((game) => game.groupId == groupId)
          .toList(growable: false);
      waiting = games.waiting
          .where((game) => game.groupId == groupId)
          .toList(growable: false);
    } on ProviderNotFoundException {
      // Thin test trees may omit GameListProvider.
    }

    final featured = GameTypeRegistry.implemented;
    return SizedBox(
      height: height,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
            Text(
              'Event Center',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.royalPurpleDark,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Games stay isolated from chat state. Create here, play in a private room, and results land back as chat events.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionTitle('Featured'),
            const SizedBox(height: AppSpacing.sm),
            ...featured.map(
              (spec) => _GameTypeTile(
                spec: spec,
                onTap: () {
                  Navigator.pop(context);
                  AppNavigation.go(
                    context,
                    '/games/create?groupId=${Uri.encodeComponent(groupId)}',
                  );
                },
              ),
            ),
            if (waiting.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              _SectionTitle('Waiting rooms'),
              const SizedBox(height: AppSpacing.sm),
              ...waiting.map(
                (game) => _LiveGameTile(
                  game: game,
                  onTap: () {
                    Navigator.pop(context);
                    AppNavigation.go(
                      context,
                      '/game?gameId=${Uri.encodeComponent(game.id)}',
                    );
                  },
                ),
              ),
            ],
            if (active.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              _SectionTitle('Active now'),
              const SizedBox(height: AppSpacing.sm),
              ...active.map(
                (game) => _LiveGameTile(
                  game: game,
                  onTap: () {
                    Navigator.pop(context);
                    if (game.type == GameType.mafia) {
                      AppNavigation.go(
                        context,
                        '/mafia?gameId=${Uri.encodeComponent(game.id)}',
                      );
                    } else {
                      AppNavigation.go(
                        context,
                        '/game?gameId=${Uri.encodeComponent(game.id)}',
                      );
                    }
                  },
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            _SectionTitle('Browse'),
            const SizedBox(height: AppSpacing.sm),
            PubgetSecondaryButton(
              onPressed: () {
                Navigator.pop(context);
                AppNavigation.go(
                  context,
                  '/games?groupId=${Uri.encodeComponent(groupId)}',
                );
              },
              semanticLabel: 'Open all group games',
              leadingIcon: Icons.sports_esports_outlined,
              child: const Text('All group games'),
            ),
            const SizedBox(height: AppSpacing.sm),
            PubgetSecondaryButton(
              onPressed: () {
                Navigator.pop(context);
                AppNavigation.go(
                  context,
                  '/events?groupId=${Uri.encodeComponent(groupId)}',
                );
              },
              semanticLabel: 'Open group events',
              leadingIcon: Icons.celebration_outlined,
              child: const Text('Group events'),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _GameTypeTile extends StatelessWidget {
  const _GameTypeTile({required this.spec, required this.onTap});

  final GameTypeSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final caps = spec.capabilities;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PubgetCard(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.royalPurplePale,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(spec.icon, color: AppColors.royalPurple),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    spec.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    spec.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${caps.minPlayers}–${caps.maxPlayers} players · isolated room',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.goldDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _LiveGameTile extends StatelessWidget {
  const _LiveGameTile({required this.game, required this.onTap});

  final PubgetGame game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spec = GameTypeRegistry.tryOf(game.type);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(spec?.icon ?? Icons.sports_esports_outlined),
      title: Text(spec?.name ?? game.type.name),
      subtitle: Text('${game.participantsCount} players · ${game.status.name}'),
      trailing: const Icon(Icons.play_arrow_rounded),
      onTap: onTap,
    );
  }
}
