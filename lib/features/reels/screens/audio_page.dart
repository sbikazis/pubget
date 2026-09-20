import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/audio_models.dart';
import '../repositories/audio_repository.dart';
import 'reels_feed_page.dart';
import 'audio_picker_sheet.dart';

class ReelAudioPage extends StatefulWidget {
  const ReelAudioPage({required this.audioId, super.key});

  final String audioId;

  @override
  State<ReelAudioPage> createState() => _ReelAudioPageState();
}

class _ReelAudioPageState extends State<ReelAudioPage> {
  ReelAudio? _audio;
  String? _creatorName;
  var _loading = true;
  var _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    final result = await context.read<AudioRepository>().getAudio(
      widget.audioId,
    );
    if (!mounted) return;
    result.fold(
      onSuccess: (audio) => setState(() {
        _audio = audio;
        _creatorName = audio.creatorName;
      }),
      onFailure: (_) => setState(() => _error = true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF07060C),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }

    if (_error || _audio == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF07060C),
        body: Center(
          child: PubgetErrorState(message: copy.audioNotFound, onRetry: _load),
        ),
      );
    }

    final audio = _audio!;
    return Scaffold(
      backgroundColor: const Color(0xFF07060C),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: copy.searchAudioHint,
            onPressed: () => AudioPickerSheet.show(context),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: kToolbarHeight + 12,
                bottom: AppSpacing.xl,
                left: AppSpacing.md,
                right: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.royalPurple.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppSpacing.md),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          color: AppColors.gold,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              audio.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'by ${_creatorName ?? audio.creatorId} · ${audio.durationFormatted}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      PubgetPrimaryButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReelsFeedPage(audioFilter: audio.audioId),
                            ),
                          );
                        },
                        leadingIcon: Icons.movie_filter,
                        semanticLabel: copy.useAudio,
                        child: Text(copy.useAudio),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      PubgetSecondaryButton(
                        onPressed: () {
                          AudioPickerSheet.show(context);
                        },
                        leadingIcon: Icons.music_note,
                        semanticLabel: copy.browseAudio,
                        child: Text(copy.browseAudio),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '${audio.usageCount} Reels',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ReelsFeedPage(
              key: ValueKey('audio-${audio.audioId}'),
              audioFilter: audio.audioId,
            ),
          ),
        ],
      ),
    );
  }
}
