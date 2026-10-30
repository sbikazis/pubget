import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_image_loader.dart';
import '../../../core/widgets/pubget_avatar.dart';
import '../../../core/widgets/pubget_states.dart';
import '../../edits/l10n/edit_copy.dart';
import '../../edits/models/edit_models.dart';
import '../../edits/repositories/edits_repository.dart';
import '../../edits/widgets/reel_metadata.dart';
import '../../groups/services/storage_video_controller.dart';
import '../../social/models/public_profile.dart';
import '../../social/repositories/profile_repository.dart';

/// Canonical `/reel/:reelId` surface.
///
/// Reads the published Reel document through the existing [EditsRepository]
/// and exposes the metadata the backend already stores.
class ReelDetailsPage extends StatefulWidget {
  const ReelDetailsPage({required this.reelId, super.key});

  static const routePath = '/reel';

  final String reelId;

  @override
  State<ReelDetailsPage> createState() => _ReelDetailsPageState();
}

class _ReelDetailsPageState extends State<ReelDetailsPage> {
  Edit? _edit;
  PublicProfile? _creator;
  VideoPlayerController? _controller;
  var _loading = true;
  var _videoFailed = false;
  var _initializingVideo = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _videoFailed = false;
    });
    final result = await context.read<EditsRepository>().getEdit(widget.reelId);
    if (!mounted) return;
    final edit = result.valueOrNull;
    PublicProfile? creator;
    if (edit != null) {
      creator = await _loadCreator(edit.displayCreatorId);
      if (!mounted) return;
    }
    setState(() {
      _edit = edit;
      _creator = creator;
      _loading = false;
    });
    if (edit != null && edit.hasPlayableVideo) {
      unawaited(_ensureVideo());
    }
  }

  Future<PublicProfile?> _loadCreator(String userId) async {
    if (userId.trim().isEmpty) return null;
    try {
      final profiles = context.read<ProfileRepository>();
      final result = await profiles.getPublicProfile(userId);
      return result.valueOrNull;
    } catch (_) {
      // Profile provider or profile document may be unavailable.
      return null;
    }
  }

  Future<void> _ensureVideo() async {
    if (_controller != null || _initializingVideo || _videoFailed) return;
    final edit = _edit;
    if (edit == null || !edit.hasPlayableVideo) return;
    _initializingVideo = true;
    try {
      final controller = await createStorageVideoController(edit.videoUrl);
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializingVideo = false;
      });
      await controller.play();
    } catch (_) {
      _initializingVideo = false;
      _videoFailed = true;
      if (mounted) setState(() {});
    }
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  Future<void> _share() async {
    final edit = _edit;
    if (edit == null) return;
    await PubgetLinks.share(
      context,
      url: PubgetLinks.reel(edit.id),
      title: 'Pubget Reel',
      type: 'edit',
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    final edit = _edit;
    return Scaffold(
      appBar: AppBar(
        title: Text(copy.reelDetails),
        leading: AppBackButton.maybeOf(context),
        actions: <Widget>[
          IconButton(
            key: const Key('reel-share'),
            tooltip: copy.share,
            icon: const Icon(Icons.ios_share),
            onPressed: edit == null ? null : _share,
          ),
        ],
      ),
      body: _body(copy, edit),
    );
  }

  Widget _body(EditCopy copy, Edit? edit) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (edit == null) {
      return PubgetErrorState(
        title: copy.reelUnavailable,
        message: copy.reelUnavailableBody,
        onRetry: _load,
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: <Widget>[
        _videoArea(edit),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _creatorRow(edit),
              if (edit.caption.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  edit.caption,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              if (edit.animeTag.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                ReelChip(
                  label: copy.animeTagOf(edit.animeTag),
                  icon: Icons.local_movies_outlined,
                  highlighted: true,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              ReelAudioAttribution(edit: edit, creatorName: _creatorName(edit)),
              if (edit.hashtags.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                ReelHashtagChips(hashtags: edit.hashtags),
              ],
              if (edit.mentions.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                ReelMentionChips(mentions: edit.mentions),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  if (edit.characterIds.isNotEmpty)
                    ReelChip(
                      label: copy.charactersCount(edit.characterIds.length),
                      icon: Icons.theater_comedy_outlined,
                    ),
                  ReelRemixBadge(allowRemix: edit.allowRemix),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ReelEngagementCounters(edit: edit),
            ],
          ),
        ),
      ],
    );
  }

  Widget _videoArea(Edit edit) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: GestureDetector(
        key: const Key('reel-video-area'),
        onTap: ready ? _togglePlayback : null,
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (edit.hasThumbnail)
                AppImageLoader(imageUrl: edit.thumbnailUrl, fit: BoxFit.cover),
              if (ready) VideoPlayer(controller),
              if (!ready && !_videoFailed && edit.hasPlayableVideo)
                const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              if (_videoFailed)
                const Center(
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white70,
                    size: 36,
                  ),
                ),
              if (ready)
                Center(
                  child: AnimatedOpacity(
                    opacity: controller.value.isPlaying ? 0 : 1,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white70,
                      size: 56,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _creatorRow(Edit edit) {
    final copy = EditCopy.of(context);
    final name = _creatorName(edit);
    return InkWell(
      key: const Key('reel-creator'),
      borderRadius: BorderRadius.circular(16),
      onTap: edit.displayCreatorId.isEmpty
          ? null
          : () => AppNavigation.go(
              context,
              PubgetLinks.profilePath(edit.displayCreatorId),
            ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          children: <Widget>[
            PubgetAvatar(
              imageUrl: _creator?.avatarUrl,
              name: name,
              size: PubgetAvatarSize.medium,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (edit.isRepost)
                    Text(
                      copy.originalCreator,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  String _creatorName(Edit edit) {
    final profileName = _creator?.primaryName(fallback: '');
    if (profileName != null && profileName.trim().isNotEmpty) {
      return profileName.trim();
    }
    return EditCopy.of(context).creatorFallback;
  }
}
