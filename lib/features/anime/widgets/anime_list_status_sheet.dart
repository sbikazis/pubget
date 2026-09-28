import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_buttons.dart';
import '../l10n/anime_copy.dart';
import '../models/anime_list_models.dart';
import '../providers/anime_library_provider.dart';
import '../theme/anime_hub_colors.dart';

/// Opens the "add to my list" sheet.
///
/// The five statuses never sit inline on the details page. They live here, with
/// the current selection preselected, the member's own rating editable in the
/// same flow, and a remove action at the bottom for an entry that already
/// exists.
Future<void> showAnimeListStatusSheet(
  BuildContext context, {
  required String animeId,
  required String title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) =>
        _AnimeListStatusSheet(animeId: animeId, title: title),
  );
}

class _AnimeListStatusSheet extends StatefulWidget {
  const _AnimeListStatusSheet({required this.animeId, required this.title});

  final String animeId;
  final String title;

  @override
  State<_AnimeListStatusSheet> createState() => _AnimeListStatusSheetState();
}

class _AnimeListStatusSheetState extends State<_AnimeListStatusSheet> {
  late AnimeListStatus _pending = _entry?.status ?? AnimeListStatus.watching;

  AnimeListEntry? get _entry =>
      maybeAnimeLibrary(context)?.entryFor(widget.animeId);

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    final theme = Theme.of(context);
    final hub = AnimeHubColors.of(context);
    final library = maybeAnimeLibrary(context);
    final entry = _entry;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(copy.listStatus, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final status in AnimeListStatus.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _StatusOption(
                  status: status,
                  selected: _pending == status,
                  accent: hub.gold,
                  onTap: library == null || library.saving
                      ? null
                      : () => setState(() => _pending = status),
                ),
              ),
            if (entry != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _ListRatingField(
                entry: entry,
                enabled: library != null && !library.saving,
                onChanged: (value) => library?.setStatus(
                  animeId: widget.animeId,
                  status: _pending,
                  title: widget.title,
                  rating: value,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            PubgetPrimaryButton(
              key: const Key('anime-list-save'),
              semanticLabel: copy.save,
              onPressed: library == null || library.saving
                  ? null
                  : () async {
                      await library.setStatus(
                        animeId: widget.animeId,
                        status: _pending,
                        title: widget.title,
                        rating: entry?.rating,
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    },
              child: Text(copy.save),
            ),
            if (entry != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              PubgetTextButton(
                key: const Key('anime-list-remove'),
                semanticLabel: copy.removeFromList,
                onPressed: library == null || library.saving
                    ? null
                    : () async {
                        await library.remove(widget.animeId);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                child: Text(copy.removeFromList),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.status,
    required this.selected,
    required this.onTap,
    required this.accent,
  });

  final AnimeListStatus status;
  final bool selected;
  final VoidCallback? onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.16)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected ? accent : theme.disabledColor,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              copy.listStatusLabel(status),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? accent : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the member score the entry while they are inside the sheet. Tapping the
/// active star clears the rating.
class _ListRatingField extends StatelessWidget {
  const _ListRatingField({
    required this.entry,
    required this.onChanged,
    required this.enabled,
  });

  final AnimeListEntry entry;
  final ValueChanged<int?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    final theme = Theme.of(context);
    final gold = AnimeHubColors.of(context).gold;
    final current = entry.rating ?? 0;
    return Row(
      children: <Widget>[
        Icon(Icons.star_outline, size: 18, color: theme.disabledColor),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            copy.myRating,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (var score = 1; score <= 5; score++)
          IconButton(
            onPressed: enabled
                ? () => onChanged(entry.rating == score ? null : score)
                : null,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              score <= current ? Icons.star : Icons.star_border,
              size: 20,
              color: score <= current ? gold : theme.disabledColor,
            ),
          ),
      ],
    );
  }
}
