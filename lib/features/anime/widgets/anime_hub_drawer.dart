import 'package:flutter/material.dart';

import '../../../app/app_router.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/l10n/app_strings.dart';
import '../l10n/anime_copy.dart';
import '../theme/anime_hub_colors.dart';
import 'anime_hub_widgets.dart';

/// The six destinations that live inside the Anime Hub.
///
/// The app's main drawer deliberately keeps a single "Anime" entry, so these
/// live in the hub's own drawer instead of being flattened into the global one.
enum AnimeHubDestinations {
  updated(
    id: 'updated',
    path: '/anime/updated',
    icon: Icons.new_releases_outlined,
  ),
  search(id: 'search', path: '/anime/search', icon: Icons.search_rounded),
  ratings(
    id: 'ratings',
    path: '/anime/ratings',
    icon: Icons.emoji_events_outlined,
  ),
  library(
    id: 'library',
    path: '/anime/library',
    icon: Icons.bookmarks_outlined,
  ),
  favoriteCharacters(
    id: 'characters-favorites',
    path: '/anime/characters/favorites',
    icon: Icons.favorite_outline,
  ),
  popularCharacters(
    id: 'characters',
    path: '/anime/characters',
    icon: Icons.people_outline,
  );

  const AnimeHubDestinations({
    required this.id,
    required this.path,
    required this.icon,
  });

  final String id;
  final String path;
  final IconData icon;

  /// The label always comes from the translation map, never a literal here.
  String label(AppStrings app, AnimeCopy copy) => switch (this) {
    AnimeHubDestinations.updated => copy.latestUpdates,
    AnimeHubDestinations.search => copy.openSearch,
    AnimeHubDestinations.ratings => copy.malRankingTitle,
    AnimeHubDestinations.library => copy.libraryTitle,
    AnimeHubDestinations.favoriteCharacters => copy.favoriteCharactersTitle,
    AnimeHubDestinations.popularCharacters => copy.popularCharactersTitle,
  };
}

/// Drawer shown by every Anime Hub page, listing the six hub destinations.
class AnimeHubDrawer extends StatelessWidget {
  const AnimeHubDrawer({required this.current, super.key});

  /// The route currently on screen, so the active row can be highlighted.
  final String current;

  @override
  Widget build(BuildContext context) {
    final app = AppStrings.of(context);
    final copy = AnimeCopy.of(context);
    final hub = AnimeHubColors.of(context);
    final active = current;
    return Drawer(
      child: AnimeHubBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: AnimeHubWordmark(subtitle: copy.hubTitle),
              ),
              const Divider(height: 1),
              for (final destination in AnimeHubDestinations.values)
                ListTile(
                  key: Key('hub-drawer-${destination.id}'),
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  selected: active == destination.path,
                  selectedTileColor: hub.royalPurple.withValues(alpha: 0.16),
                  leading: Icon(
                    destination.icon,
                    color: active == destination.path
                        ? hub.activeBlue
                        : hub.royalPurple,
                  ),
                  title: Text(
                    destination.label(app, copy),
                    style: active == destination.path
                        ? TextStyle(
                            fontWeight: FontWeight.w800,
                            color: hub.activeBlue,
                          )
                        : null,
                  ),
                  onTap: () => _open(context, destination),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, AnimeHubDestinations destination) {
    final delegate = Router.of(context).routerDelegate as AppRouterDelegate;
    Scaffold.maybeOf(context)?.closeDrawer();
    delegate.setNewRoutePath(AppRouter.routeFromString(destination.path));
  }
}

/// Convenience wrapper that gives a hub page its scaffold, drawer and backdrop.
class AnimeHubScaffold extends StatelessWidget {
  const AnimeHubScaffold({
    required this.current,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    super.key,
  });

  final String current;
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text(title), actions: actions),
      drawer: AnimeHubDrawer(current: current),
      body: AnimeHubBackdrop(child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// The blue the hub uses for "you are here" selection.
///
/// It sits outside the purple/gold identity pair on purpose: the active row has
/// to stay readable against a purple-tinted surface, which gold does not.
extension AnimeHubActiveColor on AnimeHubColors {
  Color get activeBlue => const Color(0xFF7FB2FF);
}

/// Shared radius so hub cards, sheets and the hero agree on their corners.
const double animeHubCardRadius = AppRadius.md;
