import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_states.dart';
import '../../edits/l10n/edit_copy.dart';
import '../../edits/models/edit_models.dart';
import '../../edits/repositories/edits_repository.dart';
import '../../edits/widgets/reel_metadata.dart';

/// Canonical `/hashtag/:tag` surface: tag name, Reel count and the Reels
/// already tagged with it (the `hashtags` field on the Reel document).
class HashtagPage extends StatefulWidget {
  const HashtagPage({required this.tag, super.key});

  static const routePath = '/hashtag';

  final String tag;

  @override
  State<HashtagPage> createState() => _HashtagPageState();
}

class _HashtagPageState extends State<HashtagPage> {
  List<Edit> _reels = const <Edit>[];
  var _loading = true;

  String get _normalizedTag =>
      widget.tag.trim().replaceFirst(RegExp(r'^#+'), '');

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await context.read<EditsRepository>().getEditsByHashtag(
      _normalizedTag,
    );
    if (!mounted) return;
    setState(() {
      _reels = result.valueOrNull ?? const <Edit>[];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = EditCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('#$_normalizedTag'),
        leading: AppBackButton.maybeOf(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                Text(
                  '#$_normalizedTag',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                ReelChip(
                  key: const Key('hashtag-usage'),
                  label: copy.usedInReels(_reels.length),
                  icon: Icons.tag,
                  highlighted: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_reels.isEmpty)
                  PubgetEmptyState(
                    title: copy.noHashtagReels,
                    message: copy.noHashtagReelsBody,
                    icon: Icons.tag,
                  )
                else
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final reel in _reels) ReelThumbnailTile(edit: reel),
                    ],
                  ),
              ],
            ),
    );
  }
}
