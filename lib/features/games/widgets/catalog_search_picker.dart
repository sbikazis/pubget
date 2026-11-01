import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/game_models.dart';
import '../providers/game_catalog_provider.dart';
import '../providers/game_providers.dart';

/// Searches the canonical catalog so a game can only ever submit a real
/// Anime or Character ID. Free text can never become game state, so this
/// picker is the only legal way to name a target.
class CatalogSearchPicker extends StatefulWidget {
  const CatalogSearchPicker({
    required this.hint,
    required this.onSelected,
    this.enabled = true,
    this.emptyLabel,
    super.key,
  });

  final String hint;
  final ValueChanged<CharacterSearchItem> onSelected;
  final bool enabled;
  final String? emptyLabel;

  @override
  State<CatalogSearchPicker> createState() => _CatalogSearchPickerState();
}

class _CatalogSearchPickerState extends State<CatalogSearchPicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<GameCatalogProvider>();
    final game = context.watch<GameProvider>();
    final disabled = !widget.enabled || game.busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PubgetSearchField(
          controller: _query,
          hint: widget.hint,
          enabled: !disabled,
          onChanged: catalog.queryCharacters,
          onClear: () {
            _query.clear();
            catalog.queryCharacters('');
          },
        ),
        if (catalog.searching) ...[
          const SizedBox(height: AppSpacing.sm),
          const PubgetSkeleton(height: 48),
        ],
        if (!catalog.searching &&
            catalog.characters.isEmpty &&
            catalog.characterQuery.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(widget.emptyLabel ?? 'No matches in the catalog.'),
        ],
        for (final item in catalog.characters)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: PubgetSecondaryButton(
              onPressed: disabled ? null : () => widget.onSelected(item),
              semanticLabel: item.name,
              child: Text(item.name),
            ),
          ),
        if (catalog.failure != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(catalog.failure!.message),
        ],
      ],
    );
  }
}
