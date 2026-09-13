import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../app/app_route.dart';
import '../../../app/app_router.dart';
import '../../../app/app_shell_scope.dart';
import '../../../core/constants/limits.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/network/network_service.dart';
import '../../../core/theme/app_colors.dart';
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
import '../providers/edit_upload_manager.dart';
import '../providers/edits_provider.dart';
import '../repositories/edits_repository.dart';
import '../widgets/edit_action_button.dart';
import '../widgets/edit_comments_sheet.dart';
import '../../reels/reels_brand.dart';

class EditFeedPage extends StatefulWidget {
  const EditFeedPage({super.key});

  @override
  State<EditFeedPage> createState() => _EditFeedPageState();
}

class _EditFeedPageState extends State<EditFeedPage>
    with WidgetsBindingObserver {
  final _page = PageController();
  var _activeIndex = 0;
  String? _pendingHighlight;
  EditUploadManager? _uploads;
  var _appResumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final provider = context.read<EditsProvider>();
    Future<void>.microtask(() async {
      await provider.load(refresh: true);
      if (!mounted) return;
      await _focusHighlight();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uploads = context.read<EditUploadManager>();
    if (!identical(uploads, _uploads)) {
      _uploads?.removeListener(_onUploadsChanged);
      _uploads = uploads;
      _uploads!.addListener(_onUploadsChanged);
      _pullHighlight();
    }
    _readRouteHighlight();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _appResumed) return;
    setState(() => _appResumed = resumed);
  }

  void _onUploadsChanged() {
    _pullHighlight();
    _pullSoftOfferHint();
  }

  void _pullHighlight() {
    final id = _uploads?.highlightEditId;
    if (id == null || id.isEmpty) return;
    _uploads?.consumeHighlightEditId();
    _pendingHighlight = id;
    unawaited(_focusHighlight());
  }

  void _pullSoftOfferHint() {
    // Soft offer is handled via SnackBar in PubgetApp; highlight applies on accept.
  }

  void _readRouteHighlight() {
    final delegate = Router.of(context).routerDelegate;
    if (delegate is! AppRouterDelegate) return;
    final config = delegate.currentConfiguration;
    if (config is! ParameterizedRoute) return;
    if (config.path != ReelsBrand.route && config.path != '/edits') return;
    final highlight = config.parameters['highlight'];
    if (highlight == null || highlight.isEmpty) return;
    if (_pendingHighlight == highlight) return;
    _pendingHighlight = highlight;
    unawaited(_focusHighlight());
  }

  Future<void> _focusHighlight() async {
    final id = _pendingHighlight;
    if (id == null || id.isEmpty) return;
    final provider = context.read<EditsProvider>();
    final result = await context.read<EditsRepository>().getEdit(id);
    if (!mounted) return;
    final edit = result.valueOrNull;
    if (edit != null && edit.isPublished) {
      provider.promotePublished(edit);
    } else {
      await provider.load(refresh: true);
      if (!mounted) return;
    }
    final index = provider.items.indexWhere((item) => item.id == id);
    if (index < 0 || !_page.hasClients) return;
    _pendingHighlight = null;
    _activeIndex = index;
    provider.setActiveIndex(index);
    await _page.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _skipToNext() {
    final items = context.read<EditsProvider>().items;
    if (_activeIndex + 1 >= items.length) return;
    _page.animateToPage(
      _activeIndex + 1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uploads?.removeListener(_onUploadsChanged);
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    final provider = context.watch<EditsProvider>();
    final offline = context.watch<NetworkService>().isOffline;
    final shell = AppShellScope.maybeOf(context);
    final feedVisible = (shell?.isEditsVisible ?? true) && _appResumed;

    // Soft error toast for optimistic rollback (like/save).
    final actionFailure = provider.lastActionFailure;
    if (actionFailure != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<EditsProvider>().clearActionFailure();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(actionFailure.message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 1800),
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF07060C),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: const AppShellMenuButton(),
        title: Text(copy.feedTitle),
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _body(copy, provider, offline, feedVisible),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.royalPurple,
        foregroundColor: Colors.white,
        onPressed: () => AppNavigation.go(context, '/edits/upload'),
        child: const PhosphorIcon(PhosphorIconsRegular.plus, size: 26),
      ),
    );
  }

  Widget _body(
    EditCopy copy,
    EditsProvider provider,
    bool offline,
    bool feedVisible,
  ) {
    if (provider.state == LoadingState.loading ||
        provider.state == LoadingState.initial) {
      return const Center(child: PubgetSkeleton.card(width: 240, height: 320));
    }
    if (provider.state == LoadingState.empty) {
      return PubgetEmptyState(
        title: copy.noEdits,
        message: copy.noEditsMessage,
        icon: PhosphorIconsRegular.filmStrip,
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
      color: AppColors.gold,
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
          final edit = provider.items[index];
          final prefetch = index == _activeIndex + Limits.editPrefetchCount;
          final active = feedVisible && index == _activeIndex;
          return EditFeedVideoItem(
            key: ValueKey<String>(edit.id),
            edit: edit,
            active: active,
            prefetch: feedVisible && prefetch,
            onBroken: () {
              provider.skipBroken(edit.id);
              _skipToNext();
            },
          );
        },
      ),
    );
  }
}

/// Full-screen clip cell with isolated action rail and single-controller policy.
class EditFeedVideoItem extends StatefulWidget {
  const EditFeedVideoItem({
    required this.edit,
    required this.active,
    required this.prefetch,
    required this.onBroken,
    super.key,
  });

  final Edit edit;
  final bool active;
  final bool prefetch;
  final VoidCallback onBroken;

  @override
  State<EditFeedVideoItem> createState() => _EditFeedVideoItemState();
}

class _EditFeedVideoItemState extends State<EditFeedVideoItem> {
  VideoPlayerController? _controller;
  PublicProfile? _profile;
  PublicProfile? _originalProfile;
  var _loadingVideo = false;
  var _loadFailed = false;
  var _impressionSent = false;
  var _viewSent = false;
  double _maxPercent = 0;
  String? _sessionId;
  int _lastReportedSecond = 0;
  var _userPaused = false;
  var _showPlayGlyph = false;
  Timer? _glyphTimer;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    if (widget.active || widget.prefetch) {
      unawaited(_ensureController());
    }
  }

  @override
  void didUpdateWidget(covariant EditFeedVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active || widget.prefetch) {
      unawaited(_ensureController());
    } else {
      _disposeController();
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.active && !_userPaused && !controller.value.isPlaying) {
      unawaited(_activate());
    } else if (!widget.active && controller.value.isPlaying) {
      controller.pause();
    }
  }

  @override
  void dispose() {
    _glyphTimer?.cancel();
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
      // Optional in isolated tests.
    }
  }

  Future<void> _ensureController() async {
    if (_controller != null ||
        _loadingVideo ||
        _loadFailed ||
        !widget.edit.hasPlayableVideo) {
      return;
    }
    _loadingVideo = true;
    try {
      final controller = await createStorageVideoController(
        widget.edit.videoUrl,
      );
      await controller.initialize();
      // TikTok / IG Reels style seamless loop while visible.
      await controller.setLooping(true);
      controller.addListener(_trackProgress);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      _loadingVideo = false;
      setState(() {});
      if (widget.active && !_userPaused) await _activate();
    } catch (_) {
      _loadingVideo = false;
      _loadFailed = true;
      if (mounted) {
        setState(() {});
        widget.onBroken();
      }
    }
  }

  void _disposeController() {
    _controller?.removeListener(_trackProgress);
    _controller?.dispose();
    _controller = null;
    _loadingVideo = false;
  }

  Future<void> _activate() async {
    if (!widget.edit.hasPlayableVideo || !widget.active) return;
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
    if (mounted && widget.active && !_userPaused) {
      await controller.play();
    }
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
    if (mounted) setState(() {});
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

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        _userPaused = true;
        _showPlayGlyph = true;
      } else {
        controller.play();
        _userPaused = false;
        _showPlayGlyph = true;
      }
    });
    _glyphTimer?.cancel();
    _glyphTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _showPlayGlyph = false);
    });
  }

  Future<void> _seekFraction(double value) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    if (duration.inMilliseconds <= 0) return;
    final target = Duration(
      milliseconds: (duration.inMilliseconds * value.clamp(0, 1)).round(),
    );
    await controller.seekTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final offline = context.select<NetworkService, bool>((n) => n.isOffline);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Thumbnail always underneath so there is never a black void.
        if (widget.edit.hasThumbnail)
          AppImageLoader(
            imageUrl: widget.edit.thumbnailUrl,
            fit: BoxFit.cover,
          )
        else
          const ColoredBox(color: Color(0xFF140C22)),
        if (ready)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlayPause,
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio == 0
                      ? 9 / 16
                      : controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          )
        else if (_loadingVideo || (!_loadFailed && widget.edit.hasPlayableVideo))
          const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.gold,
              ),
            ),
          )
        else if (_loadFailed || (!widget.edit.hasPlayableVideo && offline))
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const PhosphorIcon(
                  PhosphorIconsRegular.warningCircle,
                  color: Colors.white70,
                  size: 36,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  offline ? copy.offlineClip : copy.brokenClip,
                  style: const TextStyle(color: Colors.white70),
                ),
                TextButton(
                  onPressed: () {
                    _loadFailed = false;
                    unawaited(_ensureController());
                  },
                  child: Text(copy.retryClip),
                ),
              ],
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x66000000),
                Colors.transparent,
                Color(0xCC07060C),
              ],
              stops: <double>[0, 0.35, 1],
            ),
          ),
        ),
        if (_showPlayGlyph)
          IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                opacity: _showPlayGlyph ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: PhosphorIcon(
                    _userPaused ? EditActionIcons.play : EditActionIcons.pause,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        PositionedDirectional(
          start: AppSpacing.md,
          end: 88,
          bottom: AppSpacing.xl + 10,
          child: _CreatorOverlay(
            edit: widget.edit,
            profile: _profile,
            originalProfile: _originalProfile,
            copy: copy,
          ),
        ),
        PositionedDirectional(
          end: AppSpacing.sm,
          bottom: AppSpacing.xl + 10,
          child: _EditActionRail(edit: widget.edit, copy: copy),
        ),
        if (ready)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Scrubber(
              controller: controller,
              onSeek: _seekFraction,
            ),
          ),
      ],
    );
  }
}

class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.controller, required this.onSeek});

  final VideoPlayerController controller;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final duration = value.duration.inMilliseconds;
    final position = duration <= 0
        ? 0.0
        : (value.position.inMilliseconds / duration).clamp(0.0, 1.0);
    return Material(
      color: Colors.transparent,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          activeTrackColor: AppColors.gold,
          inactiveTrackColor: Colors.white24,
          thumbColor: AppColors.gold,
        ),
        child: Slider(
          value: position,
          onChanged: onSeek,
        ),
      ),
    );
  }
}

class _CreatorOverlay extends StatelessWidget {
  const _CreatorOverlay({
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
    final given = context.select<SocialProvider, int>((social) {
      final matches = social.snapshot.givenRespect.where(
        (item) => item.toUserId == edit.displayCreatorId,
      );
      if (matches.isEmpty) return 0;
      return matches.first.value;
    });
    final isFan = given >= SocialSnapshot.fanThreshold;
    final name = profile?.primaryName(fallback: edit.displayCreatorId) ??
        edit.displayCreatorId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        InkWell(
          onTap: () => AppNavigation.go(
            context,
            '/profile?uid=${edit.displayCreatorId}',
          ),
          borderRadius: BorderRadius.circular(24),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: PubgetAvatar(
                  imageUrl: profile?.avatarUrl,
                  name: name,
                  size: PubgetAvatarSize.small,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    shadows: <Shadow>[
                      Shadow(blurRadius: 8, color: Colors.black54),
                    ],
                  ),
                ),
              ),
              if (isFan)
                Container(
                  margin: const EdgeInsetsDirectional.only(start: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    copy.fan,
                    style: const TextStyle(
                      color: AppColors.royalNight,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (edit.isRepost) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${copy.originalCreator} · ${originalProfile?.primaryName(fallback: edit.displayCreatorId) ?? edit.displayCreatorId}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (edit.caption.isNotEmpty)
          Text(
            edit.caption,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              height: 1.3,
              shadows: <Shadow>[Shadow(blurRadius: 6, color: Colors.black45)],
            ),
          ),
        if (edit.animeTag.isNotEmpty)
          Text(
            '#${edit.animeTag}',
            style: const TextStyle(color: AppColors.goldLight, fontSize: 13),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          copy.views(edit.viewsCount),
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Side rail — each button selects only its own slice of EditsProvider.
class _EditActionRail extends StatelessWidget {
  const _EditActionRail({required this.edit, required this.copy});

  final Edit edit;
  final EditCopy copy;

  @override
  Widget build(BuildContext context) {
    final viewerId = context.select<AuthProvider, String?>(
      (auth) => auth.currentUser?.id,
    );
    final liked = context.select<EditsProvider, bool>(
      (p) => p.isLiked(edit.id),
    );
    final saved = context.select<EditsProvider, bool>(
      (p) => p.isSaved(edit.id),
    );
    final likes = context.select<EditsProvider, int>(
      (p) => p.likesCountOf(edit.id),
    );
    final provider = context.read<EditsProvider>();
    final now = DateTime.now();

    return Column(
      children: <Widget>[
        EditActionButton(
          key: ValueKey('like-${edit.id}'),
          icon: EditActionIcons.like,
          activeIcon: EditActionIcons.likeActive,
          active: liked,
          activeColor: const Color(0xFFFF4D6D),
          animateCount: true,
          label: copy.compactCount(likes),
          semanticLabel: copy.like,
          onTap: () => provider.like(edit.id, !liked),
        ),
        EditActionButton(
          icon: EditActionIcons.comment,
          activeIcon: EditActionIcons.comment,
          label: copy.compactCount(edit.commentsCount),
          semanticLabel: copy.comment,
          onTap: () => EditCommentsSheet.show(context, edit),
        ),
        EditActionButton(
          icon: EditActionIcons.share,
          activeIcon: EditActionIcons.share,
          label: copy.share,
          semanticLabel: copy.share,
          onTap: () => _share(context, provider),
        ),
        EditActionButton(
          icon: EditActionIcons.save,
          activeIcon: EditActionIcons.saveActive,
          active: saved,
          activeColor: AppColors.gold,
          label: copy.save,
          semanticLabel: copy.save,
          onTap: () => provider.save(edit.id, save: !saved),
        ),
        if (edit.canReceiveRespectFrom(viewerId))
          EditActionButton(
            key: ValueKey('respect-${edit.id}'),
            icon: EditActionIcons.respect,
            activeIcon: EditActionIcons.respectActive,
            activeColor: AppColors.gold,
            label: copy.respect,
            semanticLabel: copy.respect,
            onTap: () => _respect(context),
          ),
        if (edit.canRepost(now: now, viewerId: viewerId))
          EditActionButton(
            icon: EditActionIcons.repost,
            activeIcon: EditActionIcons.repost,
            label: copy.repost,
            semanticLabel: copy.repost,
            onTap: () => provider.repost(edit.id),
          ),
        EditActionButton(
          icon: EditActionIcons.more,
          activeIcon: EditActionIcons.more,
          label: copy.more,
          semanticLabel: copy.more,
          onTap: () => _more(context, provider, viewerId),
        ),
      ],
    );
  }

  Future<void> _share(BuildContext context, EditsProvider provider) async {
    // Open the share sheet immediately (optimistic UX); signal in parallel.
    unawaited(provider.share(edit.id));
    final url = PubgetLinks.canonical(ReelsBrand.route);
    final text = edit.caption.isEmpty
        ? url
        : '${edit.caption}\n$url';
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, title: 'Pubget Edit'),
      );
    } catch (_) {
      if (!context.mounted) return;
      await PubgetLinks.copy(context, url, type: 'edit');
    }
  }

  Future<void> _respect(BuildContext context) async {
    final given = context
        .read<SocialProvider>()
        .snapshot
        .givenRespect
        .where((item) => item.toUserId == edit.displayCreatorId);
    final becameFan = await showGiveRespectSheet(
      context,
      toUserId: edit.displayCreatorId,
      initialValue: given.isEmpty ? Limits.fanThreshold : given.first.value,
      silentFailure: true,
    );
    if (!context.mounted || !becameFan) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(EditCopy.of(context).becameFan),
        backgroundColor: AppColors.royalPurpleDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2200),
      ),
    );
  }

  Future<void> _more(
    BuildContext context,
    EditsProvider provider,
    String? viewerId,
  ) async {
    final copy = EditCopy.of(context);
    await PubgetBottomSheet.present<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1228),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const PhosphorIcon(
                PhosphorIconsRegular.flag,
                color: Colors.white70,
              ),
              title: Text(copy.report, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                provider.report(edit.id);
              },
            ),
            if (viewerId != null && viewerId == edit.creatorId)
              ListTile(
                leading: const PhosphorIcon(
                  PhosphorIconsRegular.trash,
                  color: Colors.white70,
                ),
                title: Text(
                  copy.delete,
                  style: const TextStyle(color: Colors.white),
                ),
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
