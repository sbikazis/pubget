import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../app/app_router.dart';
import '../../../app/app_shell_scope.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/edit_models.dart';
import '../providers/edits_provider.dart';
import '../repositories/edits_repository.dart';
import '../../groups/services/storage_video_controller.dart';
import '../widgets/edit_comments_sheet.dart';

class EditFeedPage extends StatefulWidget {
  const EditFeedPage({super.key});

  @override
  State<EditFeedPage> createState() => _EditFeedPageState();
}

class _EditFeedPageState extends State<EditFeedPage> {
  final _page = PageController();

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
    final provider = context.watch<EditsProvider>();
    if (provider.state == LoadingState.loading ||
        provider.state == LoadingState.initial) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppShellMenuButton(),
          title: const Text('Edits'),
        ),
        body: const Center(child: PubgetSkeleton.card(width: 240, height: 320)),
      );
    }
    if (provider.state == LoadingState.empty) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppShellMenuButton(),
          title: const Text('Edits'),
        ),
        body: PubgetEmptyState(
          title: 'No Edits yet',
          message: 'Be the first creator to share a video.',
          icon: Icons.movie_filter_outlined,
          action: PubgetPrimaryButton(
            onPressed: () => AppNavigation.go(context, '/edits/upload'),
            semanticLabel: 'Upload an Edit',
            child: const Text('Upload an Edit'),
          ),
        ),
        floatingActionButton: _uploadButton(context),
      );
    }
    if (provider.state == LoadingState.error) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppShellMenuButton(),
          title: const Text('Edits'),
        ),
        body: PubgetErrorState(
          message: provider.failure?.message ?? 'Edits could not load.',
          onRetry: provider.load,
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: const AppShellMenuButton(),
        title: const Text('Edits'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: _page,
        scrollDirection: Axis.vertical,
        itemCount: provider.items.length,
        onPageChanged: (index) {
          provider.setActiveIndex(index);
          if (index >= provider.items.length - 2) provider.loadMore();
        },
        itemBuilder: (context, index) => _EditVideoItem(
          key: ValueKey(provider.items[index].id),
          edit: provider.items[index],
          active: index == provider.activeIndex,
        ),
      ),
      floatingActionButton: _uploadButton(context),
    );
  }

  Widget _uploadButton(BuildContext context) => FloatingActionButton(
    onPressed: () => AppNavigation.go(context, '/edits/upload'),
    child: const Icon(Icons.add),
  );
}

class _EditVideoItem extends StatefulWidget {
  const _EditVideoItem({required this.edit, required this.active, super.key});
  final Edit edit;
  final bool active;

  @override
  State<_EditVideoItem> createState() => _EditVideoItemState();
}

class _EditVideoItemState extends State<_EditVideoItem> {
  VideoPlayerController? _controller;
  Future<void>? _initialization;
  bool _viewSent = false;
  double _maxPercent = 0;
  String? _sessionId;
  int _lastReportedSecond = 0;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    final controller = await createStorageVideoController(widget.edit.videoUrl);
    _controller = controller;
    await controller.initialize();
    if (!mounted) return;
    await controller.setLooping(false);
    controller.addListener(_trackProgress);
    if (widget.active) await _activate();
  }

  Future<void> _activate() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    if (_sessionId == null) {
      final session = await context.read<EditsProvider>().startPlayback(
        widget.edit.id,
      );
      _sessionId = session.valueOrNull;
    }
    if (mounted) await controller.play();
  }

  @override
  void didUpdateWidget(covariant _EditVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller == null) return;
    if (widget.active && !controller.value.isPlaying) {
      _activate();
    } else if (!widget.active && controller.value.isPlaying) {
      controller.pause();
    }
  }

  @override
  void dispose() {
    _sendView(force: true);
    _controller?.dispose();
    super.dispose();
  }

  void _trackProgress() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration.inMilliseconds;
    if (duration <= 0) return;
    _maxPercent = (controller.value.position.inMilliseconds / duration * 100)
        .clamp(0, 100);
    final second = controller.value.position.inSeconds;
    if (second >= _lastReportedSecond + 5) {
      _lastReportedSecond = second;
      _sendView();
    }
  }

  void _sendView({bool force = false}) {
    if ((_viewSent && !force) || _controller == null || _sessionId == null) {
      return;
    }
    if (_maxPercent < 10 && !force) {
      return;
    }
    if (_maxPercent >= 90) _viewSent = true;
    context.read<EditsProvider>().view(
      editId: widget.edit.id,
      sessionId: _sessionId!,
      percent: _maxPercent,
      seconds: _controller!.value.position.inSeconds.toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Text(
            'This video could not play.',
            style: TextStyle(color: Colors.white),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done ||
          _controller == null) {
        return const Center(child: CircularProgressIndicator());
      }
      final controller = _controller!;
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(
            onTap: () => setState(() {
              controller.value.isPlaying
                  ? controller.pause()
                  : controller.play();
            }),
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          PositionedDirectional(
            start: AppSpacing.md,
            end: 76,
            bottom: AppSpacing.xl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.edit.caption,
                  style: const TextStyle(color: Colors.white),
                ),
                if (widget.edit.animeTag.isNotEmpty)
                  Text(
                    widget.edit.animeTag,
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
          PositionedDirectional(
            end: AppSpacing.md,
            bottom: AppSpacing.xl,
            child: Column(
              children: <Widget>[
                _Action(
                  icon: Icons.favorite_border,
                  label: '${widget.edit.likesCount}',
                  onTap: () =>
                      context.read<EditsProvider>().like(widget.edit.id, true),
                ),
                _Action(
                  icon: Icons.comment_outlined,
                  label: '${widget.edit.commentsCount}',
                  onTap: () => EditCommentsSheet.show(context, widget.edit),
                ),
                _Action(
                  icon: Icons.repeat,
                  label: 'Repost',
                  onTap: () =>
                      context.read<EditsProvider>().repost(widget.edit.id),
                ),
                _Action(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () => context.read<EditsRepository>().recordSignal(
                    editId: widget.edit.id,
                    type: 'share',
                  ),
                ),
                _Action(
                  icon: Icons.bookmark_border,
                  label: 'Save',
                  onTap: () => context.read<EditsRepository>().recordSignal(
                    editId: widget.edit.id,
                    type: 'save',
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      children: <Widget>[
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white, size: 30),
        ),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    ),
  );
}
