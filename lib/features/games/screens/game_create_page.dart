import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/analytics/analytics.dart';
import '../../../core/errors/result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../mafia/providers/mafia_provider.dart';
import '../models/game_models.dart';
import '../models/game_type_registry.dart';
import '../providers/game_providers.dart';

class GameCreatePage extends StatefulWidget {
  const GameCreatePage({this.groupId, super.key});

  final String? groupId;

  @override
  State<GameCreatePage> createState() => _GameCreatePageState();
}

class _GameCreatePageState extends State<GameCreatePage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _started = false;
  bool _saving = false;
  String? _localError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    context.read<GameCreateProvider>().start(groupId: widget.groupId);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creator = context.watch<GameCreateProvider>();
    final types = GameTypeRegistry.implemented;
    final spec = GameTypeRegistry.of(creator.draft.type);
    final quiz = spec.capabilities.usesRounds && spec.capabilities.usesScoring;
    final isMafia = creator.draft.type == GameType.mafia;
    return Scaffold(
      appBar: AppBar(title: const Text(GameStrings.create)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Text('Game type', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final item in types)
            RadioListTile<GameType>(
              value: item.type,
              groupValue: creator.draft.type,
              title: Text(item.name),
              subtitle: Text(
                '${item.description} · ${item.capabilities.minPlayers}–${item.capabilities.maxPlayers} players',
              ),
              onChanged: (value) {
                if (value == null) return;
                creator.selectType(value);
              },
            ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            controller: _title,
            label: 'Title',
            onChanged: (value) =>
                creator.update(creator.draft.copyWith(title: value)),
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextArea(
            controller: _description,
            label: 'Description',
            onChanged: (value) =>
                creator.update(creator.draft.copyWith(description: value)),
          ),
          if (quiz) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Rules', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              value: creator.draft.configuration.difficulty,
              decoration: const InputDecoration(labelText: 'Difficulty'),
              items: const [
                DropdownMenuItem(value: 'easy', child: Text('Easy')),
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'hard', child: Text('Hard')),
              ],
              onChanged: (value) {
                if (value == null) return;
                creator.update(
                  creator.draft.copyWith(
                    configuration: GameConfiguration(
                      minPlayers: spec.capabilities.minPlayers,
                      maxPlayers: spec.capabilities.maxPlayers,
                      usesRounds: true,
                      roundCount: creator.draft.configuration.roundCount,
                      timerSeconds: creator.draft.configuration.timerSeconds,
                      difficulty: value,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int>(
              value: creator.draft.configuration.roundCount,
              decoration: const InputDecoration(labelText: 'Rounds'),
              items: const [
                DropdownMenuItem(value: 3, child: Text('3 rounds')),
                DropdownMenuItem(value: 5, child: Text('5 rounds')),
                DropdownMenuItem(value: 7, child: Text('7 rounds')),
              ],
              onChanged: (value) {
                if (value == null) return;
                creator.update(
                  creator.draft.copyWith(
                    configuration: GameConfiguration(
                      minPlayers: spec.capabilities.minPlayers,
                      maxPlayers: spec.capabilities.maxPlayers,
                      usesRounds: true,
                      roundCount: value,
                      timerSeconds: creator.draft.configuration.timerSeconds,
                      difficulty: creator.draft.configuration.difficulty,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int>(
              value: creator.draft.configuration.timerSeconds,
              decoration: const InputDecoration(labelText: 'Timer'),
              items: const [
                DropdownMenuItem(value: 15, child: Text('15 seconds')),
                DropdownMenuItem(value: 20, child: Text('20 seconds')),
                DropdownMenuItem(value: 30, child: Text('30 seconds')),
              ],
              onChanged: (value) {
                if (value == null) return;
                creator.update(
                  creator.draft.copyWith(
                    configuration: GameConfiguration(
                      minPlayers: spec.capabilities.minPlayers,
                      maxPlayers: spec.capabilities.maxPlayers,
                      usesRounds: true,
                      roundCount: creator.draft.configuration.roundCount,
                      timerSeconds: value,
                      difficulty: creator.draft.configuration.difficulty,
                    ),
                  ),
                );
              },
            ),
          ],
          if (isMafia) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Lobby', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int>(
              value: creator.draft.configuration.minPlayers.clamp(4, 16),
              decoration: const InputDecoration(labelText: 'Minimum players'),
              items: [
                for (var n = 4; n <= 16; n++)
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
              onChanged: (value) {
                if (value == null) return;
                final max = creator.draft.configuration.maxPlayers < value
                    ? value
                    : creator.draft.configuration.maxPlayers;
                creator.update(
                  creator.draft.copyWith(
                    configuration: GameConfiguration(
                      minPlayers: value,
                      maxPlayers: max.clamp(4, 16),
                      usesRounds: true,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int>(
              value: creator.draft.configuration.maxPlayers.clamp(4, 16),
              decoration: const InputDecoration(labelText: 'Maximum players'),
              items: [
                for (var n = 4; n <= 16; n++)
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
              onChanged: (value) {
                if (value == null) return;
                final min = creator.draft.configuration.minPlayers > value
                    ? value
                    : creator.draft.configuration.minPlayers;
                creator.update(
                  creator.draft.copyWith(
                    configuration: GameConfiguration(
                      minPlayers: min.clamp(4, 16),
                      maxPlayers: value,
                      usesRounds: true,
                    ),
                  ),
                );
              },
            ),
          ],
          if (creator.failure != null || _localError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(creator.failure?.message ?? _localError!),
          ],
          const SizedBox(height: AppSpacing.lg),
          PubgetPrimaryButton(
            onPressed: creator.saving || _saving ? null : () => _submit(context),
            semanticLabel: GameStrings.create,
            child: Text(
              creator.saving || _saving ? 'Creating…' : GameStrings.create,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final creator = context.read<GameCreateProvider>();
    setState(() => _localError = null);
    if (creator.draft.type == GameType.mafia) {
      final groupId = (widget.groupId ?? creator.draft.groupId ?? '').trim();
      if (groupId.isEmpty) {
        setState(() => _localError = 'Mafia must be created from a group.');
        return;
      }
      setState(() => _saving = true);
      final result = await context.read<MafiaProvider>().create(
        groupId: groupId,
        minPlayers: creator.draft.configuration.minPlayers,
        maxPlayers: creator.draft.configuration.maxPlayers,
      );
      if (!context.mounted) return;
      setState(() => _saving = false);
      final gameId = result.valueOrNull;
      if (gameId != null) {
        context.read<Analytics>().logEvent(
          'game_created',
          parameters: {'gameId': gameId, 'type': 'mafia'},
        );
        await AppNavigation.go(context, '/mafia/$gameId');
        return;
      }
      setState(
        () => _localError = result is FailureResult
            ? result.failure.message
            : 'Could not create Mafia.',
      );
      return;
    }
    final result = await creator.create();
    if (!context.mounted) return;
    final game = result.valueOrNull;
    if (game != null) {
      await AppNavigation.go(context, '/game/${game.id}');
    }
  }
}
