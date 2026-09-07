import 'package:flutter/material.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/anime_copy.dart';
import '../models/anime_models.dart';
import '../providers/anime_hub_social_provider.dart';
import '../widgets/anime_widgets.dart';

class AnimeRatingsPage extends StatefulWidget {
  const AnimeRatingsPage({super.key});

  @override
  State<AnimeRatingsPage> createState() => _AnimeRatingsPageState();
}

class _AnimeRatingsPageState extends State<AnimeRatingsPage> {
  @override
  void initState() {
    super.initState();
    final social = maybeAnimeHubSocial(context, listen: false);
    Future<void>.microtask(() => social?.loadTopRated());
  }

  @override
  Widget build(BuildContext context) {
    final social = maybeAnimeHubSocial(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(AnimeCopy.of(context).ratingsTitle),
      ),
      body: PubgetLoadingStateView(
        state: social?.topState ?? LoadingState.empty,
        onRetry: social?.loadTopRated,
        empty: PubgetEmptyState(
          title: AnimeCopy.of(context).noRatingsYet,
          icon: Icons.star_outline,
        ),
        error: PubgetErrorState(
          title: AnimeCopy.of(context).unableToLoad,
          message:
              social?.topFailure?.message ??
              AnimeCopy.of(context).checkConnection,
          onRetry: social?.loadTopRated,
        ),
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: social?.topRated.length ?? 0,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final item = social!.topRated[index];
            return PubgetCard(
              onTap: () => AnimeLinks.openDetails(context, item.animeId),
              child: Row(
                children: <Widget>[
                  Text(
                    '${index + 1}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 56,
                    child: AnimePoster(
                      images: AnimeImages(thumbnailUrl: item.imageUrl),
                      memCacheWidth: 120,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.title.isEmpty ? 'Anime' : item.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${item.averageScore.toStringAsFixed(1)} · ${item.ratingCount} ratings',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
