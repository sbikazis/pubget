import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/game_models.dart';
import '../models/game_type_registry.dart';
import '../providers/game_providers.dart';

abstract final class GameLinks {
  static String path(String gameId) =>
      '/game/${Uri.encodeComponent(gameId)}';

  static Future<void> copy(BuildContext context, String gameId) async {
    await Clipboard.setData(ClipboardData(text: path(gameId)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(GameStrings.copied)));
  }

  static void open(BuildContext context, String gameId) {
    AppNavigation.go(context, path(gameId));
  }
}

class GameStatusBadge extends StatelessWidget {
  const GameStatusBadge({required this.status, super.key});

  final GameStatus status;

  @override
  Widget build(BuildContext context) {
    return PubgetBadge(label: status.name);
  }
}

class GameCard extends StatelessWidget {
  const GameCard({required this.game, this.onTap, super.key});

  final PubgetGame game;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spec = GameTypeRegistry.of(game.type);
    return PubgetCard(
      onTap: onTap ?? () => GameLinks.open(context, game.id),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(spec.icon),
        title: Text(game.title),
        subtitle: Text(
          '${spec.name} · ${game.participantsCount} players',
        ),
        trailing: GameStatusBadge(status: game.status),
      ),
    );
  }
}

class GameHeader extends StatelessWidget {
  const GameHeader({required this.game, super.key});

  final PubgetGame game;

  @override
  Widget build(BuildContext context) {
    final spec = GameTypeRegistry.of(game.type);
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(spec.icon),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  game.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              GameStatusBadge(status: game.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(spec.name, style: Theme.of(context).textTheme.labelLarge),
          if (game.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(game.description),
          ],
        ],
      ),
    );
  }
}

class ParticipantList extends StatelessWidget {
  const ParticipantList({required this.participants, super.key});

  final List<GameParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final active = participants.where((item) => item.isActive).toList();
    if (active.isEmpty) {
      return const PubgetEmptyState(
        title: 'No players yet',
        message: 'Join to be the first.',
      );
    }
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Players', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final person in active)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                person.isAlive
                    ? Icons.person_outline
                    : Icons.person_off_outlined,
              ),
              title: Text(
                person.displayName.isEmpty ? person.userId : person.displayName,
              ),
              trailing: person.isAlive
                  ? (person.score == null ? null : Text('${person.score}'))
                  : const PubgetBadge(label: GameStrings.eliminated),
            ),
        ],
      ),
    );
  }
}

class GameResultCard extends StatelessWidget {
  const GameResultCard({required this.game, super.key});

  final PubgetGame game;

  @override
  Widget build(BuildContext context) {
    final result = game.result;
    if (result == null || !game.isHistorical) {
      return const SizedBox.shrink();
    }
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            GameStrings.resultTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(game.status == GameStatus.cancelled ? 'Cancelled' : 'Completed'),
          if (result.winnerIds.isNotEmpty)
            Text('Winners: ${result.winnerIds.join(', ')}'),
        ],
      ),
    );
  }
}

class GameActionFeedback extends StatelessWidget {
  const GameActionFeedback({required this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: PubgetBadge(label: message!),
    );
  }
}

class GameLoadingState extends StatelessWidget {
  const GameLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: PubgetSkeleton.card(height: 120),
    );
  }
}

class GameEmptyState extends StatelessWidget {
  const GameEmptyState({this.action, super.key});

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return PubgetEmptyState(
      title: GameStrings.noGamesTitle,
      message: GameStrings.noGamesMessage,
      icon: Icons.sports_esports_outlined,
      action: action,
    );
  }
}

class GameErrorState extends StatelessWidget {
  const GameErrorState({required this.onRetry, this.message, super.key});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return PubgetErrorState(
      message: message ?? 'Games could not load.',
      onRetry: onRetry,
    );
  }
}

class GameHomeStrip extends StatelessWidget {
  const GameHomeStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final list = context.watch<GameListProvider>();
    if (list.state == LoadingState.initial) {
      Future<void>.microtask(list.loadHome);
    }
    final games = <PubgetGame>[...list.active, ...list.waiting];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Games',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                PubgetTextButton(
                  onPressed: () => AppNavigation.go(context, '/games'),
                  semanticLabel: GameStrings.seeAll,
                  child: const Text(GameStrings.seeAll),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (list.state == LoadingState.loading && games.isEmpty)
            const GameLoadingState()
          else if (games.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: GameEmptyState(),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                scrollDirection: Axis.horizontal,
                itemCount: games.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final game = games[index];
                  return SizedBox(
                    width: 220,
                    child: GameCard(game: game),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
