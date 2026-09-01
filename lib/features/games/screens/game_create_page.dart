import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../mafia/mafia_config.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text(GameStrings.create)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Text('Game type', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final spec in types)
            RadioListTile<GameType>(
              value: spec.type,
              groupValue: creator.draft.type,
              title: Text(spec.name),
              subtitle: Text(spec.description),
              onChanged: (value) {
                if (value == null) return;
                final spec = GameTypeRegistry.of(value);
                creator.update(
                  creator.draft.copyWith(
                    type: value,
                    configuration: GameConfiguration(
                      minPlayers: spec.capabilities.minPlayers,
                      maxPlayers: spec.capabilities.maxPlayers,
                      usesRounds: spec.capabilities.usesRounds,
                      extra: value == GameType.mafia
                          ? const MafiaConfig().toExtra()
                          : const <String, dynamic>{},
                    ),
                  ),
                );
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
          if (creator.failure != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(creator.failure!.message),
          ],
          const SizedBox(height: AppSpacing.lg),
          PubgetPrimaryButton(
            onPressed: creator.saving
                ? null
                : () async {
                    final result = await creator.create();
                    if (!context.mounted) return;
                    final game = result.valueOrNull;
                    if (game != null) {
                      await AppNavigation.go(context, '/game/${game.id}');
                    }
                  },
            semanticLabel: GameStrings.create,
            child: Text(creator.saving ? 'Creating…' : GameStrings.create),
          ),
        ],
      ),
    );
  }
}
