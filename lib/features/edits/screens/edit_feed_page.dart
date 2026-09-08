import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../app/app_router.dart';
import '../../../app/app_shell_scope.dart';
import '../../../core/constants/limits.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/network/network_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/services/storage_video_controller.dart';
import '../../social/models/public_profile.dart';
import '../../social/models/social_models.dart';
import '../../social/providers/social_provider.dart';
import '../../social/repositories/profile_repository.dart';
import '../../social/widgets/give_respect_sheet.dart';
import '../l10n/edit_copy.dart';
import '../models/edit_models.dart';
import '../providers/edits_provider.dart';
import '../repositories/edits_repository.dart';
import '../widgets/edit_comments_sheet.dart';

class EditFeedPage extends StatefulWidget {
  const EditFeedPage({super.key});

  @override
  State<EditFeedPage> createState() => _EditFeedPageState();
}

class _EditFeedPageState extends State<EditFeedPage> {
  final _page = PageController();
  var _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    final provider = context.read<EditsProvider>();
    Future<void>.microtask(provider.load);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    final provider = context.watch<EditsProvider>();
    final offline = context.watch<NetworkService>().isOffline;
    return Scaffold(
      backgroundColor: const Color(0xFF07060C),
      appBar: AppBar(
        leading: const AppShellMenuButton(),
        title: Text(copy.feedTitle),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _body(copy, provider, offline),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AppNavigation.go(context, '/edits/upload'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _body(EditCopy copy, EditsProvider provider, bool offline) {
    if (provider.state == LoadingState.loading ||
        provider.state == LoadingState.initial) {
      return const Center(child: PubgetSkeleton.card(width: 240, height: 320));
    }
    if (provider.state == LoadingState.empty) {
      return PubgetEmptyState(
        title: copy.noEdits,
        message: copy.noEditsMessage,
        icon: Icons.movie_filter_outlined,
        action: PubgetPrimaryButton(
          onPressed: () => AppNavigation.go(context, '/edits/upload'),
          semanticLabel: copy.uploadTitle,
          child: Text(copy.uploadTitle),
        ),
      );
    }
    if (provider.state == LoadingState.error && provider.items.isEmpty) {
      return PubgetErrorState(
        message: provider.failure?.message ?? copy.failedLoad,
        onRetry: provider.load,
      );
    }
    if (offline && provider.items.isEmpty) {
      return PubgetOfflineState(onRetry: () => provider.load(refresh: true));
    }
    return RefreshIndicator(
      onRefresh: () => provider.load(refresh: true),
      child: PageView.builder(
        controller: _page,
        scrollDirection: Axis.vertical,
        itemCount: provider.items.length,
        onPageChanged: (index) {
          setState(() => _activeIndex = index);
          provider.setActiveIndex(index);
          if (index >= provider.items.length - 2) provider.loadMore();
        },
        itemBuilder: (context, index) {
          final edit = provider.displayOf(provider.items[index]);
          final prefetch = index == _activeIndex + Limits.editPrefetchCount;
          return _EditVideoItem(
            key: ValueKey<String>(edit.id),
            edit: edit,
            active: index == _activeIndex,
            prefetch: prefetch,
            liked: provider.isLiked(edit.id),
            saved: provider.isSaved(edit.id),
          );
        },
      ),
    );
  }
}

class _EditVideoItem extends StatefulWidget {
  const _EditVideoItem({
    required this.edit,
    required this.active,
    required this.prefetch,
    required this.liked,
    required this.saved,
    super.key,
  });

  final Edit edit;
  final bool active;
  final bool prefetch;
  final bool liked;
  final bool saved;

  @override
  State<_EditVideoItem> createState() => _EditVideoItemState();
}

class _EditVideoItemState extends State<_EditVideoItem> {
  VideoPlayerController? _controller;
  PublicProfile? _profile;
  PublicProfile? _originalProfile;
  var _loadingVideo = false;
  var _impressionSent = false;
  var _viewSent = false;
  var _replayed = false;
  double _maxPercent = 0;
  String? _sessionId;
  int _lastReportedSecond = 0;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    if (widget.active || widget.prefetch) {
      _ensureController();
    }
  }

  @override
  void didUpdateWidget(covariant _EditVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active || widget.prefetch) {
      _ensureController();
    } else {
      _disposeController();
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.active && !controller.value.isPlaying) {
      _activate();
    } else if (!widget.active && controller.value.isPlaying) {
      controller.pause();
    }
  }

  @override
  void dispose() {
    _sendView(force: true);
    _disposeController();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    try {
      final repo = context.read<ProfileRepository>();
      final creator = await repo.getPublicProfile(widget.edit.displayCreatorId);
      PublicProfile? original;
      if (widget.edit.isRepost &&
          widget.edit.creatorId != widget.edit.displayCreatorId) {
        original = (await repo.getPublicProfile(widget.edit.creatorId))
            .valueOrNull;
      }
      if (!mounted) return;
      setState(() {
        _profile = creator.valueOrNull;
        _originalProfile = original;
      });
    } on ProviderNotFoundException {
      // Profile repository is optional in isolated tests.
    }
  }

  Future<void> _ensureController() async {
    if (_controller != null || _loadingVideo || !widget.edit.hasPlayableVideo) {
      return;
    }
    _loadingVideo = true;
    try {
      final controller = await createStorageVideoController(
        widget.edit.videoUrl,
      );
      await controller.initialize();
      await controller.setLooping(false);
      controller.addListener(_trackProgress);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      _loadingVideo = false;
      setState(() {});
      if (widget.active) await _activate();
    } catch (_) {
      _loadingVideo = false;
      if (mounted) setState(() {});
    }
  }

  void _disposeController() {
    _controller?.removeListener(_trackProgress);
    _controller?.dispose();
    _controller = null;
    _loadingVideo = false;
  }

  Future<void> _activate() async {
    if (!widget.edit.hasPlayableVideo) return;
    if (!_impressionSent) {
      _impressionSent = true;
      context.read<EditsProvider>().impression(
        editId: widget.edit.id,
        sessionId: _sessionId ?? widget.edit.id,
      );
    }
    final controller = _controller;
    if (controller == null || !mounted) return;
    if (_sessionId == null) {
      if (!mounted) return;
      final session = await context.read<EditsProvider>().startPlayback(
        widget.edit.id,
      );
      _sessionId = session.valueOrNull;
      if (!mounted) return;
      if (_sessionId != null && !_viewSent) {
        _viewSent = true;
        context.read<EditsProvider>().view(
          editId: widget.edit.id,
          sessionId: _sessionId!,
          percent: 0,
          seconds: 0,
          eventType: 'view',
        );
      }
    }
    if (mounted) await controller.play();
  }

  void _trackProgress() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final durationMs = controller.value.duration.inMilliseconds;
    if (durationMs <= 0) return;
    _maxPercent = (controller.value.position.inMilliseconds / durationMs * 100)
        .clamp(0, 100);
    final second = controller.value.position.inSeconds;
    if (second >= _lastReportedSecond + 5) {
      _lastReportedSecond = second;
      _sendView();
    }
    if (controller.value.position >= controller.value.duration &&
        !controller.value.isPlaying) {
      _sendView(force: true);
    }
  }

  void _sendView({bool force = false}) {
    if (_controller == null || _sessionId == null) return;
    if (_maxPercent < Limits.editQualifiedViewPercent && !force) return;
    context.read<EditsProvider>().view(
      editId: widget.edit.id,
      sessionId: _sessionId!,
      percent: _maxPercent,
      seconds: _controller!.value.position.inSeconds.toDouble(),
    );
  }

  Future<void> _replay() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.seekTo(Duration.zero);
    _sessionId = null;
    _viewSent = false;
    _maxPercent = 0;
    _lastReportedSecond = 0;
    if (!_replayed) {
      _replayed = true;
    }
    await _activate();
  }

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (ready)
          GestureDetector(
            onTap: () {
              if (controller.value.position >= controller.value.duration &&
                  !controller.value.isPlaying) {
                _replay();
                return;
              }
              setState(() {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
              });
            },
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          )
        else if (widget.edit.hasThumbnail)
          AppImageLoader(imageUrl: widget.edit.thumbnailUrl, fit: BoxFit.cover)
        else
          const ColoredBox(
            color: Color(0xFF140C22),
            child: Center(child: Icon(Icons.movie_filter_outlined, color: Colors.white54, size: 48)),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.transparent,
                Color(0xCC07060C),
              ],
            ),
          ),
        ),
        PositionedDirectional(
          start: AppSpacing.md,
          end: 84,
          bottom: AppSpacing.xl,
          child: _CreatorBlock(
            edit: widget.edit,
            profile: _profile,
            originalProfile: _originalProfile,
            copy: copy,
          ),
        ),
        PositionedDirectional(
          end: AppSpacing.sm,
          bottom: AppSpacing.xl,
          child: _ActionRail(
            edit: widget.edit,
            liked: widget.liked,
            saved: widget.saved,
            copy: copy,
          ),
        ),
      ],
    );
  }
}

class _CreatorBlock extends StatelessWidget {
  const _CreatorBlock({
    required this.edit,
    required this.profile,
    required this.originalProfile,
    required this.copy,
  });

  final Edit edit;
  final PublicProfile? profile;
  final PublicProfile? originalProfile;
  final EditCopy copy;

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>().snapshot;
    final given = social.givenRespect.where(
      (item) => item.toUserId == edit.displayCreatorId,
    );
    final isFan = given.any((item) => item.value >= SocialSnapshot.fanThreshold);
    final name = profile?.primaryName(fallback: edit.displayCreatorId) ??
        edit.displayCreatorId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            PubgetAvatar(
              imageUrl: profile?.avatarUrl,
              name: name,
              size: PubgetAvatarSize.small,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isFan)
              const PubgetBadge(label: 'Fan', compact: true),
          ],
        ),
        if (edit.isRepost) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${copy.originalCreator} · ${originalProfile?.primaryName(fallback: edit.displayCreatorId) ?? edit.displayCreatorId}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(edit.caption, style: const TextStyle(color: Colors.white)),
        if (edit.animeTag.isNotEmpty)
          Text(
            edit.animeTag,
            style: const TextStyle(color: Colors.white70),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          copy.views(edit.viewsCount),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.edit,
    required this.liked,
    required this.saved,
    required this.copy,
  });

  final Edit edit;
  final bool liked;
  final bool saved;
  final EditCopy copy;

  @override
  Widget build(BuildContext context) {
    final viewerId = context.watch<AuthProvider>().currentUser?.id;
    final provider = context.read<EditsProvider>();
    final now = DateTime.now();
    return Column(
      children: <Widget>[
        _Action(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          label: copy.compactCount(edit.likesCount),
          semanticLabel: copy.like,
          onTap: () => provider.like(edit.id, !liked),
        ),
        _Action(
          icon: Icons.mode_comment_outlined,
          label: copy.compactCount(edit.commentsCount),
          semanticLabel: copy.comment,
          onTap: () => EditCommentsSheet.show(context, edit),
        ),
        _Action(
          icon: Icons.ios_share_outlined,
          label: copy.share,
          semanticLabel: copy.share,
          onTap: () => provider.share(edit.id),
        ),
        _Action(
          icon: saved ? Icons.bookmark : Icons.bookmark_border,
          label: copy.save,
          semanticLabel: copy.save,
          onTap: () => provider.save(edit.id, save: !saved),
        ),
        if (edit.canReceiveRespectFrom(viewerId))
          _Action(
            icon: Icons.auto_awesome,
            label: copy.respect,
            semanticLabel: copy.respect,
            onTap: () {
              final given = context
                  .read<SocialProvider>()
                  .snapshot
                  .givenRespect
                  .where((item) => item.toUserId == edit.displayCreatorId);
              showGiveRespectSheet(
                context,
                toUserId: edit.displayCreatorId,
                initialValue: given.isEmpty
                    ? Limits.fanThreshold
                    : given.first.value,
              );
            },
          ),
        if (edit.canRepost(now: now, viewerId: viewerId))
          _Action(
            icon: Icons.repeat,
            label: copy.repost,
            semanticLabel: copy.repost,
            onTap: () => provider.repost(edit.id),
          ),
        _Action(
          icon: Icons.more_horiz,
          label: copy.more,
          semanticLabel: copy.more,
          onTap: () => _more(context, provider, viewerId),
        ),
      ],
    );
  }

  Future<void> _more(
    BuildContext context,
    EditsProvider provider,
    String? viewerId,
  ) async {
    final copy = EditCopy.of(context);
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(copy.report),
              onTap: () {
                Navigator.pop(context);
                provider.report(edit.id);
              },
            ),
            if (viewerId != null && viewerId == edit.creatorId)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(copy.delete),
                onTap: () {
                  Navigator.pop(context);
                  context.read<EditsRepository>().deleteEdit(edit.id);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        children: <Widget>[
          IconButton(
            onPressed: onTap,
            tooltip: semanticLabel,
            icon: Icon(icon, color: Colors.white, size: 28),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
