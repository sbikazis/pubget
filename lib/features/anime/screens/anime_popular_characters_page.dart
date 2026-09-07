import 'package:flutter/material.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/anime_models.dart';
import '../providers/anime_hub_social_provider.dart';
import '../widgets/anime_widgets.dart';

class AnimePopularCharactersPage extends StatefulWidget {
  const AnimePopularCharactersPage({super.key});

  @override
  State<AnimePopularCharactersPage> createState() =>
      _AnimePopularCharactersPageState();
}

class _AnimePopularCharactersPageState
    extends State<AnimePopularCharactersPage> {
  @override
  void initState() {
    super.initState();
    final social = maybeAnimeHubSocial(context, listen: false);
    Future<void>.microtask(() => social?.loadPopularCharacters());
  }

  @override
  Widget build(BuildContext context) {
    final social = maybeAnimeHubSocial(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: const Text(AnimeStrings.popularCharactersTitle),
      ),
      body: PubgetLoadingStateView(
        state: social?.popularCharactersState ?? LoadingState.empty,
        onRetry: social?.loadPopularCharacters,
        empty: const PubgetEmptyState(
          title: 'No character favorites yet',
          icon: Icons.people_outline,
        ),
        error: PubgetErrorState(
          title: AnimeStrings.unableToLoad,
          message:
              social?.popularCharactersFailure?.message ??
              AnimeStrings.checkConnection,
          onRetry: social?.loadPopularCharacters,
        ),
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: social?.popularCharacters.length ?? 0,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final item = social!.popularCharacters[index];
            return PubgetCard(
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
                    width: 64,
                    child: AnimePoster(
                      images: AnimeImages(thumbnailUrl: item.imageUrl),
                      memCacheWidth: 140,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.name.isEmpty ? 'Character' : item.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text('${item.favoritesCount} favorites'),
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
