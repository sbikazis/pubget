import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/errors/failure.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../l10n/fan_work_copy.dart';
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
    final copy = FanWorkCopy.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: AppBackButton.maybeOf(context),
          title: Text(copy.feedTitle),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: copy.latest),
              Tab(text: copy.draftsLabel),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => AppNavigation.go(context, '/fan-works/create'),
          label: Text(copy.create),
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
                          label: copy.allTypes,
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
                            label: copy.typeLabel(type),
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
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(copy.offlineCached),
                  ),
                Expanded(
                  child: PubgetLoadingStateView(
                    state: feed.state,
                    onRetry: feed.load,
                    empty: PubgetEmptyState(
                      title: copy.emptyTitle,
                      message: copy.emptyMessage,
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
                            subtitle: Text(FanWorkTypeCatalog.label(work.type)),
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
                ? PubgetEmptyState(
                    title: copy.draftsEmpty,
                    message: copy.draftsEmptyMessage,
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
                          work.title.isEmpty ? copy.untitledDraft : work.title,
                        ),
                        subtitle: Text(copy.typeLabel(work.type)),
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
    if (details.state == LoadingState.initial) {
      Future<void>.microtask(
        () => details.open(workId: widget.workId, userId: uid),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = context.watch<FanWorkDetailsProvider>();
    final uid = context.watch<AuthProvider>().currentUser?.id;
    final copy = FanWorkCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(details.work?.title ?? copy.feedTitle),
        actions: <Widget>[
          if (details.work != null)
            IconButton(
              tooltip: copy.share,
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
        empty: PubgetEmptyState(title: copy.missing, message: copy.missingHint),
        child: details.work == null
            ? const SizedBox.shrink()
            : _DetailsBody(
                work: details.work!,
                isOwner: details.work!.creatorId == uid,
                liked: details.liked,
                bookmarked: details.bookmarked,
                myRating: details.myRating,
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
    required this.myRating,
    required this.acting,
  });

  final FanWork work;
  final bool isOwner;
  final bool liked;
  final bool bookmarked;
  final int? myRating;
  final bool acting;

  @override
  Widget build(BuildContext context) {
    final details = context.read<FanWorkDetailsProvider>();
    final theme = Theme.of(context);
    final copy = FanWorkCopy.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (work.cover?.path.isNotEmpty ?? false)
            AspectRatio(
              aspectRatio: 3 / 4,
              child: AppImageLoader(
                imageUrl: work.cover!.path,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(work.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              PubgetSelectionChip(
                label: copy.typeLabel(work.type),
                selected: false,
                onSelected: null,
              ),
              if (work.isAiAssisted)
                PubgetSelectionChip(
                  label: copy.aiAssisted,
                  selected: true,
                  onSelected: null,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (work.creatorSnapshot.username.isNotEmpty)
            Text(
              work.creatorSnapshot.username,
              style: theme.textTheme.titleSmall,
            ),
          if (work.publishedAt != null)
            Text(
              copy.publishedOn(work.publishedAt!),
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: AppSpacing.md),
          if (work.description.isNotEmpty) Text(work.description),
          if (work.animeTitle.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              copy.relatedAnime(work.animeTitle),
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (!work.copyright.isEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(copy.copyright, style: theme.textTheme.titleSmall),
            if (work.copyright.sourceTitle.isNotEmpty)
              Text(copy.sourceLine(work.copyright.sourceTitle)),
            if (work.copyright.originalWorkId.isNotEmpty)
              Text(copy.originalId(work.copyright.originalWorkId)),
            if (work.copyright.credit.isNotEmpty)
              Text(copy.credit(work.copyright.credit)),
            Text(copy.revisionNumber(work.version)),
          ],
          if (work.characterIds.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(copy.characterRefs(work.characterIds.join(', '))),
          ],
          const SizedBox(height: AppSpacing.md),
          FanWorkTagWrap(tags: work.tags),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${copy.likes(work.likesCount)} · ${copy.commentsCount(work.commentsCount)} · ${copy.saves(work.bookmarksCount)}'
            '${work.ratingsCount > 0 ? ' · ${copy.ratings(work.ratingsCount)}' : ''}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          if (work.type == FanWorkType.manga)
            PubgetPrimaryButton(
              onPressed: () => AppNavigation.go(
                context,
                '/fan-work/${Uri.encodeComponent(work.id)}?view=manga',
              ),
              semanticLabel: copy.readManga,
              child: Text(copy.readManga),
            ),
          if (work.type == FanWorkType.story)
            PubgetPrimaryButton(
              onPressed: () => AppNavigation.go(
                context,
                '/fan-work/${Uri.encodeComponent(work.id)}?view=story',
              ),
              semanticLabel: copy.readStory,
              child: Text(copy.readStory),
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
              Text('${copy.personalityLabel}: ${work.content.personality}'),
            if (work.content.abilities.isNotEmpty)
              Text('${copy.abilitiesLabel}: ${work.content.abilities}'),
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
          if (work.type == FanWorkType.drawing ||
              work.type == FanWorkType.other)
            ...work.content.images.map(
              (image) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppImageLoader(imageUrl: image.path, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(copy.rating, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (var score = 1; score <= 10; score++)
                PubgetSelectionChip(
                  key: Key('fan-work-rate-$score'),
                  label: '$score',
                  selected: myRating == score,
                  onSelected: acting
                      ? null
                      : (_) => details.rate(workId: work.id, rating: score),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: PubgetSecondaryButton(
                  onPressed: acting ? null : () => details.toggleLike(work.id),
                  semanticLabel: copy.like,
                  leadingIcon: liked ? Icons.favorite : Icons.favorite_border,
                  child: Text(liked ? copy.liked : copy.like),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: PubgetSecondaryButton(
                  onPressed: acting
                      ? null
                      : () => details.toggleBookmark(work.id),
                  semanticLabel: copy.bookmark,
                  leadingIcon: bookmarked
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  child: Text(bookmarked ? copy.bookmarked : copy.bookmark),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetTextButton(
            onPressed: () => _report(context),
            semanticLabel: copy.report,
            child: Text(copy.report),
          ),
          PubgetTextButton(
            onPressed: acting
                ? null
                : () => details.requestRemoval(workId: work.id),
            semanticLabel: copy.requestRemoval,
            child: Text(copy.requestRemoval),
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
              semanticLabel: copy.revised,
              child: Text(copy.saveRevisionMetadata),
            ),
          if (isOwner && work.isPublished)
            PubgetSecondaryButton(
              onPressed: acting ? null : () => details.archive(work.id),
              semanticLabel: copy.archive,
              child: Text(copy.archive),
            ),
          if (isOwner && work.isDraft)
            PubgetSecondaryButton(
              onPressed: () => AppNavigation.go(
                context,
                '/fan-works/create?workId=${Uri.encodeComponent(work.id)}',
              ),
              semanticLabel: copy.editDraft,
              child: Text(copy.editDraft),
            ),
          const SizedBox(height: AppSpacing.xl),
          _FanWorkRevisionsSection(workId: work.id),
          _FanWorkCommentsSection(workId: work.id),
        ],
      ),
    );
  }

  Future<void> _report(BuildContext context) async {
    final copy = FanWorkCopy.of(context);
    final reason = await PubgetBottomSheet.present<FanWorkReportReason>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in FanWorkReportReason.values)
              ListTile(
                title: Text(copy.reportReason(value)),
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

class _FanWorkRevisionsSection extends StatelessWidget {
  const _FanWorkRevisionsSection({required this.workId});

  final String workId;

  @override
  Widget build(BuildContext context) {
    final details = context.watch<FanWorkDetailsProvider>();
    final theme = Theme.of(context);
    final copy = FanWorkCopy.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${copy.revisions} (${details.revisions.length})',
                style: theme.textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: details.revisionsLoading
                  ? null
                  : () => details.loadRevisions(workId),
              child: Text(details.revisionsLoading ? '…' : copy.load),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (details.revisionsFailure != null)
          Text(
            details.revisionsFailure?.message ?? copy.missing,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else if (details.revisions.isEmpty)
          Text(
            copy.noRevisions,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          )
        else
          for (final revision in details.revisions)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history, size: 20),
              title: Text(
                copy.versionNumber(revision.version),
                style: theme.textTheme.bodyMedium,
              ),
              subtitle: Text(
                revision.description.isNotEmpty
                    ? revision.description
                    : copy.revised,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      ],
    );
  }
}

class _FanWorkCommentsSection extends StatefulWidget {
  const _FanWorkCommentsSection({required this.workId});

  final String workId;

  @override
  State<_FanWorkCommentsSection> createState() =>
      _FanWorkCommentsSectionState();
}

class _FanWorkCommentsSectionState extends State<_FanWorkCommentsSection> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final result = await context.read<FanWorkDetailsProvider>().addComment(
      workId: widget.workId,
      text: text,
    );
    if (!mounted) return;
    if (result.isSuccess) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final details = context.watch<FanWorkDetailsProvider>();
    final uid = context.watch<AuthProvider>().currentUser?.id;
    final theme = Theme.of(context);
    final copy = FanWorkCopy.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(copy.comments, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (details.replyTo != null)
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${copy.replyingTo} ${details.replyTo!.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: copy.cancelReply,
                onPressed: () => details.setReplyTo(null),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        Row(
          children: <Widget>[
            Expanded(
              child: PubgetTextField(
                key: const Key('fan-work-comment-field'),
                controller: _controller,
                hint: copy.addComment,
                minLines: 1,
                maxLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
            IconButton(
              key: const Key('fan-work-comment-send'),
              tooltip: copy.sendComment,
              onPressed: _send,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (details.commentsLoading)
          const PubgetSkeleton.card(height: 72)
        else if (details.commentsFailure != null && details.comments.isEmpty)
          PubgetErrorState(
            message: details.commentsFailure!.message,
            onRetry: () => details.loadComments(widget.workId),
          )
        else if (details.comments.isEmpty)
          PubgetEmptyState(
            compact: true,
            icon: Icons.chat_bubble_outline,
            title: copy.noComments,
            message: copy.noCommentsMessage,
          )
        else
          for (final comment in details.comments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(comment.text),
              subtitle: Text(
                [
                  if (comment.replyToCommentId != null) copy.replyBadge,
                  if (comment.mentions.isNotEmpty)
                    comment.mentions.map((handle) => '@$handle').join(' '),
                  copy.likes(comment.likesCount),
                ].join(' · '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: copy.reply,
                    onPressed: () => details.setReplyTo(comment),
                    icon: const Icon(Icons.reply),
                  ),
                  IconButton(
                    tooltip: copy.likeComment,
                    onPressed: details.acting
                        ? null
                        : () => details.commentAction(
                            workId: widget.workId,
                            commentId: comment.id,
                            action: 'like',
                          ),
                    icon: const Icon(Icons.favorite_border),
                  ),
                  if (comment.authorId == uid)
                    IconButton(
                      tooltip: copy.deleteComment,
                      onPressed: details.acting
                          ? null
                          : () => details.commentAction(
                              workId: widget.workId,
                              commentId: comment.id,
                              action: 'delete',
                            ),
                      icon: const Icon(Icons.delete_outline),
                    )
                  else
                    IconButton(
                      tooltip: copy.reportComment,
                      onPressed: details.acting
                          ? null
                          : () => details.commentAction(
                              workId: widget.workId,
                              commentId: comment.id,
                              action: 'report',
                            ),
                      icon: const Icon(Icons.flag_outlined),
                    ),
                ],
              ),
            ),
        if (details.commentsHasMore)
          PubgetTextButton(
            onPressed: details.commentsLoadingMore
                ? null
                : () => details.loadComments(widget.workId, more: true),
            semanticLabel: copy.loadMoreComments,
            child: Text(
              details.commentsLoadingMore ? copy.loading : copy.loadMore,
            ),
          ),
      ],
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
      if (result.failureOrNull is CancelledError) return;
      final copy = FanWorkCopy.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.failureOrNull?.message ?? copy.uploadFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<FanWorkEditorProvider>();
    final copy = FanWorkCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(widget.workId == null ? copy.create : copy.editDraft),
      ),
      body: Column(
        children: <Widget>[
          if (editor.draftSavedLocally && editor.failure != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                copy.draftStillOnDevice(editor.failure!.message),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (editor.fieldError != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                copy.lifecycleError(editor.fieldError),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (editor.uploading || editor.uploadFailed)
            Padding(
              key: const Key('fan-work-upload-status'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    editor.uploadFailed
                        ? editor.uploadCanceled
                              ? copy.uploadCanceled
                              : copy.uploadFailed
                        : copy.uploadProgress(editor.uploadPercent),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Semantics(
                    label: editor.uploading
                        ? copy.uploadingMedia
                        : copy.uploadFailed,
                    value: '${editor.uploadPercent}%',
                    child: LinearProgressIndicator(
                      key: const Key('fan-work-upload-progress'),
                      value: editor.uploadProgress,
                    ),
                  ),
                  if (editor.uploadCancellable || editor.canRetryUpload)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        children: <Widget>[
                          if (editor.uploadCancellable)
                            PubgetTextButton(
                              key: const Key('fan-work-upload-cancel'),
                              onPressed: () async {
                                final result = await editor.cancelUpload();
                                if (!context.mounted || result.isSuccess) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(copy.uploadFailed)),
                                );
                              },
                              semanticLabel: copy.cancelUpload,
                              child: Text(copy.cancelUpload),
                            ),
                          if (editor.canRetryUpload)
                            PubgetTextButton(
                              key: const Key('fan-work-upload-retry'),
                              onPressed: editor.retryUpload,
                              semanticLabel: copy.retryUpload,
                              child: Text(copy.retryUpload),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (editor.step == FanWorkEditorStep.type)
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final type in FanWorkType.values)
                          PubgetSelectionChip(
                            label: copy.typeLabel(type),
                            selected: editor.draft.type == type,
                            onSelected: (_) => editor.selectType(type),
                          ),
                      ],
                    ),
                  if (editor.step != FanWorkEditorStep.type) ...[
                    PubgetTextField(
                      key: const Key('fan-work-title'),
                      controller: _title,
                      label: copy.titleLabel,
                      onChanged: (_) => editor.updateDraft(_collected(editor)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PubgetTextArea(
                      key: const Key('fan-work-description'),
                      controller: _description,
                      label: copy.descriptionLabel,
                      onChanged: (_) => editor.updateDraft(_collected(editor)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PubgetTextField(
                      key: const Key('fan-work-tags'),
                      controller: _tags,
                      label: copy.tagsLabel,
                      hint: copy.tagsHintEnEditor,
                      helperText: copy.tagsHelperEditor,
                      onChanged: (_) => editor.updateDraft(_collected(editor)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PubgetTextField(
                      key: const Key('fan-work-anime-id'),
                      controller: _animeId,
                      label: copy.relatedAnimeId,
                      onChanged: (_) => editor.updateDraft(_collected(editor)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PubgetTextField(
                      key: const Key('fan-work-anime-title'),
                      controller: _animeTitle,
                      label: copy.relatedAnimeTitle,
                      onChanged: (_) => editor.updateDraft(_collected(editor)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PubgetTextField(
                      key: const Key('fan-work-original-id'),
                      controller: _originalWorkId,
                      label: copy.originalWorkId,
                      hint: copy.optionalSourceIdentifier,
                      onChanged: (_) => editor.updateDraft(_collected(editor)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PubgetTextField(
                      key: const Key('fan-work-source-title'),
                      controller: _sourceTitle,
                      label: copy.sourceTitle,
                      hint: copy.originalSeriesOrWork,
                      onChanged: (_) => editor.updateDraft(_collected(editor)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PubgetTextField(
                      key: const Key('fan-work-credit'),
                      controller: _credit,
                      label: copy.creditLabel,
                      hint: copy.creditHint,
                      onChanged: (_) => editor.updateDraft(_collected(editor)),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (editor.draft.type == FanWorkType.story ||
                        editor.draft.type == FanWorkType.other)
                      PubgetTextArea(
                        key: const Key('fan-work-story-body'),
                        controller: _body,
                        label: editor.draft.type == FanWorkType.story
                            ? copy.storyLabel
                            : copy.contentLabel,
                        minLines: 8,
                        maxLines: 16,
                        onChanged: (_) =>
                            editor.updateDraft(_collected(editor)),
                      ),
                    if (editor.draft.type == FanWorkType.character ||
                        editor.draft.type == FanWorkType.aiCharacter) ...[
                      if (editor.draft.type == FanWorkType.aiCharacter)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: PubgetSelectionChip(
                            label: copy.aiAssisted,
                            selected: true,
                            onSelected: null,
                          ),
                        ),
                      PubgetTextField(
                        key: const Key('fan-work-character-name'),
                        controller: _name,
                        label: copy.nameLabel,
                        onChanged: (_) =>
                            editor.updateDraft(_collected(editor)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PubgetTextArea(
                        controller: _personality,
                        label: copy.personalityLabel,
                        onChanged: (_) =>
                            editor.updateDraft(_collected(editor)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PubgetTextArea(
                        controller: _abilities,
                        label: copy.abilitiesLabel,
                        onChanged: (_) =>
                            editor.updateDraft(_collected(editor)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PubgetTextArea(
                        controller: _background,
                        label: copy.backgroundLabel,
                        onChanged: (_) =>
                            editor.updateDraft(_collected(editor)),
                      ),
                    ],
                    if (editor.draft.type == FanWorkType.worldbuilding)
                      PubgetTextArea(
                        key: const Key('fan-work-lore'),
                        controller: _lore,
                        label: copy.loreLabel,
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
                        copy.preview,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(editor.draft.title),
                      Text(editor.draft.description),
                      if (editor.draft.type == FanWorkType.aiCharacter)
                        Text(copy.aiAssisted),
                    ],
                  ],
                ],
              ),
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
                                        ? copy.draftSaved
                                        : result.failureOrNull?.message ??
                                              copy.draftKept,
                                  ),
                                ),
                              );
                            },
                      semanticLabel: copy.saveDraft,
                      loading: editor.saving,
                      child: Text(copy.saveDraft),
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
                                          copy.publishFailed,
                                    ),
                                  ),
                                );
                              }
                            },
                      semanticLabel: copy.publish,
                      loading: editor.publishing,
                      child: Text(copy.publish),
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
    final copy = FanWorkCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(details.work?.title ?? copy.mangaFallback),
      ),
      body: pages.isEmpty
          ? PubgetEmptyState(title: copy.noPagesYet, message: copy.mangaNoPages)
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
                        semanticsLabel: copy.pageOf(pages.length, index + 1),
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
    final copy = FanWorkCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(work?.title ?? copy.storyFallback),
      ),
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
                                ? copy.chapterNumber(i + 1)
                                : chapters[i].title,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _chapter = value ?? 0),
                  ),
                Text(
                  body.isEmpty ? copy.storyNoContent : body,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
    );
  }
}
