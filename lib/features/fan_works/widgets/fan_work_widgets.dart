import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/fan_work_lifecycle.dart';
import '../models/fan_work_models.dart';
import '../providers/fan_work_providers.dart';

abstract final class FanWorkLinks {
  static const host = PubgetLinks.host;

  static String path(String workId) => PubgetLinks.fanWorkPath(workId);

  static String canonical(String workId) => PubgetLinks.fanWork(workId);

  @visibleForTesting
  static Future<void> Function(String text, String? subject)? get debugNativeShare =>
      PubgetLinks.debugNativeShare;

  @visibleForTesting
  static set debugNativeShare(
    Future<void> Function(String text, String? subject)? value,
  ) => PubgetLinks.debugNativeShare = value;

  static Future<void> copy(BuildContext context, String workId) =>
      PubgetLinks.copy(
        context,
        canonical(workId),
        type: 'fanWork',
        message: FanWorkStrings.copied,
      );

  static Future<void> share(
    BuildContext context,
    String workId, {
    String? title,
  }) => PubgetLinks.share(
    context,
    url: canonical(workId),
    title: title ?? FanWorkStrings.share,
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
    return Semantics(
      button: true,
      label: '${preview.title}, ${FanWorkTypeCatalog.label(preview.type)}',
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
                    preview.title.isEmpty ? 'Untitled' : preview.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    FanWorkTypeCatalog.label(preview.type),
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
    if (feed.state == LoadingState.initial) {
      Future<void>.microtask(feed.load);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    FanWorkStrings.feedTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                PubgetTextButton(
                  onPressed: () => AppNavigation.go(context, '/fan-works'),
                  semanticLabel: FanWorkStrings.seeAll,
                  child: const Text(FanWorkStrings.seeAll),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (feed.state == LoadingState.loading && feed.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PubgetSkeleton.card(width: double.infinity, height: 150),
            )
          else if (feed.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('Fan Works will appear here after they are published.'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PubgetTextField(
          key: const Key('fan-work-title'),
          label: 'Title',
          hint: 'Give this work a name',
          controller: TextEditingController(text: draft.title)
            ..selection = TextSelection.collapsed(offset: draft.title.length),
          onChanged: (value) => onChanged(draft.copyWith(title: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextArea(
          key: const Key('fan-work-description'),
          label: 'Description',
          hint: 'What is this work about?',
          controller: TextEditingController(text: draft.description)
            ..selection = TextSelection.collapsed(
              offset: draft.description.length,
            ),
          onChanged: (value) => onChanged(draft.copyWith(description: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextField(
          key: const Key('fan-work-tags'),
          label: 'Tags',
          hint: 'demonslayer, tanjiro, drawing',
          helperText: 'Up to 8 tags. Hashtags are normalized.',
          controller: TextEditingController(text: draft.tags.join(', '))
            ..selection = TextSelection.collapsed(
              offset: draft.tags.join(', ').length,
            ),
          onChanged: (value) => onChanged(
            draft.copyWith(tags: FanWorkLifecycle.normalizeTags(value.split(','))),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextField(
          key: const Key('fan-work-anime-id'),
          label: 'Related anime ID',
          hint: 'Optional anime identifier',
          controller: TextEditingController(text: draft.animeId)
            ..selection = TextSelection.collapsed(offset: draft.animeId.length),
          onChanged: (value) => onChanged(draft.copyWith(animeId: value.trim())),
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextField(
          key: const Key('fan-work-anime-title'),
          label: 'Related anime title',
          hint: 'Optional display title',
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

class MangaEditor extends StatelessWidget {
  const MangaEditor({
    required this.work,
    required this.draft,
    required this.onChanged,
    required this.onAddPage,
    super.key,
  });

  final FanWork? work;
  final FanWorkDraft draft;
  final ValueChanged<FanWorkDraft> onChanged;
  final VoidCallback onAddPage;

  @override
  Widget build(BuildContext context) {
    final pages = work?.content.orderedPages ?? const <FanWorkPage>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Pages', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final page in pages)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 48,
              height: 64,
              child: AppImageLoader(imageUrl: page.path, fit: BoxFit.cover),
            ),
            title: Text('Page ${page.index + 1}'),
            subtitle: PubgetTextField(
              hint: 'Optional caption',
              controller: TextEditingController(text: page.caption)
                ..selection = TextSelection.collapsed(
                  offset: page.caption.length,
                ),
              onChanged: (value) {
                final captions = Map<String, String>.from(draft.pageCaptions)
                  ..[page.mediaId] = value;
                onChanged(draft.copyWith(pageCaptions: captions));
              },
            ),
          ),
        PubgetSecondaryButton(
          onPressed: onAddPage,
          semanticLabel: 'Add manga page',
          leadingIcon: Icons.add_photo_alternate_outlined,
          child: const Text('Add page'),
        ),
      ],
    );
  }
}

class DrawingEditor extends StatelessWidget {
  const DrawingEditor({
    required this.work,
    required this.onAddImage,
    super.key,
  });

  final FanWork? work;
  final VoidCallback onAddImage;

  @override
  Widget build(BuildContext context) {
    final images = [
      if (work?.cover != null) work!.cover!,
      ...?work?.content.images,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Images', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final image in images)
              SizedBox(
                width: 96,
                height: 96,
                child: AppImageLoader(imageUrl: image.path, fit: BoxFit.cover),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        PubgetSecondaryButton(
          onPressed: onAddImage,
          semanticLabel: 'Add drawing image',
          leadingIcon: Icons.add_photo_alternate_outlined,
          child: const Text('Add image'),
        ),
      ],
    );
  }
}

class StoryEditor extends StatelessWidget {
  const StoryEditor({
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final FanWorkDraft draft;
  final ValueChanged<FanWorkDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Chapters', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < draft.chapters.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: PubgetCard(
              child: Column(
                children: <Widget>[
                  PubgetTextField(
                    label: 'Chapter title',
                    controller:
                        TextEditingController(text: draft.chapters[i].title)
                          ..selection = TextSelection.collapsed(
                            offset: draft.chapters[i].title.length,
                          ),
                    onChanged: (value) {
                      final chapters = [...draft.chapters];
                      chapters[i] = chapters[i].copyWith(title: value);
                      onChanged(draft.copyWith(chapters: chapters));
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PubgetTextArea(
                    label: 'Chapter text',
                    minLines: 4,
                    maxLines: 8,
                    controller:
                        TextEditingController(text: draft.chapters[i].body)
                          ..selection = TextSelection.collapsed(
                            offset: draft.chapters[i].body.length,
                          ),
                    onChanged: (value) {
                      final chapters = [...draft.chapters];
                      chapters[i] = chapters[i].copyWith(body: value);
                      onChanged(draft.copyWith(chapters: chapters));
                    },
                  ),
                ],
              ),
            ),
          ),
        PubgetSecondaryButton(
          onPressed: () {
            final chapters = [
              ...draft.chapters,
              FanWorkChapter(
                id: 'ch-${draft.chapters.length + 1}',
                title: '',
                body: '',
                index: draft.chapters.length,
              ),
            ];
            onChanged(draft.copyWith(chapters: chapters));
          },
          semanticLabel: 'Add chapter',
          leadingIcon: Icons.add,
          child: const Text('Add chapter'),
        ),
      ],
    );
  }
}

class CharacterEditor extends StatelessWidget {
  const CharacterEditor({
    required this.draft,
    required this.work,
    required this.onChanged,
    required this.onAddImage,
    this.aiAssisted = false,
    super.key,
  });

  final FanWorkDraft draft;
  final FanWork? work;
  final ValueChanged<FanWorkDraft> onChanged;
  final VoidCallback onAddImage;
  final bool aiAssisted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (aiAssisted) ...[
          PubgetSelectionChip(
            label: FanWorkStrings.aiAssisted,
            selected: true,
            onSelected: null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This work is labeled as AI-assisted. Pubget does not generate the character in this version.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        PubgetTextField(
          key: const Key('fan-work-character-name'),
          label: 'Name',
          controller: TextEditingController(text: draft.name)
            ..selection = TextSelection.collapsed(offset: draft.name.length),
          onChanged: (value) => onChanged(draft.copyWith(name: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextArea(
          label: 'Personality',
          controller: TextEditingController(text: draft.personality)
            ..selection = TextSelection.collapsed(
              offset: draft.personality.length,
            ),
          onChanged: (value) => onChanged(draft.copyWith(personality: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextArea(
          label: 'Abilities',
          controller: TextEditingController(text: draft.abilities)
            ..selection = TextSelection.collapsed(
              offset: draft.abilities.length,
            ),
          onChanged: (value) => onChanged(draft.copyWith(abilities: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        PubgetTextArea(
          label: 'Background',
          controller: TextEditingController(text: draft.background)
            ..selection = TextSelection.collapsed(
              offset: draft.background.length,
            ),
          onChanged: (value) => onChanged(draft.copyWith(background: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        if (work?.content.image != null)
          SizedBox(
            height: 160,
            child: AppImageLoader(
              imageUrl: work!.content.image!.path,
              fit: BoxFit.cover,
            ),
          ),
        PubgetSecondaryButton(
          onPressed: onAddImage,
          semanticLabel: 'Add character image',
          leadingIcon: Icons.add_photo_alternate_outlined,
          child: const Text('Add image'),
        ),
      ],
    );
  }
}

class WorldbuildingEditor extends StatelessWidget {
  const WorldbuildingEditor({
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final FanWorkDraft draft;
  final ValueChanged<FanWorkDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PubgetTextArea(
          key: const Key('fan-work-lore'),
          label: 'Lore',
          minLines: 6,
          maxLines: 12,
          controller: TextEditingController(text: draft.lore)
            ..selection = TextSelection.collapsed(offset: draft.lore.length),
          onChanged: (value) => onChanged(draft.copyWith(lore: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        _NamedEntryEditor(
          title: 'Locations',
          entries: draft.locations,
          onChanged: (entries) => onChanged(draft.copyWith(locations: entries)),
        ),
        _NamedEntryEditor(
          title: 'Factions',
          entries: draft.factions,
          onChanged: (entries) => onChanged(draft.copyWith(factions: entries)),
        ),
        _NamedEntryEditor(
          title: 'Characters',
          entries: draft.characters,
          onChanged: (entries) =>
              onChanged(draft.copyWith(characters: entries)),
        ),
      ],
    );
  }
}

class OtherEditor extends StatelessWidget {
  const OtherEditor({
    required this.draft,
    required this.work,
    required this.onChanged,
    required this.onAddImage,
    super.key,
  });

  final FanWorkDraft draft;
  final FanWork? work;
  final ValueChanged<FanWorkDraft> onChanged;
  final VoidCallback onAddImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PubgetTextArea(
          label: 'Content',
          minLines: 4,
          maxLines: 10,
          controller: TextEditingController(text: draft.body)
            ..selection = TextSelection.collapsed(offset: draft.body.length),
          onChanged: (value) => onChanged(draft.copyWith(body: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        DrawingEditor(work: work, onAddImage: onAddImage),
      ],
    );
  }
}

class _NamedEntryEditor extends StatelessWidget {
  const _NamedEntryEditor({
    required this.title,
    required this.entries,
    required this.onChanged,
  });

  final String title;
  final List<FanWorkNamedEntry> entries;
  final ValueChanged<List<FanWorkNamedEntry>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PubgetTextField(
              label: 'Name',
              controller: TextEditingController(text: entries[i].name)
                ..selection = TextSelection.collapsed(
                  offset: entries[i].name.length,
                ),
              onChanged: (value) {
                final next = [...entries];
                next[i] = FanWorkNamedEntry(
                  name: value,
                  description: next[i].description,
                );
                onChanged(next);
              },
            ),
          ),
        PubgetTextButton(
          onPressed: () => onChanged([
            ...entries,
            const FanWorkNamedEntry(name: ''),
          ]),
          semanticLabel: 'Add $title item',
          child: Text('Add $title'),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class TypeSpecificEditor extends StatelessWidget {
  const TypeSpecificEditor({
    required this.draft,
    required this.work,
    required this.onChanged,
    required this.onAddImage,
    required this.onAddPage,
    super.key,
  });

  final FanWorkDraft draft;
  final FanWork? work;
  final ValueChanged<FanWorkDraft> onChanged;
  final VoidCallback onAddImage;
  final VoidCallback onAddPage;

  @override
  Widget build(BuildContext context) {
    return switch (draft.type) {
      FanWorkType.manga => MangaEditor(
        work: work,
        draft: draft,
        onChanged: onChanged,
        onAddPage: onAddPage,
      ),
      FanWorkType.drawing => DrawingEditor(work: work, onAddImage: onAddImage),
      FanWorkType.story => StoryEditor(draft: draft, onChanged: onChanged),
      FanWorkType.character => CharacterEditor(
        draft: draft,
        work: work,
        onChanged: onChanged,
        onAddImage: onAddImage,
      ),
      FanWorkType.aiCharacter => CharacterEditor(
        draft: draft,
        work: work,
        onChanged: onChanged,
        onAddImage: onAddImage,
        aiAssisted: true,
      ),
      FanWorkType.worldbuilding => WorldbuildingEditor(
        draft: draft,
        onChanged: onChanged,
      ),
      FanWorkType.other => OtherEditor(
        draft: draft,
        work: work,
        onChanged: onChanged,
        onAddImage: onAddImage,
      ),
    };
  }
}
