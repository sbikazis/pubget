import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/group_copy.dart';

/// Titles a founder can start a search from, used only while the search field
/// is empty. They are search shortcuts, not results: tapping one runs the same
/// server search the field runs, so nothing here can be mistaken for a title
/// the catalog actually holds.
const catalogStarterAnimeSearches = <String>[
  'Naruto',
  'One Piece',
  'Bleach',
  'Attack on Titan',
  'Jujutsu Kaisen',
  'Demon Slayer',
  'Dragon Ball',
  'Death Note',
];

/// The same idea for a group that draws from the whole character catalog.
/// A group bound to one work is not given these: its roster is filtered to that
/// work server-side, so a name from another series would only ever miss.
const catalogStarterCharacterSearches = <String>[
  'Monkey D. Luffy',
  'Naruto Uzumaki',
  'Ichigo Kurosaki',
  'Light Yagami',
  'Edward Elric',
  'Tanjiro Kamado',
  'Levi Ackerman',
  'Goku',
];

/// What a catalog picker shows while its search field is still empty and there
/// is nothing browsable to show.
///
/// The search itself is server-backed and fast, so an empty field must never
/// read as a broken feature: the page opens on an invitation to type, plus a
/// row of one-tap searches that land on real results. A browse that failed
/// before anything was typed is reported here as one quiet line with a retry,
/// rather than as an error screen that replaces the whole page.
///
/// The "no results" state is deliberately absent. It belongs to a search the
/// user actually ran.
class CatalogStarterList extends StatelessWidget {
  const CatalogStarterList({
    required this.subtitle,
    this.seeds = const <String>[],
    this.onPick,
    this.notice,
    this.onRetry,
    super.key,
  });

  /// Explains what typing will do, in the picker's own wording.
  final String subtitle;

  /// One-tap searches. Empty when the catalog scope cannot answer them.
  final List<String> seeds;
  final ValueChanged<String>? onPick;

  /// A quiet line about the browse that could not be read, if there was one.
  final String? notice;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = GroupCopy.of(context);
    final notice = this.notice;
    final pick = onPick;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: <Widget>[
        if (notice != null) ...<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.cloud_off_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  notice,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                key: const Key('catalog-starter-retry'),
                onPressed: onRetry,
                child: Text(copy.retry),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Icon(Icons.search, size: 32, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.sm),
        Text(subtitle, style: theme.textTheme.titleSmall),
        if (seeds.isNotEmpty && pick != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(copy.startFromThese, style: theme.textTheme.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final seed in seeds)
                PubgetSelectionChip(
                  key: Key('catalog-starter-seed-$seed'),
                  label: seed,
                  selected: false,
                  onSelected: (_) => pick(seed),
                ),
            ],
          ),
        ],
      ],
    );
  }
}