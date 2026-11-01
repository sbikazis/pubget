import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../l10n/game_copy.dart';
import '../models/game_models.dart';
import '../models/game_type_registry.dart';
import '../providers/game_providers.dart';
import '../widgets/game_widgets.dart';

class GameListScreen extends StatefulWidget {
  const GameListScreen({
    this.groupId,
    this.creationSource = 'unknown',
    super.key,
  });

  final String? groupId;
  final String creationSource;

  @override
  State<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends State<GameListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    final list = context.read<GameListProvider>();
    final uid = context.read<AuthProvider>().currentUser?.id;
    Future<void>.microtask(() async {
      if (widget.groupId != null) {
        await list.loadGroup(widget.groupId!);
      } else {
        await list.loadHome();
      }
      if (uid != null) {
        await list.loadMine(uid);
        await list.loadHistory(uid);
      }
    });
    _tabs = TabController(length: 6, vsync: this)
      ..addListener(() {
        if (mounted && _tabs.index != _tab) {
          setState(() => _tab = _tabs.index);
        }
      });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = context.watch<GameListProvider>();
    final copy = GameCopy.of(context);
    final groupId = widget.groupId;
    // Server side (gamesDomain.createGame) only asks for group membership:
    // the daily two-game cap is the real limit, and `manageGames` is about
    // managing *other* people's games, not creating your own (Spec 12.1).
    final isMember =
        groupId != null &&
        context.watch<GroupProvider>().membership != null;
    final canCreate = isMember && widget.creationSource == 'group_chat';
    final groupGames = list.groupGames;
    // A group Center loads one list; the Active and Waiting sections are
    // views over it rather than separate queries.
    final active =
        groupId == null
        ? list.active
        : groupGames
            .where(
              (game) =>
                  game.status == GameStatus.starting ||
                  game.status == GameStatus.inProgress,
            )
            .toList(growable: false);
    final waiting =
        groupId == null
        ? list.waiting
        : groupGames
            .where(
              (game) =>
                  game.status == GameStatus.created ||
                  game.status == GameStatus.waiting,
            )
            .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(groupId == null ? copy.gameCenter : copy.gameCenterInGroup),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: <Widget>[
            Tab(text: copy.tabAvailable),
            Tab(text: copy.tabActive),
            Tab(text: copy.tabWaiting),
            Tab(text: copy.tabRecent),
            Tab(text: copy.tabHistory),
            Tab(text: copy.tabRules),
          ],
        ),
      ),
      floatingActionButton: !canCreate
          ? null
          : FloatingActionButton.extended(
              onPressed: () => AppNavigation.go(
                context,
                '/games/create?groupId=${Uri.encodeComponent(groupId)}'
                '&source=group_chat',
              ),
              label: Text(copy.createGame),
              icon: const Icon(Icons.add),
            ),
      body: PubgetLoadingStateView(
        // Every section owns its empty copy (Spec 12.1), so an empty list is
        // rendered by the section itself instead of a generic wrapper. The
        // static sections (Available, Rules) never hide behind a load state.
        state: _tab == 0 || _tab == 5 || list.state == LoadingState.empty
            ? LoadingState.loaded
            : list.state,
        onRetry: () => widget.groupId == null
            ? list.loadHome()
            : list.loadGroup(widget.groupId!),
        error: GameErrorState(
          message: list.failure?.message,
          onRetry: () => widget.groupId == null
              ? list.loadHome()
              : list.loadGroup(widget.groupId!),
        ),
        offline: PubgetOfflineState(
          onRetry: () => widget.groupId == null
              ? list.loadHome()
              : list.loadGroup(widget.groupId!),
        ),
        child: TabBarView(
          controller: _tabs,
          children: <Widget>[
            AvailableGamesSection(groupId: groupId, canCreate: canCreate),
            _GameTiles(games: active, emptyMessage: copy.noActiveGames),
            _GameTiles(games: waiting, emptyMessage: copy.noWaitingGames),
            _HistoryTiles(
              entries: list.recent,
              emptyMessage: copy.noRecentGames,
            ),
            _HistoryTiles(
              entries: list.history,
              emptyMessage: copy.noHistoryGames,
            ),
            const GameRulesSection(),
          ],
        ),
      ),
    );
  }
}

class _GameTiles extends StatelessWidget {
  const _GameTiles({required this.games, required this.emptyMessage});

  final List<PubgetGame> games;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return GameEmptyState(message: emptyMessage);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: games.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => GameCard(game: games[index]),
    );
  }
}

/// Game Center "Available Games": every implemented game stays listed and
/// tappable, including Mafia, which is created through its own callable.
class AvailableGamesSection extends StatelessWidget {
  const AvailableGamesSection({
    this.groupId,
    this.canCreate = false,
    super.key,
  });

  /// Set when the Center was opened from a group chat, which is the only
  /// place creation is allowed (Spec 12.1).
  final String? groupId;

  /// False outside a group chat: the card still lists the game (the four are
  /// never disabled), it just does not offer a button the server would refuse.
  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    final copy = GameCopy.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        if (!canCreate) ...[
          PubgetCard(
            child: Text(
              groupId == null
                  ? copy.createFromGroupChatOnly
                  : copy.createFromGroupChatButton,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (final spec in GameTypeRegistry.all)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PubgetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(spec.icon),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          spec.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(spec.description),
                  const SizedBox(height: AppSpacing.xs),
                  Text(_gameInfoLine(context, spec)),
                  if (canCreate) ...[
                    const SizedBox(height: AppSpacing.sm),
                    PubgetPrimaryButton(
                      onPressed: () => _create(context, spec),
                      semanticLabel: copy.createGame,
                      child: Text(
                        '${copy.createGame} ${spec.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _create(BuildContext context, GameTypeSpec spec) {
    // The create page fills the draft from the registry, so the requested size
    // always matches what the server will clamp to.
    final id = groupId;
    final query = <String>[
      if (id != null) 'groupId=${Uri.encodeComponent(id)}',
      'type=${spec.type.name}',
      'source=group_chat',
    ];
    AppNavigation.go(context, '/games/create?${query.join('&')}');
  }

  String _gameInfoLine(BuildContext context, GameTypeSpec spec) {
    final copy = GameCopy.of(context);
    final caps = spec.capabilities;
    final players = caps.minPlayers == caps.maxPlayers
        ? copy.playerCount(caps.minPlayers)
        : copy.playerRange(caps.minPlayers, caps.maxPlayers);
    // Spec 12.1: every game card carries players · duration · difficulty ·
    // win condition · type. The type is the card title above it.
    return '$players · ${copy.durationMinutes(spec.durationMinutes)}'
        ' · ${copy.difficultyTitle}: ${copy.difficulty(spec.difficulty)}'
        ' · ${copy.winConditionFor(spec.type)}';
  }
}

/// Game Center "Rules": the same facts as the Available Games cards, so a
/// player can read how a game is won before creating it.
class GameRulesSection extends StatelessWidget {
  const GameRulesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = GameCopy.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        for (final spec in GameTypeRegistry.all)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PubgetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    spec.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(copy.rulesFor(spec.type)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${copy.winCondition}: ${copy.winConditionFor(spec.type)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HistoryTiles extends StatelessWidget {
  const _HistoryTiles({required this.entries, required this.emptyMessage});

  final List<GameHistoryEntry> entries;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final copy = GameCopy.of(context);
    if (entries.isEmpty) {
      return PubgetEmptyState(
        title: copy.noGamesTitle,
        message: emptyMessage,
        icon: Icons.history,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PubgetCard(
              onTap: () => AppNavigation.go(context, '/game/${entry.gameId}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    GameTypeRegistry.tryOf(
                          GameType.values.firstWhere(
                            (type) => type.name == entry.type,
                            orElse: () => GameType.guessCharacter,
                          ),
                        )?.name ??
                        entry.type,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    entry.result?.winnerIds.isEmpty ?? true
                        ? copy.noWinner
                        : '${copy.winner}: ${entry.result!.winnerIds.join(', ')}',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
