import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/fan_work_copy.dart';
import '../models/fan_work_lifecycle.dart';
import '../models/fan_work_models.dart';
import '../models/fan_work_taxonomy.dart';
import '../providers/fan_work_providers.dart';

abstract final class FanWorkLinks {
  static const host = PubgetLinks.host;

  static String path(String workId) => PubgetLinks.fanWorkPath(workId);

  static String canonical(String workId) => PubgetLinks.fanWork(workId);

  static Future<void> copy(BuildContext context, String workId) =>
      PubgetLinks.copy(
        context,
        canonical(workId),
        type: 'fanWork',
        message: FanWorkCopy.of(context).copied,
      );

  static Future<void> share(
    BuildContext context,
    String workId, {
    String? title,
  }) => PubgetLinks.share(
    context,
    url: canonical(workId),
    title: title ?? FanWorkCopy.of(context).share,
    type: 'fanWork',
  );

  static void open(BuildContext context, String workId) {
    AppNavigation.go(context, path(workId));
  }
}

class FanWorkPreviewCard extends StatelessWidget {
  const FanWorkPreviewCard({required this.work, this.onTap, super.key});

  final FanWork work;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FanWorkPreviewTile(preview: work.preview, onTap: onTap);
  }
}

class FanWorkPreviewTile extends StatelessWidget {
  const FanWorkPreviewTile({required this.preview, this.onTap, super.key});

  final FanWorkPreview preview;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = FanWorkCopy.of(context);
    return Semantics(
      button: true,
      label: '${preview.title}, ${copy.typeLabel(preview.type)}',
      child: PubgetCard(
        onTap: onTap ?? () => FanWorkLinks.open(context, preview.id),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 3 / 4,
              child: preview.coverPath.isEmpty
                  ? ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.auto_awesome_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : AppImageLoader(
                      imageUrl: preview.coverPath,
                      fit: BoxFit.cover,
                      memCacheWidth: 360,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    preview.title.isEmpty ? copy.untitled : preview.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    copy.typeLabel(preview.type),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (preview.creatorName.isNotEmpty)
                    Text(
                      preview.creatorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FanWorkHomeStrip extends StatelessWidget {
  const FanWorkHomeStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FanWorkFeedProvider>();
    final copy = FanWorkCopy.of(context);
    if (feed.state == LoadingState.initial) {
      Future<void>.microtask(feed.load);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PubgetSectionHeader(
            title: AppStrings.of(context).sectionFanWorks,
            actionLabel: copy.seeAll,
            onAction: () => AppNavigation.go(context, '/fan-works'),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (feed.state == LoadingState.loading && feed.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PubgetSkeleton.card(width: double.infinity, height: 150),
            )
          else if (feed.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(copy.homeStripEmpty),
            )
          else
            SizedBox(
              height: 220,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                scrollDirection: Axis.horizontal,
                itemCount: feed.items.take(8).length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final work = feed.items[index];
                  return SizedBox(
                    width: 140,
                    child: FanWorkPreviewCard(work: work),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class FanWorkTagWrap extends StatelessWidget {
  const FanWorkTagWrap({required this.tags, super.key});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final tag in tags)
          PubgetSelectionChip(label: tag, selected: false, onSelected: null),
      ],
    );
  }
}

/// The fields every creatable type shares: the one required title/name, the
/// description (which is the character's story for [FanWorkType.character]), the
/// closed category list, the optional creator note, tags and anime link.
///
/// The draft is the source of truth while editing; nothing here talks to the
/// repository, so every keystroke stays local and cheap.
class CommonFanWorkFields extends StatelessWidget {
  const CommonFanWorkFields({
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final FanWorkDraft draft;
  final ValueChanged<FanWorkDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final copy = FanWorkCopy.of(context);
    final type = draft.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PubgetTextField(
          key: const Key('fan-work-title'),
          label: copy.titleLabel(type),
          hint: copy.titleHint(type),
          maxLength: FanWorkLifecycle.titleMax,
          controller: TextEditingController(text: draft.title)
            ..selection = TextSelection.collapsed(offset: draft.title.length),
          onChanged: (value) => onChanged(draft.copyWith(title: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextArea(
          key: const Key('fan-work-description'),
          label: copy.descriptionLabel(type),
          hint: copy.descriptionHint(type),
          maxLength: FanWorkLifecycle.descriptionMax,
          controller: TextEditingController(text: draft.description)
            ..selection = TextSelection.collapsed(
              offset: draft.description.length,
            ),
          onChanged: (value) => onChanged(draft.copyWith(description: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        if (FanWorkCategories.supportsCategory(type)) ...<Widget>[
          FanWorkCategoryPicker(
            type: type,
            selectedId: draft.categoryId,
            onSelected: (id) => onChanged(draft.copyWith(categoryId: id)),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        PubgetTextArea(
          key: const Key('fan-work-creator-note'),
          label: copy.creatorNoteLabel(type),
          hint: copy.creatorNoteHint,
          minLines: 2,
          maxLines: 4,
          maxLength: FanWorkLifecycle.creatorNoteMax,
          controller: TextEditingController(text: draft.creatorNote)
            ..selection = TextSelection.collapsed(
              offset: draft.creatorNote.length,
            ),
          onChanged: (value) => onChanged(draft.copyWith(creatorNote: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextField(
          key: const Key('fan-work-tags'),
          label: copy.tagsLabel,
          hint: copy.tagsHint,
          helperText: copy.tagsHelper,
          controller: TextEditingController(text: draft.tags.join(', '))
            ..selection = TextSelection.collapsed(
              offset: draft.tags.join(', ').length,
            ),
          onChanged: (value) => onChanged(
            draft.copyWith(
              tags: FanWorkLifecycle.normalizeTags(value.split(',')),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextField(
          key: const Key('fan-work-anime-id'),
          label: copy.relatedAnimeId,
          hint: copy.optionalAnimeIdentifier,
          controller: TextEditingController(text: draft.animeId)
            ..selection = TextSelection.collapsed(offset: draft.animeId.length),
          onChanged: (value) =>
              onChanged(draft.copyWith(animeId: value.trim())),
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextField(
          key: const Key('fan-work-anime-title'),
          label: copy.relatedAnimeTitle,
          hint: copy.optionalDisplayTitle,
          controller: TextEditingController(text: draft.animeTitle)
            ..selection = TextSelection.collapsed(
              offset: draft.animeTitle.length,
            ),
          onChanged: (value) =>
              onChanged(draft.copyWith(animeTitle: value.trim())),
        ),
      ],
    );
  }
}

/// The closed category list for a type. It is a picker rather than a free-text
/// field on purpose: the server rejects anything outside the list, so letting a
/// creator type one would only produce a publish-time failure.
class FanWorkCategoryPicker extends StatelessWidget {
  const FanWorkCategoryPicker({
    required this.type,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final FanWorkType type;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final copy = FanWorkCopy.of(context);
    final categories = FanWorkCategories.forType(type);
    if (categories.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(copy.category, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(copy.categoryHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final category in categories)
              PubgetSelectionChip(
                key: Key('fan-work-category-${category.id}'),
                label: category.label(arabic: _isArabic(context)),
                selected: category.id == selectedId,
                onSelected: (_) => onSelected(category.id),
              ),
          ],
        ),
      ],
    );
  }

  static bool _isArabic(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';
}

/// A read-only slot that shows what is already attached to a work and hands the
/// pick/replace/remove actions back to the editor screen.
class FanWorkFileSlot extends StatelessWidget {
  const FanWorkFileSlot({
    required this.title,
    required this.hint,
    required this.emptyLabel,
    required this.pickLabel,
    required this.onPick,
    this.icon = Icons.image_outlined,
    this.secondaryIcon,
    this.secondaryLabel = '',
    this.onSecondary,
    this.onRemove,
    this.preview,
    this.trailingLabel = '',
    super.key,
  });

  final String title;
  final String hint;
  final String emptyLabel;
  final String pickLabel;
  final VoidCallback onPick;
  final IconData icon;
  final IconData? secondaryIcon;
  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback? onRemove;
  final Widget? preview;
  final String trailingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              if (trailingLabel.isNotEmpty)
                Text(trailingLabel, style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(hint, style: theme.textTheme.bodySmall),
          if (preview != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            preview!,
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              PubgetSecondaryButton(
                onPressed: onPick,
                semanticLabel: pickLabel,
                leadingIcon: icon,
                child: Text(pickLabel),
              ),
              if (onSecondary != null && secondaryIcon != null)
                PubgetSecondaryButton(
                  onPressed: onSecondary,
                  semanticLabel: secondaryLabel,
                  leadingIcon: secondaryIcon,
                  child: Text(secondaryLabel),
                ),
              if (onRemove != null)
                PubgetTextButton(
                  onPressed: onRemove,
                  semanticLabel: FanWorkCopy.of(context).removeFile,
                  child: Text(FanWorkCopy.of(context).removeFile),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The manga and story reading file: one PDF, replaced wholesale rather than
/// edited page by page. Page captions do not exist in this format, so the whole
/// pre-rebuild page editor is intentionally gone.
class FanWorkDocumentEditor extends StatelessWidget {
  const FanWorkDocumentEditor({
    required this.draft,
    required this.work,
    required this.onPick,
    super.key,
  });

  final FanWorkDraft draft;
  final FanWork? work;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final copy = FanWorkCopy.of(context);
    final document = work?.content.document;
    final pages = document?.pageCount ?? 0;
    return FanWorkFileSlot(
      key: const Key('fan-work-document-slot'),
      title: copy.documentLabel(draft.type),
      hint: copy.documentHint(draft.type),
      emptyLabel: copy.choosePdf,
      pickLabel: document == null ? copy.choosePdf : copy.replacePdf,
      onPick: onPick,
      icon: Icons.picture_as_pdf_outlined,
      trailingLabel: pages > 0 ? copy.pagesCount(pages) : '',
      preview: document == null
          ? null
          : Row(
              children: <Widget>[
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    copy.documentProtectedHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
    );
  }
}

/// The single artwork of a drawing.
class FanWorkArtworkEditor extends StatelessWidget {
  const FanWorkArtworkEditor({
    required this.work,
    required this.onPick,
    super.key,
  });

  final FanWork? work;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final copy = FanWorkCopy.of(context);
    final artwork = work?.content.artwork;
    return FanWorkFileSlot(
      key: const Key('fan-work-artwork-slot'),
      title: copy.artworkSlotTitle,
      hint: copy.drawingImage,
      emptyLabel: copy.chooseDrawing,
      pickLabel: artwork == null ? copy.chooseDrawing : copy.replaceFile,
      onPick: onPick,
      icon: Icons.brush_outlined,
      preview: artwork == null
          ? null
          : SizedBox(
              height: 180,
              child: AppImageLoader(
                imageUrl: artwork.path,
                fit: BoxFit.contain,
              ),
            ),
    );
  }
}

/// The portrait of a character work, plus its category-specific fields.
class FanWorkCharacterEditor extends StatelessWidget {
  const FanWorkCharacterEditor({
    required this.draft,
    required this.work,
    required this.onChanged,
    required this.onPickPortrait,
    super.key,
  });

  final FanWorkDraft draft;
  final FanWork? work;
  final ValueChanged<FanWorkDraft> onChanged;
  final VoidCallback onPickPortrait;

  @override
  Widget build(BuildContext context) {
    final copy = FanWorkCopy.of(context);
    final portrait = work?.content.portrait;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (draft.origin == FanWorkOrigin.aiGenerated) ...<Widget>[
          Row(
            children: <Widget>[
              PubgetSelectionChip(
                label: copy.originAi,
                selected: true,
                onSelected: null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            copy.aiAssistedNotice,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        FanWorkFileSlot(
          key: const Key('fan-work-portrait-slot'),
          title: copy.portraitSlotTitle,
          hint: copy.choosePortrait,
          emptyLabel: copy.choosePortrait,
          pickLabel: portrait == null ? copy.choosePortrait : copy.replaceFile,
          onPick: onPickPortrait,
          icon: Icons.face_outlined,
          preview: portrait == null
              ? null
              : SizedBox(
                  height: 180,
                  child: AppImageLoader(
                    imageUrl: portrait.path,
                    fit: BoxFit.contain,
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextArea(
          key: const Key('fan-work-character-personality'),
          label: copy.characterPersonality,
          hint: copy.characterStoryHint,
          minLines: 2,
          maxLines: 5,
          maxLength: FanWorkLifecycle.maxPersonality,
          controller: TextEditingController(text: draft.personality)
            ..selection = TextSelection.collapsed(
              offset: draft.personality.length,
            ),
          onChanged: (value) => onChanged(draft.copyWith(personality: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextArea(
          key: const Key('fan-work-character-abilities'),
          label: copy.characterAbilities,
          hint: copy.characterAbilitiesOptional,
          minLines: 2,
          maxLines: 5,
          maxLength: FanWorkLifecycle.maxAbilities,
          controller: TextEditingController(text: draft.abilities)
            ..selection = TextSelection.collapsed(
              offset: draft.abilities.length,
            ),
          onChanged: (value) => onChanged(draft.copyWith(abilities: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextArea(
          key: const Key('fan-work-character-specs'),
          label: copy.characterSpecs,
          hint: copy.characterSpecsOptional,
          minLines: 2,
          maxLines: 5,
          maxLength: FanWorkLifecycle.maxSpecs,
          controller: TextEditingController(text: draft.specs)
            ..selection = TextSelection.collapsed(offset: draft.specs.length),
          onChanged: (value) => onChanged(draft.copyWith(specs: value)),
        ),
      ],
    );
  }
}

/// The `+` sheet a manga or story creator uses to collect the characters that
/// appear in the work: optional portrait, required name, optional bio, reorder
/// and remove. The list is capped at [FanWorkLifecycle.maxCharacters] so the
/// document cannot grow past what a reader will scroll.
class FanWorkCastEditor extends StatelessWidget {
  const FanWorkCastEditor({
    required this.characters,
    required this.onChanged,
    this.onEdit,
    super.key,
  });

  final List<FanWorkCharacter> characters;
  final ValueChanged<List<FanWorkCharacter>> onChanged;

  /// Opens the detail sheet for one member. When null the list is
  /// reorder/remove only, which is what a read-only viewer shows.
  final ValueChanged<FanWorkCharacter>? onEdit;

  @override
  Widget build(BuildContext context) {
    final copy = FanWorkCopy.of(context);
    final ordered = [...characters]..sort((a, b) => a.index.compareTo(b.index));
    final atLimit = ordered.length >= FanWorkLifecycle.maxCharacters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                copy.cast,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              copy.charactersCount(ordered.length),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (ordered.isEmpty)
          Text(
            copy.castEmptyMessage,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          for (final entry in ordered)
            _CastEntryTile(
              entry: entry,
              onEdit: onEdit == null ? null : () => onEdit!(entry),
              canMoveUp: entry.index > 0,
              canMoveDown: entry.index < ordered.length - 1,
              onMoveUp: () => _reorder(entry.index, entry.index - 1),
              onMoveDown: () => _reorder(entry.index, entry.index + 1),
              onRemove: () => onChanged(
                ordered.where((item) => item.id != entry.id).toList()
                  ..sort((a, b) => a.index.compareTo(b.index)),
              ),
            ),
        const SizedBox(height: AppSpacing.sm),
        if (atLimit)
          Text(
            copy.castLimitReached,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          PubgetSecondaryButton(
            key: const Key('fan-work-add-character'),
            onPressed: () => onChanged(<FanWorkCharacter>[
              ...ordered,
              FanWorkCharacter(
                id: 'char-${DateTime.now().microsecondsSinceEpoch}',
                name: '',
                index: ordered.length,
              ),
            ]),
            semanticLabel: copy.addCharacter,
            leadingIcon: Icons.person_add_alt_outlined,
            child: Text(copy.addCharacter),
          ),
      ],
    );
  }

  void _reorder(int from, int to) {
    final next = [...characters]..sort((a, b) => a.index.compareTo(b.index));
    if (to < 0 || to >= next.length) return;
    final moved = next.removeAt(from);
    next.insert(to, moved);
    onChanged(<FanWorkCharacter>[
      for (var i = 0; i < next.length; i++) next[i].copyWith(index: i),
    ]);
  }
}

class _CastEntryTile extends StatelessWidget {
  const _CastEntryTile({
    required this.entry,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    this.onEdit,
  });

  final FanWorkCharacter entry;
  final VoidCallback? onEdit;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final copy = FanWorkCopy.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        onTap: onEdit,
        child: PubgetCard(
          child: Row(
            children: <Widget>[
              if (entry.hasImage)
                SizedBox(
                  width: 44,
                  height: 44,
                  child: AppImageLoader(
                    imageUrl: entry.imagePath,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Icon(
                  Icons.person_outline,
                  color: Theme.of(context).colorScheme.outline,
                ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.name.isEmpty ? copy.characterName : entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (entry.bio.isNotEmpty)
                      Text(
                        entry.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: copy.moveUp,
                onPressed: canMoveUp ? onMoveUp : null,
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: copy.moveDown,
                onPressed: canMoveDown ? onMoveDown : null,
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: copy.removeCharacter,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dispatches to the editor for the four creatable types.
///
/// The two legacy-only types are absent on purpose: they are read-only now, so
/// the editor can never be asked to produce one.
class FanWorkTypeEditor extends StatelessWidget {
  const FanWorkTypeEditor({
    required this.draft,
    required this.work,
    required this.onChanged,
    required this.onPickDocument,
    required this.onPickArtwork,
    required this.onPickPortrait,
    this.onEditCharacter,
    super.key,
  });

  final FanWorkDraft draft;
  final FanWork? work;
  final ValueChanged<FanWorkDraft> onChanged;
  final VoidCallback onPickDocument;
  final VoidCallback onPickArtwork;
  final VoidCallback onPickPortrait;
  final ValueChanged<FanWorkCharacter>? onEditCharacter;

  @override
  Widget build(BuildContext context) {
    return switch (draft.type) {
      FanWorkType.manga || FanWorkType.story => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FanWorkDocumentEditor(
            draft: draft,
            work: work,
            onPick: onPickDocument,
          ),
          const SizedBox(height: AppSpacing.md),
          FanWorkCastEditor(
            characters: draft.characters,
            onChanged: (characters) =>
                onChanged(draft.copyWith(characters: characters)),
            onEdit: onEditCharacter,
          ),
        ],
      ),
      FanWorkType.drawing => FanWorkArtworkEditor(
        work: work,
        onPick: onPickArtwork,
      ),
      FanWorkType.character => FanWorkCharacterEditor(
        draft: draft,
        work: work,
        onChanged: onChanged,
        onPickPortrait: onPickPortrait,
      ),
      // Read-only types: render nothing rather than an editor that could not
      // save. An edit screen is only ever opened for a creatable type.
      FanWorkType.worldbuilding || FanWorkType.other => const SizedBox.shrink(),
    };
  }
}
