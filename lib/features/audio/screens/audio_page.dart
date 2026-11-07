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
import '../../kirari/data/kirari_repository.dart';
import '../../kirari/l10n/kirari_copy.dart';
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
  List<KirariReel> _kirariReels = const <KirariReel>[];
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
    final results = await Future.wait([
      context.read<EditsRepository>().getEditsByAudio(widget.audioId),
      context.read<KirariRepository>().getReelsByAudio(widget.audioId)
          .catchError((_) => <KirariReel>[]),
    ]);
    final result = results[0] as dynamic;
    final kirariReels = results[1] as List<KirariReel>;
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
      _kirariReels = kirariReels;
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
                if (_reels.isEmpty && _kirariReels.isEmpty)
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
                      for (final reel in _kirariReels)
                        InkWell(
                          key: ValueKey('kirari-audio-${reel.id}'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => AppNavigation.go(
                            context,
                            PubgetLinks.reelPath(reel.id),
                          ),
                          child: SizedBox(
                            width: 112,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AspectRatio(
                                    aspectRatio: 9 / 16,
                                    child: reel.coverUrl.isEmpty
                                        ? const ColoredBox(
                                            color: Colors.black12,
                                            child: Icon(Icons.movie_outlined),
                                          )
                                        : Image.network(
                                            reel.coverUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const ColoredBox(
                                              color: Colors.black12,
                                              child: Icon(Icons.movie_outlined),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  reel.caption.isEmpty ? KirariCopy.of(context).title : reel.caption,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
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
          label: copy.usedInReels(_reels.length + _kirariReels.length),
          icon: Icons.movie_outlined,
          highlighted: true,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const Key('use-kirari-audio'),
          onPressed: () => AppNavigation.go(
            context,
            '/reels/upload?audioId=${Uri.encodeComponent(widget.audioId)}',
          ),
          icon: const Icon(Icons.music_note),
          label: Text(copy.useAudio),
        ),
        if (_kirariReels.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Builder(builder: (context) {
            final attribution = _kirariReels.first.audioAttribution;
            final title = attribution['title'] as String? ?? '';
            final artist = attribution['artist'] as String? ?? '';
            final license = attribution['license'] as String? ?? '';
            final credit = attribution['attribution'] as String? ?? '';
            final sourceCreatorId = attribution['sourceCreatorId'] as String?;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_outlined),
              title: Text(title.isEmpty ? KirariCopy.of(context).originalAudio : title),
              subtitle: Text([artist, license, credit].where((value) => value.isNotEmpty).join(' · ')),
              onTap: sourceCreatorId == null
                  ? null
                  : () => AppNavigation.go(context, PubgetLinks.profilePath(sourceCreatorId)),
            );
          }),
        ],
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
