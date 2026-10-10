import 'package:flutter/material.dart';

class PubgetSelectionChip extends StatelessWidget {
  const PubgetSelectionChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: true,
    );
  }
}

/// A read-only chip used to present a label or tag.
///
/// Unlike [PubgetSelectionChip] it is deliberately not tappable, so an
/// informational tag never looks like a filter the user can toggle.
class PubgetInfoChip extends StatelessWidget {
  const PubgetInfoChip({required this.label, this.icon, super.key});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: icon == null ? null : Icon(icon, size: 16),
      label: Text(label),
      labelStyle: theme.textTheme.labelMedium,
      side: BorderSide(color: theme.colorScheme.outlineVariant),
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.4,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
