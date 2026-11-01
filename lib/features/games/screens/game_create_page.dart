import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/analytics/analytics.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../mafia/models/mafia_models.dart';
import '../../mafia/providers/mafia_provider.dart';
import '../l10n/game_copy.dart';
import '../models/game_models.dart';
import '../models/game_type_registry.dart';
import '../providers/game_providers.dart';

class GameCreatePage extends StatefulWidget {
  const GameCreatePage({
    this.groupId,
    this.creationSource = 'unknown',
    this.initialType,
    super.key,
  });

  final String? groupId;
  final String creationSource;

  /// Set when the Game Center "Available Games" list opens a specific game.
  final GameType? initialType;

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
    final creator = context.read<GameCreateProvider>();
    final groupId = widget.groupId;
    final type = widget.initialType;
    Future<void>.microtask(() {
      creator.start(groupId: groupId, creationSource: widget.creationSource);
      if (type != null) creator.selectType(type);
    });
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
    final copy = GameCopy.of(context);
    // Every implemented type is offered (Spec 12.1 lists all four games as
    // always available). Mafia branches to createMafiaGame in _submit
    // instead of the generic createGame, which is why its card carries
    // genericCreate: false while still being listed here.
    final types = GameTypeRegistry.all;
    final spec = GameTypeRegistry.of(creator.draft.type);
    final quiz = spec.capabilities.usesRounds && spec.capabilities.usesScoring;
    final isMafia = creator.draft.type == GameType.mafia;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.createGame),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Text(
            copy.gameTypeTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final item in types)
                PubgetSelectionChip(
                  label: item.name,
                  selected: creator.draft.type == item.type,
                  onSelected: (_) => creator.selectType(item.type),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(spec.description),
          Text(
            copy.playerRange(
              spec.capabilities.minPlayers,
              spec.capabilities.maxPlayers,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            controller: _title,
            label: copy.titleLabel,
            onChanged: (value) =>
                creator.update(creator.draft.copyWith(title: value)),
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextArea(
            controller: _description,
            label: copy.descriptionLabel,
            onChanged: (value) =>
                creator.update(creator.draft.copyWith(description: value)),
          ),
          if (quiz) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              copy.rulesTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              value: creator.draft.configuration.difficulty,
              decoration: InputDecoration(labelText: copy.difficultyTitle),
              items: [
                DropdownMenuItem(
                  value: 'easy',
                  child: Text(copy.difficulty('easy')),
                ),
                DropdownMenuItem(
                  value: 'normal',
                  child: Text(copy.difficulty('normal')),
                ),
                DropdownMenuItem(
                  value: 'hard',
                  child: Text(copy.difficulty('hard')),
                ),
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
              decoration: InputDecoration(labelText: copy.roundsLabel),
              items: [
                for (final rounds in const [3, 5, 7])
                  DropdownMenuItem(
                    value: rounds,
                    child: Text(copy.roundsOption(rounds)),
                  ),
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
              decoration: InputDecoration(labelText: copy.timerLabel),
              items: [
                for (final seconds in const [15, 20, 30])
                  DropdownMenuItem(
                    value: seconds,
                    child: Text(copy.secondsOption(seconds)),
                  ),
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
            Text(
              copy.lobbyTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int>(
              value: creator.draft.configuration.minPlayers.clamp(
                MafiaLimits.minPlayers,
                MafiaLimits.maxPlayers,
              ),
              decoration: InputDecoration(labelText: copy.minPlayersLabel),
              items: [
                for (
                  var n = MafiaLimits.minPlayers;
                  n <= MafiaLimits.maxPlayers;
                  n++
                )
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
                      maxPlayers: max.clamp(
                        MafiaLimits.minPlayers,
                        MafiaLimits.maxPlayers,
                      ),
                      usesRounds: true,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int>(
              value: creator.draft.configuration.maxPlayers.clamp(
                MafiaLimits.minPlayers,
                MafiaLimits.maxPlayers,
              ),
              decoration: InputDecoration(labelText: copy.maxPlayersLabel),
              items: [
                for (
                  var n = MafiaLimits.minPlayers;
                  n <= MafiaLimits.maxPlayers;
                  n++
                )
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
                      minPlayers: min.clamp(
                        MafiaLimits.minPlayers,
                        MafiaLimits.maxPlayers,
                      ),
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
            onPressed: creator.saving || _saving
                ? null
                : () => _submit(context),
            semanticLabel: copy.createGame,
            child: Text(
              creator.saving || _saving ? copy.creating : copy.createGame,
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
        setState(() => _localError = GameCopy.of(context).mafiaNeedsGroup);
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
        () => _localError =
            result.failureOrNull?.message ??
            GameCopy.of(context).mafiaCreateFailed,
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
