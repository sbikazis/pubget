import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
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
import '../models/fan_work_taxonomy.dart';
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
          if (work.type == FanWorkType.manga ||
              work.type == FanWorkType.story) ...[
            const SizedBox(height: AppSpacing.md),
            PubgetPrimaryButton(
              onPressed: () => AppNavigation.go(
                context,
                '/fan-work/${Uri.encodeComponent(work.id)}'
                '?view=${work.type == FanWorkType.manga ? 'manga' : 'story'}',
              ),
              semanticLabel: copy.openDocument,
              child: Text(copy.openDocument),
            ),
            if (work.content.characters.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(copy.cast, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              for (final member in work.content.characters)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: member.hasImage
                      ? SizedBox(
                          width: 40,
                          height: 40,
                          child: AppImageLoader(
                            imageUrl: member.imagePath,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.person_outline),
                  title: Text(
                    member.name.isEmpty ? copy.characterName : member.name,
                  ),
                  subtitle: member.bio.isEmpty ? null : Text(member.bio),
                ),
            ],
            if (work.content.pages.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(copy.mangaFallback, style: theme.textTheme.bodySmall),
            ],
          ],
          if (work.type == FanWorkType.character) ...[
            const SizedBox(height: AppSpacing.md),
            if (work.content.portrait != null)
              SizedBox(
                height: 220,
                child: AppImageLoader(
                  imageUrl: work.content.portrait!.path,
                  fit: BoxFit.cover,
                ),
              ),
            if (work.content.personality.isNotEmpty)
              Text(work.content.personality),
            if (work.content.abilities.isNotEmpty) Text(work.content.abilities),
            if (work.content.specs.isNotEmpty) Text(work.content.specs),
          ],
          if (work.type == FanWorkType.drawing) ...[
            const SizedBox(height: AppSpacing.md),
            if (work.content.artwork != null)
              SizedBox(
                height: 320,
                child: AppImageLoader(
                  imageUrl: work.content.artwork!.path,
                  fit: BoxFit.contain,
                ),
              )
            else
              Text(copy.noPagesYet, style: theme.textTheme.bodySmall),
          ],
          if (work.type == FanWorkType.worldbuilding) ...[
            const SizedBox(height: AppSpacing.md),
            if (work.content.lore.isNotEmpty) Text(work.content.lore),
          ],
          if (work.origin == FanWorkOrigin.aiGenerated) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(copy.aiAssisted, style: theme.textTheme.labelSmall),
          ],
          if (work.content.chapters.isNotEmpty ||
              work.content.body.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(copy.storyFallback, style: theme.textTheme.titleSmall),
            if (work.content.body.isNotEmpty)
              Text(work.content.body, style: theme.textTheme.bodyMedium),
          ],
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

/// The create/edit screen.
///
/// All field state lives in [FanWorkEditorProvider] rather than in a dozen
/// `TextEditingController`s here. That is deliberate: the provider is what
/// persists a draft to the device, and a controller-local value would be lost
/// the moment the app is backgrounded. The widgets therefore rebuild from
/// `editor.draft` and report every keystroke back through `updateDraft`.
class FanWorkEditorPage extends StatefulWidget {
  const FanWorkEditorPage({this.workId, super.key});

  final String? workId;

  @override
  State<FanWorkEditorPage> createState() => _FanWorkEditorPageState();
}

class _FanWorkEditorPageState extends State<FanWorkEditorPage> {
  final ImagePicker _imagePicker = ImagePicker();

  FanWorkEditorProvider get _editor => context.read<FanWorkEditorProvider>();

  @override
  void initState() {
    super.initState();
    // The provider is resolved synchronously so the microtask below never has
    // to reach for a [BuildContext] after an await.
    final editor = context.read<FanWorkEditorProvider>();
    Future<void>.microtask(() => editor.start(workId: widget.workId));
  }

  /// Opens the PDF picker and hands the bytes to the provider.
  ///
  /// `pageCount` is deliberately left null here: the server derives it when the
  /// upload is confirmed, and a client-supplied count would be an unverified
  /// claim about the file's contents.
  Future<void> _pickDocument() async {
    XFile? file;
    try {
      file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[
          XTypeGroup(
            label: 'PDF',
            extensions: <String>['pdf'],
            mimeTypes: <String>['application/pdf'],
          ),
        ],
      );
    } on Exception {
      if (!mounted) return;
      _report();
      return;
    }
    if (file == null || !mounted) return;
    await _upload(
      read: file.readAsBytes,
      contentType: 'application/pdf',
      role: FanWorkMediaRole.document,
    );
  }

  /// Opens the gallery for the single artwork of a drawing, or for a
  /// character's portrait.
  Future<void> _pickImage({
    FanWorkMediaRole role = FanWorkMediaRole.cover,
    String characterId = '',
  }) async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (file == null || !mounted) return;
    await _upload(
      read: file.readAsBytes,
      contentType: file.mimeType ?? 'image/jpeg',
      role: role,
      characterId: characterId,
    );
  }

  Future<void> _upload({
    required Future<Uint8List> Function() read,
    required String contentType,
    required FanWorkMediaRole role,
    String characterId = '',
  }) async {
    final editor = _editor;
    final messenger = ScaffoldMessenger.of(context);
    final copy = FanWorkCopy.of(context);
    Uint8List bytes;
    try {
      bytes = await read();
    } on Exception catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
    if (!mounted) return;
    final result = await editor.uploadMedia(
      bytes: bytes,
      contentType: contentType,
      role: role,
      characterId: characterId,
    );
    if (!mounted) return;
    if (result.isSuccess) return;
    if (result.failureOrNull is CancelledError) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.failureOrNull?.message ?? copy.uploadFailed),
      ),
    );
  }

  /// Surfaces a picker-level failure (no file chooser available, permission
  /// denied) using the same wording as an upload failure.
  void _report() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(FanWorkCopy.of(context).uploadFailed)),
    );
  }

  /// The cast member detail sheet: name, bio, and portrait.
  ///
  /// Kept as a sheet rather than an inline expansion so the list stays scannable
  /// when a work has the maximum number of members.
  Future<void> _editCharacter(FanWorkCharacter entry) async {
    final editor = _editor;
    final result = await showModalBottomSheet<FanWorkCharacter>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CastSheet(
        entry: entry,
        onPickPortrait: () => _pickImage(
          role: FanWorkMediaRole.characterPortrait,
          characterId: entry.id,
        ),
      ),
    );
    if (!mounted) return;
    if (result == null) return;
    editor.updateDraft(
      editor.draft.copyWith(
        characters: <FanWorkCharacter>[
          for (final item in editor.draft.characters)
            if (item.id == entry.id) result else item,
        ],
      ),
    );
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
                copy.lifecycleError(editor.fieldError!),
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
                        ? (editor.uploadCanceled
                              ? copy.uploadCanceled
                              : copy.uploadFailed)
                        : copy.progress(editor.uploadPercent),
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
                              onPressed: () => editor.cancelUpload(),
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
                  if (editor.step == FanWorkEditorStep.type) ...<Widget>[
                    Text(
                      copy.chooseType,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        // Only the four creatable types appear. The legacy
                        // read-only types are never selectable.
                        for (final type in FanWorkType.creatable)
                          PubgetSelectionChip(
                            key: Key('fan-work-type-${type.name}'),
                            label: copy.typeLabel(type),
                            selected: editor.draft.type == type,
                            onSelected: (_) => editor.selectType(type),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CommonFanWorkFields(
                      draft: editor.draft,
                      onChanged: editor.updateDraft,
                    ),
                  ] else ...<Widget>[
                    CommonFanWorkFields(
                      draft: editor.draft,
                      onChanged: editor.updateDraft,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FanWorkTypeEditor(
                      draft: editor.draft,
                      work: editor.loaded,
                      onChanged: editor.updateDraft,
                      onPickDocument: _pickDocument,
                      onPickArtwork: () =>
                          _pickImage(role: FanWorkMediaRole.artwork),
                      onPickPortrait: () =>
                          _pickImage(role: FanWorkMediaRole.portrait),
                      onEditCharacter: _editCharacter,
                    ),
                    if (editor.step == FanWorkEditorStep.preview) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        copy.preview,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(editor.draft.title),
                      Text(editor.draft.description),
                      if (editor.draft.origin == FanWorkOrigin.aiGenerated)
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
                      onPressed: editor.busy ? null : () => _saveDraft(copy),
                      semanticLabel: copy.saveDraft,
                      loading: editor.saving,
                      child: Text(copy.saveDraft),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: PubgetPrimaryButton(
                      onPressed: editor.busy ? null : () => _publish(copy),
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

  Future<void> _saveDraft(FanWorkCopy copy) async {
    final editor = _editor;
    final messenger = ScaffoldMessenger.of(context);
    final result = await editor.saveDraft();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? copy.draftSaved
              : result.failureOrNull?.message ?? copy.draftKept,
        ),
      ),
    );
  }

  Future<void> _publish(FanWorkCopy copy) async {
    final editor = _editor;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    editor.goTo(FanWorkEditorStep.preview);
    final result = await editor.publish();
    if (!mounted) return;
    final published = result.valueOrNull;
    if (published != null) {
      navigator.pushReplacementNamed(FanWorkLinks.path(published.id));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.failureOrNull?.message ?? copy.publishFailed),
      ),
    );
  }
}

/// The name/bio/portrait sheet for one cast member.
class _CastSheet extends StatefulWidget {
  const _CastSheet({required this.entry, required this.onPickPortrait});

  final FanWorkCharacter entry;

  /// Opens the gallery for this member's portrait.
  ///
  /// The upload runs through the editor provider rather than being handed back
  /// as bytes, because a cast portrait is bound to a `characterId` and a
  /// `characterPortrait` role: the server mints the ticket against that slot, so
  /// the picker cannot be a plain `onPick` callback that returns a file.
  final Future<void> Function() onPickPortrait;

  @override
  State<_CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends State<_CastSheet> {
  late final TextEditingController _name;
  late final TextEditingController _bio;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.entry.name);
    _bio = TextEditingController(text: widget.entry.bio);
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = FanWorkCopy.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            copy.editCharacter,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            key: const Key('fan-work-cast-name'),
            controller: _name,
            label: copy.characterName,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextArea(
            key: const Key('fan-work-cast-bio'),
            controller: _bio,
            label: copy.characterBio,
            hint: copy.characterBioOptional,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          // The preview reads the draft rather than the `entry` snapshot, so a
          // portrait that finishes uploading while the sheet is open shows up
          // immediately instead of waiting for a save-and-reopen.
          Builder(
            builder: (context) {
              final editor = context.watch<FanWorkEditorProvider>();
              final live = editor.draft.characters
                  .where((item) => item.id == widget.entry.id)
                  .firstOrNull;
              final path = live?.imagePath ?? widget.entry.imagePath;
              // Deliberately not an `Image.network`: the stored value is a
              // private object path, not a readable URL, so a thumbnail built
              // from it would always fail. Reading it back needs a signed
              // grant, which the editor has no reason to mint. An attachment
              // marker is the honest signal that the portrait is there.
              return Row(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    child: Icon(
                      path.isNotEmpty ? Icons.person : Icons.person_outline,
                      semanticLabel: path.isEmpty
                          ? null
                          : copy.characterPortrait,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PubgetSecondaryButton(
                      key: const Key('fan-work-cast-portrait'),
                      onPressed: editor.uploading
                          ? null
                          : widget.onPickPortrait,
                      semanticLabel: copy.characterPortrait,
                      child: Text(copy.characterPortrait),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetPrimaryButton(
            key: const Key('fan-work-cast-save'),
            onPressed: _name.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(
                    widget.entry.copyWith(
                      name: _name.text.trim(),
                      bio: _bio.text.trim(),
                    ),
                  ),
            semanticLabel: copy.saveCharacter,
            child: Text(copy.saveCharacter),
          ),
        ],
      ),
    );
  }
}
