import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/audio_models.dart';
import '../providers/audio_provider.dart';
import '../repositories/audio_repository.dart';

class AudioPickerSheet extends StatefulWidget {
  const AudioPickerSheet({super.key, this.onPicked});

  final ValueChanged<ReelAudio>? onPicked;

  static Future<ReelAudio?> show(
    BuildContext context, {
    ValueChanged<ReelAudio>? onPicked,
  }) {
    return PubgetBottomSheet.present<ReelAudio?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AudioPickerSheet(onPicked: onPicked),
    );
  }

  @override
  State<AudioPickerSheet> createState() => _AudioPickerSheetState();
}

class _AudioPickerSheetState extends State<AudioPickerSheet> {
  final _searchController = TextEditingController();
  var _searchQuery = '';
  var _searching = false;
  List<ReelAudio> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    final audioProvider = context.read<AudioProvider>();
    Future<void>.microtask(audioProvider.load);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _searchQuery) return;
    _searchQuery = query;
    if (query.isEmpty) {
      setState(() => _searchResults = []);
    } else {
      _debouncedSearch();
    }
  }

  Future<void> _debouncedSearch() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    if (_searchController.text.trim() != _searchQuery) return;
    if (_searchQuery.isEmpty) return;
    setState(() => _searching = true);
    final result = await context.read<AudioRepository>().searchAudios(
      query: _searchQuery,
    );
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searchResults = result.valueOrNull ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final provider = context.watch<AudioProvider>();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: copy.searchAudioHint,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      },
                    ),
                ],
              ),
            ),
            Flexible(child: _buildContent(copy, provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppStrings copy, AudioProvider provider) {
    if (_searchQuery.isNotEmpty) {
      if (_searching) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_searchResults.isEmpty) {
        return Center(
          child: Text(
            copy.noAudioFound,
            style: TextStyle(color: Colors.white70),
          ),
        );
      }
      return _AudioList(audios: _searchResults, onPicked: _onPicked);
    }

    switch (provider.state) {
      case LoadingState.loading:
      case LoadingState.initial:
        return const Center(child: CircularProgressIndicator());
      case LoadingState.empty:
        return Center(
          child: Text(
            copy.noAudioAvailable,
            style: TextStyle(color: Colors.white70),
          ),
        );
      case LoadingState.error:
        return Center(
          child: PubgetErrorState(
            message: provider.failure?.message ?? copy.sectionFailed,
            onRetry: () => provider.load(),
          ),
        );
      case LoadingState.offline:
        return Center(
          child: PubgetOfflineState(onRetry: () => provider.load()),
        );
      case LoadingState.loaded:
      case LoadingState.loadingMore:
      case LoadingState.refreshing:
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
              provider.loadMore();
            }
            return false;
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: provider.items.length + (provider.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= provider.items.length) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _AudioTile(audio: provider.items[index], onTap: _onPicked);
            },
          ),
        );
    }
  }

  void _onPicked(ReelAudio audio) {
    widget.onPicked?.call(audio);
    Navigator.of(context).pop(audio);
  }
}

class _AudioList extends StatelessWidget {
  const _AudioList({required this.audios, required this.onPicked});
  final List<ReelAudio> audios;
  final ValueChanged<ReelAudio> onPicked;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: audios.length,
      itemBuilder: (context, index) =>
          _AudioTile(audio: audios[index], onTap: onPicked),
    );
  }
}

class _AudioTile extends StatelessWidget {
  const _AudioTile({required this.audio, required this.onTap});
  final ReelAudio audio;
  final ValueChanged<ReelAudio> onTap;

  @override
  Widget build(BuildContext context) {
    final isReady = audio.isReady;
    return ListTile(
      onTap: isReady ? () => onTap(audio) : null,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isReady
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(
          isReady ? Icons.music_note : Icons.hourglass_empty,
          color: isReady ? AppColors.gold : Colors.white.withValues(alpha: 0.5),
          size: 24,
        ),
      ),
      title: Text(
        audio.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${audio.creatorId} · ${audio.durationFormatted} · ${audio.usageCount} uses',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 12,
        ),
      ),
      trailing: isReady
          ? Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.5),
            )
          : const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    );
  }
}
