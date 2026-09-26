import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';
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
  TabController? _tabs;
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
    _tabs = TabController(length: widget.groupId == null ? 6 : 1, vsync: this)
      ..addListener(() {
        if (mounted && _tabs?.index != _tab) {
          setState(() => _tab = _tabs!.index);
        }
      });
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = context.watch<GameListProvider>();
    final groupId = widget.groupId;
    final canManage =
        groupId != null &&
        widget.creationSource == 'group_chat' &&
        context.watch<GroupProvider>().membership?.canManageGames == true;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(groupId == null ? 'Games' : 'Game Center'),
        bottom: groupId == null
            ? TabBar(
                controller: _tabs,
                isScrollable: true,
                tabs: <Widget>[
                  Tab(text: 'Available'),
                  Tab(text: 'Live'),
                  Tab(text: 'Waiting'),
                  Tab(text: 'Recent'),
                  Tab(text: 'History'),
                  Tab(text: 'Rules'),
                ],
              )
            : null,
      ),
      floatingActionButton: !canManage
          ? null
          : FloatingActionButton.extended(
              onPressed: () => AppNavigation.go(
                context,
                '/games/create?groupId=${Uri.encodeComponent(groupId)}&source=group_chat',
              ),
              label: const Text(GameStrings.create),
              icon: const Icon(Icons.add),
            ),
      body: PubgetLoadingStateView(
        state: _tab == 0 || _tab == 5 ? LoadingState.loaded : list.state,
        onRetry: () => widget.groupId == null
            ? list.loadHome()
            : list.loadGroup(widget.groupId!),
        empty: GameEmptyState(
          action: canManage
              ? PubgetPrimaryButton(
                  onPressed: () => AppNavigation.go(
                    context,
                    '/games/create?groupId=${Uri.encodeComponent(groupId)}&source=group_chat',
                  ),
                  semanticLabel: GameStrings.create,
                  child: const Text(GameStrings.create),
                )
              : null,
        ),
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
        child: groupId == null
            ? TabBarView(
                controller: _tabs,
                children: <Widget>[
                  AvailableGamesSection(groupId: groupId),
                  _GameTiles(games: list.active),
                  _GameTiles(games: list.waiting),
                  _HistoryTiles(
                    entries: list.recent,
                    emptyMessage: 'No finished games yet.',
                  ),
                  _HistoryTiles(
                    entries: list.history,
                    emptyMessage: 'Your finished games appear here.',
                  ),
                  const GameRulesSection(),
                ],
              )
            : _GameTiles(games: list.groupGames),
      ),
    );
  }
}

class _GameTiles extends StatelessWidget {
  const _GameTiles({required this.games});

  final List<PubgetGame> games;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return const GameEmptyState();
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
  const AvailableGamesSection({this.groupId, super.key});

  /// Mafia is a group game, so it is only creatable from a group Game Center.
  final String? groupId;

  @override
  Widget build(BuildContext context) {
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
                  Text(_gameInfoLine(spec)),
                  const SizedBox(height: AppSpacing.sm),
                  PubgetPrimaryButton(
                    onPressed: () => _create(context, spec),
                    semanticLabel: GameStrings.create,
                    child: Text(
                      '${GameStrings.create} ${spec.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
    AppNavigation.go(
      context,
      '/games/create?type=${spec.type.name}&source=game_center',
    );
  }

  String _gameInfoLine(GameTypeSpec spec) {
    final caps = spec.capabilities;
    final players = caps.minPlayers == caps.maxPlayers
        ? '${caps.minPlayers} players'
        : '${caps.minPlayers}-${caps.maxPlayers} players';
    return '$players · ${spec.winCondition}';
  }
}

/// Game Center "Rules": the same facts as the Available Games cards, so a
/// player can read how a game is won before creating it.
class GameRulesSection extends StatelessWidget {
  const GameRulesSection({super.key});

  @override
  Widget build(BuildContext context) {
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
                  Text(spec.rules),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Win condition: ${spec.winCondition}',
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
    if (entries.isEmpty) {
      return PubgetEmptyState(
        title: GameStrings.noGamesTitle,
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
              onTap: () => AppNavigation.go(context, '/games/${entry.gameId}'),
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
                        ? 'No winner'
                        : 'Winner: ${entry.result!.winnerIds.join(', ')}',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
