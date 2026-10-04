import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../edits/models/edit_models.dart';
import '../../edits/providers/edits_provider.dart';

/// Segmented control for switching between Reels feed types.
class ReelsFeedSwitcher extends StatelessWidget {
  const ReelsFeedSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final provider = context.watch<EditsProvider>();

    return SegmentedButton<FeedType>(
      segments: <ButtonSegment<FeedType>>[
        ButtonSegment<FeedType>(
          value: FeedType.forYou,
          label: Text(copy.feedForYou),
          icon: const Icon(Icons.home_outlined),
        ),
        ButtonSegment<FeedType>(
          value: FeedType.following,
          label: Text(copy.feedFollowing),
          icon: const Icon(Icons.person_outline),
        ),
        ButtonSegment<FeedType>(
          value: FeedType.trending,
          label: Text(copy.feedTrending),
          icon: const Icon(Icons.trending_up_outlined),
        ),
      ],
      selected: <FeedType>{provider.feedType},
      onSelectionChanged: (selection) {
        context.read<EditsProvider>().setFeedType(selection.first);
      },
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.royalPurple;
          }
          return Colors.white.withValues(alpha: 0.05);
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.white.withValues(alpha: 0.7);
        }),
        side: WidgetStateProperty.resolveWith<BorderSide>((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide.none;
          }
          return BorderSide(color: Colors.white.withValues(alpha: 0.1));
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        ),
      ),
      showSelectedIcon: false,
      multiSelectionEnabled: false,
    );
  }
}