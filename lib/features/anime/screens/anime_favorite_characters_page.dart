import 'package:flutter/material.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/anime_copy.dart';
import '../models/anime_list_models.dart';
import '../providers/anime_hub_social_provider.dart';
import '../providers/anime_library_provider.dart';
import '../widgets/anime_hub_widgets.dart';
import '../widgets/anime_widgets.dart';

/// Drawer "My Favorite Characters".
///
/// Spec: a three-column grid of the member's favorite characters, without the
/// year and rating overlays the anime grid uses, with search, cached reads, an
/// offline state and long press to remove.
class AnimeFavoriteCharactersPage extends StatefulWidget {
  const AnimeFavoriteCharactersPage({this.userId, super.key});

  final String? userId;

  @override
  State<AnimeFavoriteCharactersPage> createState() =>
      _AnimeFavoriteCharactersPageState();
}

class _AnimeFavoriteCharactersPageState
    extends State<AnimeFavoriteCharactersPage> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    if (!mounted) return;
    final social = maybeAnimeHubSocial(context, listen: false);
    final userId = widget.userId;
    if (social == null || userId == null || userId.isEmpty) return;
    social.loadUser(userId);
  }

  List<CharacterFavorite> _visible(List<CharacterFavorite> all) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return all;
    return all
        .where(
          (item) =>
              item.name.toLowerCase().contains(query) ||
              item.characterId.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    final social = maybeAnimeHubSocial(context);
    final library = maybeAnimeLibrary(context);
    final all = social?.userCharacters ?? const <CharacterFavorite>[];
    final items = _visible(all);

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.favoriteCharactersTitle),
      ),
      body: AnimeHubBackdrop(
        child: Column(
          children: <Widget>[
            if (all.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: PubgetSearchField(
                  key: const Key('anime-favorite-characters-search'),
                  controller: _search,
                  hint: copy.searchHint,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            Expanded(
              child: PubgetLoadingStateView(
                state: social?.userState ?? LoadingState.initial,
                onRetry: _load,
                empty: PubgetEmptyState(
                  title: copy.charactersEmpty,
                  icon: Icons.people_outline,
                ),
                error: PubgetErrorState(
                  title: copy.unableToLoad,
                  message: social?.userFailure?.message ?? copy.checkConnection,
                  onRetry: _load,
                ),
                offline: PubgetOfflineState(
                  message: copy.offlineCached,
                  onRetry: _load,
                ),
                child: all.isEmpty
                    ? PubgetEmptyState(
                        title: copy.charactersEmpty,
                        icon: Icons.people_outline,
                      )
                    : items.isEmpty
                    ? PubgetEmptyState(
                        title: copy.nothingFoundMessage,
                        icon: Icons.search_off,
                      )
                    : AnimeHubGrid(
                        itemCount: items.length,
                        itemBuilder: (context, index) => _CharacterCell(
                          item: items[index],
                          onTap: () => AnimeLinks.openCharacter(
                            context,
                            items[index].characterId,
                          ),
                          onLongPress: library == null
                              ? null
                              : () => library.toggleCharacter(
                                  characterId: items[index].characterId,
                                  name: items[index].name,
                                  imageUrl: items[index].imageUrl,
                                ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterCell extends StatelessWidget {
  const _CharacterCell({required this.item, this.onTap, this.onLongPress});

  final CharacterFavorite item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final copy = AnimeCopy.of(context);
    final name = item.name.isEmpty ? item.characterId : item.name;
    return Semantics(
      button: true,
      label: name,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  AnimeCharacterPortrait(
                    imageUrl: item.imageUrl ?? '',
                    name: name,
                  ),
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: _HeartBadge(tooltip: copy.favorited),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              copy.favorite,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartBadge extends StatelessWidget {
  const _HeartBadge({required this.tooltip});

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.xs),
          child: Icon(Icons.favorite, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}
