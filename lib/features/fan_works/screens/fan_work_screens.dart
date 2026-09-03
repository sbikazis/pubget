import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/fan_work_lifecycle.dart';
import '../models/fan_work_models.dart';
import '../providers/fan_work_providers.dart';
import '../widgets/fan_work_widgets.dart';

class FanWorkFeedPage extends StatefulWidget {
  const FanWorkFeedPage({super.key});

  @override
  State<FanWorkFeedPage> createState() => _FanWorkFeedPageState();
}

class _FanWorkFeedPageState extends State<FanWorkFeedPage> {
  FanWorkType? _type;

  @override
  void initState() {
    super.initState();
    final feed = context.read<FanWorkFeedProvider>();
    final uid = context.read<AuthProvider>().currentUser?.id;
    Future<void>.microtask(() async {
      await feed.load();
      if (uid != null) await feed.loadDrafts(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FanWorkFeedProvider>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(FanWorkStrings.feedTitle),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Latest'),
              Tab(text: 'Drafts'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => AppNavigation.go(context, '/fan-works/create'),
          label: const Text(FanWorkStrings.create),
          icon: const Icon(Icons.add),
        ),
        body: TabBarView(
          children: <Widget>[
            Column(
              children: <Widget>[
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: AppSpacing.sm,
                        ),
                        child: PubgetSelectionChip(
                          label: 'All',
                          selected: _type == null,
                          onSelected: (_) {
                            setState(() => _type = null);
                            feed.load();
                          },
                        ),
                      ),
                      for (final type in FanWorkType.values)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            end: AppSpacing.sm,
                          ),
                          child: PubgetSelectionChip(
                            label: FanWorkTypeCatalog.label(type),
                            selected: _type == type,
                            onSelected: (_) {
                              setState(() => _type = type);
                              feed.load(type: type);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                if (feed.offlineCached)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: Text(FanWorkStrings.offlineCached),
                  ),
                Expanded(
                  child: PubgetLoadingStateView(
                    state: feed.state,
                    onRetry: feed.load,
                    empty: const PubgetEmptyState(
                      title: FanWorkStrings.emptyTitle,
                      message: FanWorkStrings.emptyMessage,
                      icon: Icons.auto_awesome_outlined,
                    ),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.extentAfter < 400) {
                          feed.loadMore();
                        }
                        return false;
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: feed.items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final work = feed.items[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: SizedBox(
                              width: 56,
                              height: 72,
                              child: work.cover?.path.isEmpty ?? true
                                  ? Icon(
                                      Icons.auto_awesome_outlined,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    )
                                  : AppImageLoader(
                                      imageUrl: work.cover!.path,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            title: Text(work.title),
                            subtitle: Text(
                              FanWorkTypeCatalog.label(work.type),
                            ),
                            onTap: () => FanWorkLinks.open(context, work.id),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            feed.drafts.isEmpty
                ? const PubgetEmptyState(
                    title: FanWorkStrings.draftsEmpty,
                    message: 'Start a Fan Work and save it as a draft.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: feed.drafts.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final work = feed.drafts[index];
                      return ListTile(
                        title: Text(
                          work.title.isEmpty ? 'Untitled draft' : work.title,
                        ),
                        subtitle: Text(FanWorkTypeCatalog.label(work.type)),
                        onTap: () => AppNavigation.go(
                          context,
                          '/fan-works/create?workId=${Uri.encodeComponent(work.id)}',
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

class FanWorkDetailsPage extends StatefulWidget {
  const FanWorkDetailsPage({required this.workId, super.key});

  final String workId;

  @override
  State<FanWorkDetailsPage> createState() => _FanWorkDetailsPageState();
}

class _FanWorkDetailsPageState extends State<FanWorkDetailsPage> {
  @override
  void initState() {
    super.initState();
    final details = context.read<FanWorkDetailsProvider>();
    final uid = context.read<AuthProvider>().currentUser?.id ?? '';
    Future<void>.microtask(
      () => details.open(workId: widget.workId, userId: uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = context.watch<FanWorkDetailsProvider>();
    final uid = context.watch<AuthProvider>().currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(details.work?.title ?? FanWorkStrings.feedTitle),
        actions: <Widget>[
          if (details.work != null)
            IconButton(
              tooltip: FanWorkStrings.share,
              onPressed: () => FanWorkLinks.share(
                context,
                details.work!.id,
                title: details.work!.title,
              ),
              icon: const Icon(Icons.share_outlined),
            ),
        ],
      ),
      body: PubgetLoadingStateView(
        state: details.state,
        onRetry: () => details.open(workId: widget.workId, userId: uid ?? ''),
        empty: const PubgetEmptyState(
          title: FanWorkStrings.missing,
          message: 'It may be a draft, archived, or removed.',
        ),
        child: details.work == null
            ? const SizedBox.shrink()
            : _DetailsBody(
                work: details.work!,
                isOwner: details.work!.creatorId == uid,
                liked: details.liked,
                bookmarked: details.bookmarked,
                acting: details.acting,
              ),
      ),
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({
    required this.work,
    required this.isOwner,
    required this.liked,
    required this.bookmarked,
    required this.acting,
  });

  final FanWork work;
  final bool isOwner;
  final bool liked;
  final bool bookmarked;
  final bool acting;

  @override
  Widget build(BuildContext context) {
    final details = context.read<FanWorkDetailsProvider>();
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        if (work.cover?.path.isNotEmpty ?? false)
          AspectRatio(
            aspectRatio: 3 / 4,
            child: AppImageLoader(imageUrl: work.cover!.path, fit: BoxFit.cover),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(work.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          children: <Widget>[
            PubgetSelectionChip(
              label: FanWorkTypeCatalog.label(work.type),
              selected: false,
              onSelected: null,
            ),
            if (work.isAiAssisted)
              const PubgetSelectionChip(
                label: FanWorkStrings.aiAssisted,
                selected: true,
                onSelected: null,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (work.creatorSnapshot.username.isNotEmpty)
          Text(work.creatorSnapshot.username, style: theme.textTheme.titleSmall),
        if (work.publishedAt != null)
          Text(
            'Published ${work.publishedAt!.toLocal().toIso8601String().split('T').first}',
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: AppSpacing.md),
        if (work.description.isNotEmpty) Text(work.description),
        if (work.animeTitle.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Related anime: ${work.animeTitle}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
        if (!work.copyright.isEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(FanWorkStrings.copyright, style: theme.textTheme.titleSmall),
          if (work.copyright.sourceTitle.isNotEmpty)
            Text('Source: ${work.copyright.sourceTitle}'),
          if (work.copyright.originalWorkId.isNotEmpty)
            Text('Original ID: ${work.copyright.originalWorkId}'),
          if (work.copyright.credit.isNotEmpty)
            Text('Credit: ${work.copyright.credit}'),
          Text('Revision ${work.version}'),
        ],
        if (work.characterIds.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Character refs: ${work.characterIds.join(', ')}'),
        ],
        const SizedBox(height: AppSpacing.md),
        FanWorkTagWrap(tags: work.tags),
        const SizedBox(height: AppSpacing.md),
        Text(
          '${work.likesCount} likes · ${work.bookmarksCount} saves',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        if (work.type == FanWorkType.manga)
          PubgetPrimaryButton(
            onPressed: () => AppNavigation.go(
              context,
              '/fan-work/${Uri.encodeComponent(work.id)}?view=manga',
            ),
            semanticLabel: 'Read manga',
            child: const Text('Read manga'),
          ),
        if (work.type == FanWorkType.story)
          PubgetPrimaryButton(
            onPressed: () => AppNavigation.go(
              context,
              '/fan-work/${Uri.encodeComponent(work.id)}?view=story',
            ),
            semanticLabel: 'Read story',
            child: const Text('Read story'),
          ),
        if (work.type == FanWorkType.character ||
            work.type == FanWorkType.aiCharacter) ...[
          const SizedBox(height: AppSpacing.md),
          if (work.content.image != null)
            SizedBox(
              height: 220,
              child: AppImageLoader(
                imageUrl: work.content.image!.path,
                fit: BoxFit.cover,
              ),
            ),
          Text(work.content.name, style: theme.textTheme.titleLarge),
          if (work.content.personality.isNotEmpty)
            Text('Personality: ${work.content.personality}'),
          if (work.content.abilities.isNotEmpty)
            Text('Abilities: ${work.content.abilities}'),
          if (work.content.background.isNotEmpty)
            Text(work.content.background),
        ],
        if (work.type == FanWorkType.worldbuilding) ...[
          const SizedBox(height: AppSpacing.md),
          Text(work.content.lore),
          for (final location in work.content.locations)
            ListTile(
              title: Text(location.name),
              subtitle: Text(location.description),
            ),
        ],
        if (work.type == FanWorkType.drawing || work.type == FanWorkType.other)
          ...work.content.images.map(
            (image) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppImageLoader(imageUrl: image.path, fit: BoxFit.cover),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: PubgetSecondaryButton(
                onPressed: acting ? null : () => details.toggleLike(work.id),
                semanticLabel: FanWorkStrings.like,
                leadingIcon: liked ? Icons.favorite : Icons.favorite_border,
                child: Text(liked ? 'Liked' : FanWorkStrings.like),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PubgetSecondaryButton(
                onPressed: acting
                    ? null
                    : () => details.toggleBookmark(work.id),
                semanticLabel: FanWorkStrings.bookmark,
                leadingIcon: bookmarked ? Icons.bookmark : Icons.bookmark_border,
                child: Text(bookmarked ? 'Saved' : FanWorkStrings.bookmark),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        PubgetTextButton(
          onPressed: () => _report(context),
          semanticLabel: FanWorkStrings.report,
          child: const Text(FanWorkStrings.report),
        ),
        PubgetTextButton(
          onPressed: acting
              ? null
              : () => details.requestRemoval(workId: work.id),
          semanticLabel: FanWorkStrings.requestRemoval,
          child: const Text(FanWorkStrings.requestRemoval),
        ),
        if (isOwner && work.isPublished)
          PubgetSecondaryButton(
            onPressed: acting
                ? null
                : () => details.revisePublished(
                    workId: work.id,
                    title: work.title,
                    description: work.description,
                    copyright: work.copyright,
                  ),
            semanticLabel: FanWorkStrings.revised,
            child: const Text('Save revision metadata'),
          ),
        if (isOwner && work.isPublished)
          PubgetSecondaryButton(
            onPressed: acting ? null : () => details.archive(work.id),
            semanticLabel: FanWorkStrings.archive,
            child: const Text(FanWorkStrings.archive),
          ),
        if (isOwner && work.isDraft)
          PubgetSecondaryButton(
            onPressed: () => AppNavigation.go(
              context,
              '/fan-works/create?workId=${Uri.encodeComponent(work.id)}',
            ),
            semanticLabel: 'Edit draft',
            child: const Text('Edit draft'),
          ),
      ],
    );
  }

  Future<void> _report(BuildContext context) async {
    final reason = await showModalBottomSheet<FanWorkReportReason>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in FanWorkReportReason.values)
              ListTile(
                title: Text(value.name),
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return;
    await context.read<FanWorkDetailsProvider>().report(
      workId: work.id,
      reason: reason,
    );
  }
}

class FanWorkEditorPage extends StatefulWidget {
  const FanWorkEditorPage({this.workId, super.key});

  final String? workId;

  @override
  State<FanWorkEditorPage> createState() => _FanWorkEditorPageState();
}

class _FanWorkEditorPageState extends State<FanWorkEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _tags;
  late final TextEditingController _animeId;
  late final TextEditingController _animeTitle;
  late final TextEditingController _body;
  late final TextEditingController _name;
  late final TextEditingController _personality;
  late final TextEditingController _abilities;
  late final TextEditingController _background;
  late final TextEditingController _lore;
  late final TextEditingController _originalWorkId;
  late final TextEditingController _sourceTitle;
  late final TextEditingController _credit;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final editor = context.read<FanWorkEditorProvider>();
    _title = TextEditingController(text: editor.draft.title);
    _description = TextEditingController(text: editor.draft.description);
    _tags = TextEditingController(text: editor.draft.tags.join(', '));
    _animeId = TextEditingController(text: editor.draft.animeId);
    _animeTitle = TextEditingController(text: editor.draft.animeTitle);
    _body = TextEditingController(text: editor.draft.body);
    _name = TextEditingController(text: editor.draft.name);
    _personality = TextEditingController(text: editor.draft.personality);
    _abilities = TextEditingController(text: editor.draft.abilities);
    _background = TextEditingController(text: editor.draft.background);
    _lore = TextEditingController(text: editor.draft.lore);
    _originalWorkId = TextEditingController(
      text: editor.draft.copyright.originalWorkId,
    );
    _sourceTitle = TextEditingController(
      text: editor.draft.copyright.sourceTitle,
    );
    _credit = TextEditingController(text: editor.draft.copyright.credit);
    Future<void>.microtask(() async {
      await editor.start(workId: widget.workId);
      if (!mounted) return;
      _syncControllers(editor.draft);
    });
  }

  void _syncControllers(FanWorkDraft draft) {
    _title.text = draft.title;
    _description.text = draft.description;
    _tags.text = draft.tags.join(', ');
    _animeId.text = draft.animeId;
    _animeTitle.text = draft.animeTitle;
    _body.text = draft.body;
    _name.text = draft.name;
    _personality.text = draft.personality;
    _abilities.text = draft.abilities;
    _background.text = draft.background;
    _lore.text = draft.lore;
    _originalWorkId.text = draft.copyright.originalWorkId;
    _sourceTitle.text = draft.copyright.sourceTitle;
    _credit.text = draft.copyright.credit;
  }

  FanWorkDraft _collected(FanWorkEditorProvider editor) {
    return editor.draft.copyWith(
      title: _title.text,
      description: _description.text,
      tags: FanWorkLifecycle.normalizeTags(_tags.text.split(',')),
      animeId: _animeId.text.trim(),
      animeTitle: _animeTitle.text.trim(),
      body: _body.text,
      name: _name.text,
      personality: _personality.text,
      abilities: _abilities.text,
      background: _background.text,
      lore: _lore.text,
      copyright: editor.draft.copyright.copyWith(
        originalWorkId: _originalWorkId.text.trim(),
        sourceTitle: _sourceTitle.text.trim(),
        credit: _credit.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tags.dispose();
    _animeId.dispose();
    _animeTitle.dispose();
    _body.dispose();
    _name.dispose();
    _personality.dispose();
    _abilities.dispose();
    _background.dispose();
    _lore.dispose();
    _originalWorkId.dispose();
    _sourceTitle.dispose();
    _credit.dispose();
    super.dispose();
  }

  Future<void> _pick(FanWorkMediaRole role) async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final contentType = file.mimeType ?? 'image/jpeg';
    final editor = context.read<FanWorkEditorProvider>();
    editor.updateDraft(_collected(editor));
    final result = await editor.uploadImage(
      bytes: bytes,
      contentType: contentType,
      role: role,
    );
    if (!mounted) return;
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.failureOrNull?.message ?? FanWorkStrings.uploadFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<FanWorkEditorProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.workId == null
              ? FanWorkStrings.create
              : 'Edit draft',
        ),
      ),
      body: Column(
        children: <Widget>[
          if (editor.draftSavedLocally && editor.failure != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                '${editor.failure!.message} Your draft is still on this device.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (editor.fieldError != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                editor.fieldError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                if (editor.step == FanWorkEditorStep.type)
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final type in FanWorkType.values)
                        PubgetSelectionChip(
                          label: FanWorkTypeCatalog.label(type),
                          selected: editor.draft.type == type,
                          onSelected: (_) => editor.selectType(type),
                        ),
                    ],
                  ),
                if (editor.step != FanWorkEditorStep.type) ...[
                  PubgetTextField(
                    key: const Key('fan-work-title'),
                    controller: _title,
                    label: 'Title',
                    onChanged: (_) =>
                        editor.updateDraft(_collected(editor)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PubgetTextArea(
                    key: const Key('fan-work-description'),
                    controller: _description,
                    label: 'Description',
                    onChanged: (_) =>
                        editor.updateDraft(_collected(editor)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PubgetTextField(
                    key: const Key('fan-work-tags'),
                    controller: _tags,
                    label: 'Tags',
                    hint: 'demonslayer, tanjiro',
                    helperText: 'Up to 8 tags. Values are normalized.',
                    onChanged: (_) =>
                        editor.updateDraft(_collected(editor)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PubgetTextField(
                    key: const Key('fan-work-anime-id'),
                    controller: _animeId,
                    label: 'Related anime ID',
                    onChanged: (_) =>
                        editor.updateDraft(_collected(editor)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PubgetTextField(
                    key: const Key('fan-work-anime-title'),
                    controller: _animeTitle,
                    label: 'Related anime title',
                    onChanged: (_) =>
                        editor.updateDraft(_collected(editor)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PubgetTextField(
                    key: const Key('fan-work-original-id'),
                    controller: _originalWorkId,
                    label: 'Original work ID',
                    hint: 'Optional source identifier',
                    onChanged: (_) =>
                        editor.updateDraft(_collected(editor)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PubgetTextField(
                    key: const Key('fan-work-source-title'),
                    controller: _sourceTitle,
                    label: 'Source title',
                    hint: 'Original series or work',
                    onChanged: (_) =>
                        editor.updateDraft(_collected(editor)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PubgetTextField(
                    key: const Key('fan-work-credit'),
                    controller: _credit,
                    label: 'Credit',
                    hint: 'How this work should be credited',
                    onChanged: (_) =>
                        editor.updateDraft(_collected(editor)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (editor.draft.type == FanWorkType.story ||
                      editor.draft.type == FanWorkType.other)
                    PubgetTextArea(
                      key: const Key('fan-work-story-body'),
                      controller: _body,
                      label: editor.draft.type == FanWorkType.story
                          ? 'Story'
                          : 'Content',
                      minLines: 8,
                      maxLines: 16,
                      onChanged: (_) =>
                          editor.updateDraft(_collected(editor)),
                    ),
                  if (editor.draft.type == FanWorkType.character ||
                      editor.draft.type == FanWorkType.aiCharacter) ...[
                    if (editor.draft.type == FanWorkType.aiCharacter)
                      const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.sm),
                        child: PubgetSelectionChip(
                          label: FanWorkStrings.aiAssisted,
                          selected: true,
                          onSelected: null,
                        ),
                      ),
                    PubgetTextField(
                      key: const Key('fan-work-character-name'),
                      controller: _name,
                      label: 'Name',
                      onChanged: (_) =>
                          editor.updateDraft(_collected(editor)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PubgetTextArea(
                      controller: _personality,
                      label: 'Personality',
                      onChanged: (_) =>
                          editor.updateDraft(_collected(editor)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PubgetTextArea(
                      controller: _abilities,
                      label: 'Abilities',
                      onChanged: (_) =>
                          editor.updateDraft(_collected(editor)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PubgetTextArea(
                      controller: _background,
                      label: 'Background',
                      onChanged: (_) =>
                          editor.updateDraft(_collected(editor)),
                    ),
                  ],
                  if (editor.draft.type == FanWorkType.worldbuilding)
                    PubgetTextArea(
                      key: const Key('fan-work-lore'),
                      controller: _lore,
                      label: 'Lore',
                      minLines: 6,
                      maxLines: 12,
                      onChanged: (_) =>
                          editor.updateDraft(_collected(editor)),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  TypeSpecificEditor(
                    draft: editor.draft,
                    work: editor.loaded,
                    onChanged: editor.updateDraft,
                    onAddImage: () => _pick(
                      editor.draft.type == FanWorkType.character ||
                              editor.draft.type == FanWorkType.aiCharacter
                          ? FanWorkMediaRole.image
                          : FanWorkMediaRole.image,
                    ),
                    onAddPage: () => _pick(FanWorkMediaRole.page),
                  ),
                  if (editor.step == FanWorkEditorStep.preview) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Preview',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(editor.draft.title),
                    Text(editor.draft.description),
                    if (editor.draft.type == FanWorkType.aiCharacter)
                      const Text(FanWorkStrings.aiAssisted),
                  ],
                ],
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: PubgetSecondaryButton(
                      onPressed: editor.busy
                          ? null
                          : () async {
                              editor.updateDraft(_collected(editor));
                              final result = await editor.saveDraft();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result.isSuccess
                                        ? FanWorkStrings.draftSaved
                                        : result.failureOrNull?.message ??
                                              'Draft kept on this device.',
                                  ),
                                ),
                              );
                            },
                      semanticLabel: FanWorkStrings.saveDraft,
                      loading: editor.saving,
                      child: const Text(FanWorkStrings.saveDraft),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: PubgetPrimaryButton(
                      onPressed: editor.busy
                          ? null
                          : () async {
                              editor.updateDraft(_collected(editor));
                              editor.goTo(FanWorkEditorStep.preview);
                              final result = await editor.publish();
                              if (!context.mounted) return;
                              if (result.isSuccess) {
                                AppNavigation.go(
                                  context,
                                  FanWorkLinks.path(result.valueOrNull!.id),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result.failureOrNull?.message ??
                                          FanWorkStrings.publishFailed,
                                    ),
                                  ),
                                );
                              }
                            },
                      semanticLabel: FanWorkStrings.publish,
                      loading: editor.publishing,
                      child: const Text(FanWorkStrings.publish),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MangaViewerPage extends StatefulWidget {
  const MangaViewerPage({required this.workId, super.key});

  final String workId;

  @override
  State<MangaViewerPage> createState() => _MangaViewerPageState();
}

class _MangaViewerPageState extends State<MangaViewerPage> {
  @override
  void initState() {
    super.initState();
    final details = context.read<FanWorkDetailsProvider>();
    if (details.work?.id != widget.workId) {
      final uid = context.read<AuthProvider>().currentUser?.id ?? '';
      Future<void>.microtask(
        () => details.open(workId: widget.workId, userId: uid),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = context.watch<FanWorkDetailsProvider>();
    final pages = details.work?.content.orderedPages ?? const <FanWorkPage>[];
    return Scaffold(
      appBar: AppBar(title: Text(details.work?.title ?? 'Manga')),
      body: pages.isEmpty
          ? const PubgetEmptyState(
              title: 'No pages yet',
              message: 'This manga does not have pages to display.',
            )
          : PageView.builder(
              itemCount: pages.length,
              itemBuilder: (context, index) {
                final page = pages[index];
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: AppImageLoader(
                        imageUrl: page.path,
                        fit: BoxFit.contain,
                        memCacheWidth: 1200,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Text(
                        '${index + 1} / ${pages.length}',
                        semanticsLabel: 'Page ${index + 1} of ${pages.length}',
                      ),
                    ),
                    if (page.caption.isNotEmpty) Text(page.caption),
                  ],
                );
              },
            ),
    );
  }
}

class StoryReaderPage extends StatefulWidget {
  const StoryReaderPage({required this.workId, super.key});

  final String workId;

  @override
  State<StoryReaderPage> createState() => _StoryReaderPageState();
}

class _StoryReaderPageState extends State<StoryReaderPage> {
  int _chapter = 0;

  @override
  void initState() {
    super.initState();
    final details = context.read<FanWorkDetailsProvider>();
    if (details.work?.id != widget.workId) {
      final uid = context.read<AuthProvider>().currentUser?.id ?? '';
      Future<void>.microtask(
        () => details.open(workId: widget.workId, userId: uid),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = context.watch<FanWorkDetailsProvider>();
    final work = details.work;
    final chapters = work?.content.orderedChapters ?? const <FanWorkChapter>[];
    final body = chapters.isEmpty
        ? (work?.content.body ?? '')
        : chapters[_chapter.clamp(0, chapters.length - 1)].body;
    return Scaffold(
      appBar: AppBar(title: Text(work?.title ?? 'Story')),
      body: work == null
          ? const PubgetSkeleton.card(width: double.infinity)
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                if (chapters.isNotEmpty)
                  DropdownButton<int>(
                    value: _chapter,
                    items: [
                      for (var i = 0; i < chapters.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            chapters[i].title.isEmpty
                                ? 'Chapter ${i + 1}'
                                : chapters[i].title,
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _chapter = value ?? 0),
                  ),
                Text(
                  body.isEmpty ? 'This story has no content yet.' : body,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
    );
  }
}
