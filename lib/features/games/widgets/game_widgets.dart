import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/game_copy.dart';
import '../models/game_models.dart';
import '../models/game_type_registry.dart';
import '../providers/game_providers.dart';

abstract final class GameLinks {
  static String path(String gameId) => PubgetLinks.gamePath(gameId);

  static String canonical(String gameId) => PubgetLinks.game(gameId);

  static Future<void> copy(BuildContext context, String gameId) =>
      PubgetLinks.copy(
        context,
        canonical(gameId),
        type: 'game',
        message: GameCopy.of(context).copied,
      );

  static Future<void> share(
    BuildContext context,
    String gameId, {
    String? title,
  }) => PubgetLinks.share(
    context,
    url: canonical(gameId),
    title: title ?? GameCopy.of(context).share,
    type: 'game',
  );

  static void open(BuildContext context, String gameId) {
    AppNavigation.go(context, path(gameId));
  }

  static void openMafia(BuildContext context, String gameId) {
    AppNavigation.go(context, PubgetLinks.mafiaPath(gameId));
  }

  static void openCreate(BuildContext context, {String? groupId}) {
    final hasGroup = groupId != null && groupId.isNotEmpty;
    final query = <String, String>{
      if (hasGroup) 'groupId': groupId,
      // gamesDomain.createGame rejects anything that does not carry this
      // marker, so every group-scoped create button sends it (Spec 12.1).
      if (hasGroup) 'source': 'group_chat',
    };
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    AppNavigation.go(context, '/games/create$suffix');
  }

  static void openCenter(BuildContext context, {required String groupId}) {
    final query = Uri(
      queryParameters: <String, String>{
        'groupId': groupId,
        'source': 'group_chat',
      },
    ).query;
    AppNavigation.go(context, '/games?$query');
  }
}

/// A live "waiting room closes in m:ss" line driven by the server's
/// `waitingDeadlineAt` (gamesDomain writes WAITING_ROOM_TIMEOUT_SECONDS when
/// a game enters WAITING, Spec 12.1).
class WaitingRoomCountdown extends StatefulWidget {
  const WaitingRoomCountdown({required this.deadline, super.key});

  final DateTime deadline;

  @override
  State<WaitingRoomCountdown> createState() => _WaitingRoomCountdownState();
}

class _WaitingRoomCountdownState extends State<WaitingRoomCountdown> {
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    if (widget.deadline.difference(_now).isNegative) return;
    Future<void>.delayed(const Duration(seconds: 1), _tick);
    setState(() => _now = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    var remaining = widget.deadline.difference(_now);
    if (remaining.isNegative) remaining = Duration.zero;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final copy = GameCopy.of(context);
    return Text(
      '${copy.waitingRoomClosesIn} $minutes:$seconds',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class GameStatusBadge extends StatelessWidget {
  const GameStatusBadge({required this.status, super.key});

  final GameStatus status;

  @override
  Widget build(BuildContext context) {
    return PubgetBadge(label: GameCopy.of(context).statusLabel(status));
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
          '${spec.name} · ${GameCopy.of(context).playerCount(game.participantsCount)}',
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
    final copy = GameCopy.of(context);
    final active = participants.where((item) => item.isActive).toList();
    if (active.isEmpty) {
      return PubgetEmptyState(
        title: copy.noPlayersYet,
        message: copy.joinFirst,
      );
    }
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(copy.playersTitle, style: Theme.of(context).textTheme.titleMedium),
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
                  : PubgetBadge(label: copy.eliminated),
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
    final copy = GameCopy.of(context);
    final result = game.result;
    if (result == null || !game.isHistorical) {
      return const SizedBox.shrink();
    }
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            copy.resultTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(copy.statusLabel(game.status)),
          if (result.winnerIds.isNotEmpty) Text(copy.winners(result.winnerIds)),
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
  const GameEmptyState({this.action, this.message, super.key});

  final Widget? action;

  /// Section-specific empty copy: the Active, Waiting, Recent, and History
  /// tabs must not all claim "start a game" when they mean different things.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final copy = GameCopy.of(context);
    return PubgetEmptyState(
      title: copy.noGamesTitle,
      message: message ?? copy.noGamesMessage,
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
      message: message ?? GameCopy.of(context).gamesCouldNotLoad,
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
          PubgetSectionHeader(
            title: AppStrings.of(context).sectionGames,
            actionLabel: GameCopy.of(context).seeAll,
            onAction: () => AppNavigation.go(context, '/games'),
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
                  return SizedBox(width: 220, child: GameCard(game: game));
                },
              ),
            ),
        ],
      ),
    );
  }
}
