import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_avatar.dart';
import '../../../core/widgets/pubget_states.dart';
import '../../edits/l10n/edit_copy.dart';
import '../../edits/models/edit_models.dart';
import '../../edits/repositories/edits_repository.dart';
import '../../edits/widgets/reel_metadata.dart';
import '../../social/models/public_profile.dart';
import '../../social/repositories/profile_repository.dart';

/// Canonical `/audio/:audioId` surface.
///
/// The backend records an `audioId` on each Reel; there is no separate audio
/// document service in this codebase, so attribution, usage and related Reels
/// are derived from the published Reels that share the id.
class AudioPage extends StatefulWidget {
  const AudioPage({required this.audioId, super.key});

  static const routePath = '/audio';

  final String audioId;

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  List<Edit> _reels = const <Edit>[];
  PublicProfile? _creator;
  Edit? _originalReel;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await context.read<EditsRepository>().getEditsByAudio(
      widget.audioId,
    );
    if (!mounted) return;
    final reels = result.valueOrNull ?? const <Edit>[];
    final original = _oldest(reels);
    PublicProfile? creator;
    if (original != null) {
      try {
        final profiles = context.read<ProfileRepository>();
        creator = (await profiles.getPublicProfile(
          original.displayCreatorId,
        )).valueOrNull;
      } catch (_) {
        creator = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _reels = reels;
      _originalReel = original;
      _creator = creator;
      _loading = false;
    });
  }

  Edit? _oldest(List<Edit> reels) {
    Edit? oldest;
    for (final reel in reels) {
      final stamp = reel.publishedAt ?? reel.createdAt;
      final oldestStamp = oldest?.publishedAt ?? oldest?.createdAt;
      if (oldest == null ||
          (stamp != null &&
              (oldestStamp == null || stamp.isBefore(oldestStamp)))) {
        oldest = reel;
      }
    }
    return oldest;
  }

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(copy.audio),
        leading: AppBackButton.maybeOf(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                _header(copy),
                const SizedBox(height: AppSpacing.lg),
                if (_reels.isEmpty)
                  PubgetEmptyState(
                    title: copy.noAudioReels,
                    message: copy.noAudioReelsBody,
                    icon: Icons.music_off_outlined,
                  )
                else ...<Widget>[
                  Text(
                    copy.relatedReels,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final reel in _reels) ReelThumbnailTile(edit: reel),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Widget _header(EditCopy copy) {
    final creatorName = _creator?.primaryName(fallback: '') ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.music_note, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                copy.originalAudio,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ReelChip(
          key: const Key('audio-usage'),
          label: copy.usedInReels(_reels.length),
          icon: Icons.movie_outlined,
          highlighted: true,
        ),
        if (_originalReel != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          InkWell(
            key: const Key('audio-source-creator'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => AppNavigation.go(
              context,
              PubgetLinks.profilePath(_originalReel!.displayCreatorId),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  PubgetAvatar(
                    imageUrl: _creator?.avatarUrl,
                    name: creatorName,
                    size: PubgetAvatarSize.medium,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          creatorName.isEmpty
                              ? copy.creatorFallback
                              : creatorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          copy.audioSource,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ReelChip(
              key: const Key('audio-original-reel'),
              label: copy.openOriginalReel,
              icon: Icons.play_circle_outline,
              onTap: () => AppNavigation.go(
                context,
                PubgetLinks.reelPath(_originalReel!.id),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
