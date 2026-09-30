import 'package:flutter/material.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/anime_copy.dart';
import '../providers/anime_hub_social_provider.dart';
import '../widgets/anime_hub_drawer.dart';
import '../widgets/anime_hub_widgets.dart';
import '../widgets/anime_ranked_cards.dart';
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
        title: Text(AnimeCopy.of(context).popularCharactersTitle),
      ),
      drawer: AnimeHubDrawer(current: '/anime/characters'),
      body: PubgetLoadingStateView(
        state: social?.popularCharactersState ?? LoadingState.empty,
        onRetry: social?.loadPopularCharacters,
        empty: PubgetEmptyState(
          title: AnimeCopy.of(context).noRatingsYet,
          icon: Icons.people_outline,
        ),
        error: PubgetErrorState(
          title: AnimeCopy.of(context).unableToLoad,
          message:
              social?.popularCharactersFailure?.message ??
              AnimeCopy.of(context).checkConnection,
          onRetry: social?.loadPopularCharacters,
        ),
        child: AnimeHubGrid(
          itemCount: social?.popularCharacters.length ?? 0,
          itemBuilder: (context, index) {
            final item = social!.popularCharacters[index];
            return AnimeRankedCharacterCard(
              key: Key('character-rank-$index'),
              rank: index + 1,
              name: item.name,
              imageUrl: item.imageUrl ?? '',
              likes: item.favoritesCount,
              heroTag: animeCharacterHeroTag(item.characterId),
              onTap: () => AnimeLinks.openCharacter(context, item.characterId),
            );
          },
        ),
      ),
    );
  }
}
