import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../authentication/providers/onboarding_provider.dart';
import '../../social/providers/profile_provider.dart';
import '../models/anime_list_models.dart';
import '../models/anime_models.dart';
import '../providers/anime_hub_social_provider.dart';
import '../providers/anime_library_provider.dart';
import '../widgets/anime_widgets.dart';

class AnimeMyPage extends StatefulWidget {
  const AnimeMyPage({this.userId, super.key});

  final String? userId;

  @override
  State<AnimeMyPage> createState() => _AnimeMyPageState();
}

class _AnimeMyPageState extends State<AnimeMyPage> {
  @override
  void initState() {
    super.initState();
    final viewerId = context.read<AuthProvider>().currentUser?.id;
    final target = widget.userId ?? viewerId;
    final social = maybeAnimeHubSocial(context, listen: false);
    final library = maybeAnimeLibrary(context, listen: false);
    Future<void>.microtask(() async {
      if (target != null) await social?.loadUser(target);
      if (target != null && target == viewerId) await library?.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewerId = context.watch<AuthProvider>().currentUser?.id;
    final target = widget.userId ?? viewerId;
    final own = target != null && target == viewerId;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: AppBackButton.maybeOf(context),
          title: Text(
            own ? AnimeStrings.myAnimeTitle : AnimeStrings.theirAnimeTitle,
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'Favorite characters'),
              Tab(text: 'Favorite anime'),
              Tab(text: 'Lists'),
              Tab(text: 'Ratings'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _FavoriteCharactersTab(own: own),
            _FavoriteAnimeTab(own: own, userId: target),
            _ListsTab(own: own),
            _RatingsTab(),
          ],
        ),
      ),
    );
  }
}

class _FavoriteCharactersTab extends StatelessWidget {
  const _FavoriteCharactersTab({required this.own});

  final bool own;

  @override
  Widget build(BuildContext context) {
    final social = maybeAnimeHubSocial(context);
    final library = maybeAnimeLibrary(context);
    final items = social?.userCharacters ?? const [];
    if ((social?.userState ?? LoadingState.loading) == LoadingState.loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: PubgetSkeleton.card(height: 160),
      );
    }
    if (items.isEmpty) {
      return const PubgetEmptyState(
        title: 'No favorite characters yet',
        icon: Icons.people_outline,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final item = items[index];
        return PubgetCard(
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 56,
                child: AnimePoster(
                  images: AnimeImages(thumbnailUrl: item.imageUrl),
                  memCacheWidth: 120,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  item.name.isEmpty ? item.characterId : item.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (own)
                PubgetIconButton(
                  icon: Icons.favorite,
                  tooltip: AnimeStrings.favorited,
                  onPressed: library == null
                      ? null
                      : () => library.toggleCharacter(
                          characterId: item.characterId,
                          name: item.name,
                          imageUrl: item.imageUrl,
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FavoriteAnimeTab extends StatelessWidget {
  const _FavoriteAnimeTab({required this.own, required this.userId});

  final bool own;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final ids = own
        ? context.watch<OnboardingProvider>().profile?.favoriteAnimeIds ??
              const <String>[]
        : context.watch<ProfileProvider>().publicProfile?.favoriteAnimeIds ??
              const <String>[];
    if (ids.isEmpty) {
      return const PubgetEmptyState(
        title: 'No favorite anime yet',
        icon: Icons.favorite_border,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: ids.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final id = ids[index];
        return PubgetCard(
          onTap: () => AnimeLinks.openDetails(context, id),
          child: Text(id, style: Theme.of(context).textTheme.titleMedium),
        );
      },
    );
  }
}

class _ListsTab extends StatelessWidget {
  const _ListsTab({required this.own});

  final bool own;

  @override
  Widget build(BuildContext context) {
    final social = maybeAnimeHubSocial(context);
    final library = maybeAnimeLibrary(context);
    final statuses = AnimeListStatus.values
        .where((status) => status != AnimeListStatus.favorites)
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        for (final status in statuses) ...<Widget>[
          Text(status.label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          ..._entriesFor(status, own: own, social: social, library: library).map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: PubgetCard(
                onTap: () => AnimeLinks.openDetails(context, entry.animeId),
                child: Text(
                  entry.title.isEmpty ? entry.animeId : entry.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ],
    );
  }

  List<AnimeListEntry> _entriesFor(
    AnimeListStatus status, {
    required bool own,
    required AnimeHubSocialProvider? social,
    required AnimeLibraryProvider? library,
  }) {
    if (own && library != null) return library.byStatus(status);
    return (social?.userList ?? const <AnimeListEntry>[])
        .where((entry) => entry.status == status)
        .toList(growable: false);
  }
}

class _RatingsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final social = maybeAnimeHubSocial(context);
    final items = social?.userRatings ?? const [];
    if (items.isEmpty) {
      return const PubgetEmptyState(
        title: AnimeStrings.noRatingsYet,
        icon: Icons.star_outline,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final item = items[index];
        return PubgetCard(
          onTap: () => AnimeLinks.openDetails(context, item.animeId),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.title.isEmpty ? item.animeId : item.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                item.overall.toStringAsFixed(1),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
