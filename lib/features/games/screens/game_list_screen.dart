import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../models/game_models.dart';
import '../models/game_type_registry.dart';
import '../providers/game_providers.dart';
import '../widgets/game_widgets.dart';

class GameListScreen extends StatefulWidget {
  const GameListScreen({this.groupId, super.key});

  final String? groupId;

  @override
  State<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends State<GameListScreen> {
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
      if (uid != null) await list.loadMine(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = context.watch<GameListProvider>();
    final groupId = widget.groupId;
    final canManage =
        groupId != null &&
        context.watch<GroupProvider>().membership?.canManageGames == true;
    return DefaultTabController(
      length: groupId == null ? 3 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: Text(groupId == null ? 'Games' : GameStrings.groupGames),
          bottom: groupId == null
              ? const TabBar(
                  isScrollable: true,
                  tabs: <Widget>[
                    Tab(text: 'Live'),
                    Tab(text: 'Waiting'),
                    Tab(text: 'Mine'),
                  ],
                )
              : null,
        ),
        floatingActionButton: !canManage
            ? null
            : FloatingActionButton.extended(
                onPressed: () => AppNavigation.go(
                  context,
                  '/games/create?groupId=${Uri.encodeComponent(groupId)}',
                ),
                label: const Text(GameStrings.create),
                icon: const Icon(Icons.add),
              ),
        body: PubgetLoadingStateView(
          state: list.state,
          onRetry: () => widget.groupId == null
              ? list.loadHome()
              : list.loadGroup(widget.groupId!),
          empty: GameEmptyState(
            action: canManage
                ? PubgetPrimaryButton(
                    onPressed: () => AppNavigation.go(
                      context,
                      '/games/create?groupId=${Uri.encodeComponent(groupId)}',
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
                  children: <Widget>[
                    _GameTiles(games: list.active),
                    _GameTiles(games: list.waiting),
                    _GameTiles(games: list.mine),
                  ],
                )
              : _GameTiles(games: list.groupGames),
        ),
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
