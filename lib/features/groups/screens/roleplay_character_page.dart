import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/group_copy.dart';
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
    final copy = GroupCopy.of(context);
    final provider = context.watch<RoleplayProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.roleplayCharacterTitle),
      ),
      body: PubgetLoadingStateView(
        state: provider.state,
        onRetry: () => provider.load(widget.groupId),
        empty: PubgetEmptyState(
          key: const Key('group-roleplay-empty'),
          title: copy.roleplayNoCharacters,
          message: copy.roleplayAllReserved,
          icon: Icons.person_off_outlined,
        ),
        error: PubgetErrorState(
          key: const Key('group-roleplay-error'),
          message: provider.failure?.message ?? copy.roleplayCharactersLoadFailed,
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
              key: Key('group-roleplay-character-${character.key}'),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  PubgetAvatar(name: character.name),
                  const SizedBox(height: AppSpacing.sm),
                  Text(character.name),
                  const SizedBox(height: AppSpacing.md),
                  PubgetPrimaryButton(
                    key: Key('group-roleplay-reserve-${character.key}'),
                    onPressed: () =>
                        provider.reserve(widget.groupId, character),
                    semanticLabel: '${copy.reserveCharacter} ${character.name}',
                    child: Text(copy.reserveCharacter),
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