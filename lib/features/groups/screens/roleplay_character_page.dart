import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../providers/roleplay_provider.dart';

class RoleplayCharacterPage extends StatefulWidget {
  const RoleplayCharacterPage({required this.groupId, super.key});

  final String groupId;

  @override
  State<RoleplayCharacterPage> createState() => _RoleplayCharacterPageState();
}

class _RoleplayCharacterPageState extends State<RoleplayCharacterPage> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<RoleplayProvider>();
    Future<void>.microtask(() => provider.load(widget.groupId));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoleplayProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a character')),
      body: PubgetLoadingStateView(
        state: provider.state,
        onRetry: () => provider.load(widget.groupId),
        empty: const PubgetEmptyState(
          title: 'No characters available',
          message: 'All mock characters may already be reserved.',
        ),
        error: PubgetErrorState(
          message: provider.failure?.message ?? 'Characters could not load.',
          onRetry: () => provider.load(widget.groupId),
        ),
        offline: PubgetOfflineState(
          onRetry: () => provider.load(widget.groupId),
        ),
        child: GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
          ),
          itemCount: provider.characters.length,
          itemBuilder: (context, index) {
            final character = provider.characters[index];
            return PubgetCard(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  PubgetAvatar(name: character.name),
                  const SizedBox(height: AppSpacing.sm),
                  Text(character.name),
                  const SizedBox(height: AppSpacing.md),
                  PubgetPrimaryButton(
                    onPressed: () =>
                        provider.reserve(widget.groupId, character),
                    semanticLabel: 'Reserve ${character.name}',
                    child: const Text('Reserve'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
