import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../app/app_shell_scope.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../../core/loading/loading_state.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../authentication/providers/onboarding_provider.dart';
import '../../groups/models/group_models.dart';
import '../../edits/providers/edits_provider.dart';
import '../../events/widgets/event_widgets.dart';
import '../../anime/widgets/anime_widgets.dart';
import '../../games/widgets/game_widgets.dart';
import '../../fan_works/widgets/fan_work_widgets.dart';
import '../../economy/models/economy_types.dart';
import '../../economy/providers/economy_provider.dart';
import '../../economy/widgets/economy_widgets.dart';
import '../../notifications/providers/unread_engine.dart';
import '../../notifications/widgets/unread_badge.dart';
import '../../search/search_provider.dart';
import '../../search/screens/search_page.dart';
import '../../social/models/public_profile.dart';
import '../models/home_models.dart';
import '../providers/home_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final home = context.read<HomeProvider>();
    final uid = auth.currentUser?.id;
    if (uid != null) {
      Future<void>.microtask(() => home.load(uid));
      final economy = maybeEconomy(context, listen: false);
      if (economy != null) {
        Future<void>.microtask(economy.load);
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<OnboardingProvider>().profile;
    final auth = context.watch<AuthProvider>();
    final home = context.watch<HomeProvider>();
    final search = context.watch<SearchProvider>();
    final unread = context.watch<UnreadEngine>();
    final economy = maybeEconomy(context);
    final copy = AppStrings.of(context);
    final name =
        profile?.displayName ?? profile?.username ?? auth.currentUser?.email;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const AppShellMenuButton(),
        title: Text(copy.tabDiscover),
        actions: <Widget>[
          if (economy != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: CoinBalanceChip(
                balance: economy.coins,
                cached: economy.offlineCached,
                onPressed: () => AppNavigation.go(context, '/store'),
              ),
            ),
          UnreadBadge(
            count: unread.notifications,
            child: PubgetIconButton(
              icon: Icons.notifications_none,
              tooltip: copy.notifications,
              onPressed: () => AppNavigation.go(context, '/notifications'),
            ),
          ),
          PubgetIconButton(
            icon: Icons.settings_outlined,
            tooltip: copy.settings,
            onPressed: () => AppNavigation.go(context, '/settings'),
          ),
          const SizedBox(width: AppSpacing.xs),
          GestureDetector(
            onTap: () => AppNavigation.go(context, '/profile'),
            child: EquippedAvatar(
              imageUrl: profile?.avatarUrl ?? auth.currentUser?.avatarUrl,
              name: name,
              frameId: economy?.equipped.frameId,
              size: PubgetAvatarSize.small,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: PubgetAtmosphere(
        child: RefreshIndicator(
          onRefresh: home.refresh,
          child: CustomScrollView(
            controller: _scroll,
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: _HomeCommandHero(
                  name: name,
                  avatarUrl: profile?.avatarUrl ?? auth.currentUser?.avatarUrl,
                  frameId: economy?.equipped.frameId,
                ),
              ),
              const SliverToBoxAdapter(child: _HomeNowActions()),
              SliverToBoxAdapter(child: _SearchBar(controller: _search)),
              if (economy != null)
                const SliverToBoxAdapter(child: _HomeAdSlot()),
              if (home.coldStart && _search.text.trim().isEmpty)
                const SliverToBoxAdapter(child: _ColdStartBanner()),
              if (_search.text.trim().isNotEmpty)
                SliverToBoxAdapter(
                  child: SearchResultsView(search: search, shrinkWrap: true),
                ),
              if (_search.text.trim().isEmpty)
                SliverList.builder(
                  itemCount: home.displayOrder.length,
                  itemBuilder: (context, index) => _SectionView(
                    key: ValueKey(home.displayOrder[index]),
                    kind: home.displayOrder[index],
                    provider: home,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCommandHero extends StatelessWidget {
  const _HomeCommandHero({
    required this.name,
    required this.avatarUrl,
    required this.frameId,
  });

  final String? name;
  final String? avatarUrl;
  final String? frameId;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final greeting = name == null || name!.isEmpty
        ? copy.homeGreeting
        : copy.welcomeUser(name!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: PubgetHeroBanner(
        key: const Key('home-command-hero'),
        title: greeting,
        subtitle: copy.homeHeroSubtitle,
        leading: EquippedAvatar(
          imageUrl: avatarUrl,
          name: name,
          frameId: frameId,
          size: PubgetAvatarSize.medium,
        ),
      ),
    );
  }
}

class _HomeNowActions extends StatelessWidget {
  const _HomeNowActions();

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PubgetSectionHeader(title: copy.homeWhatNow),
        PubgetNowActions(
          actions: <PubgetNowActionData>[
            PubgetNowActionData(
              id: 'groups',
              label: copy.nowJoinGroup,
              icon: Icons.groups_outlined,
              onPressed: () => AppNavigation.go(context, '/groups'),
            ),
            PubgetNowActionData(
              id: 'edits',
              label: copy.nowWatchEdits,
              icon: Icons.movie_filter_outlined,
              onPressed: () => AppNavigation.go(context, '/edits'),
            ),
            PubgetNowActionData(
              id: 'events',
              label: copy.nowEvents,
              icon: Icons.event_outlined,
              onPressed: () => AppNavigation.go(context, '/events'),
            ),
            PubgetNowActionData(
              id: 'games',
              label: copy.nowPlay,
              icon: Icons.sports_esports_outlined,
              onPressed: () => AppNavigation.go(context, '/games'),
            ),
            PubgetNowActionData(
              id: 'people',
              label: copy.nowPeople,
              icon: Icons.person_search_outlined,
              onPressed: () => AppNavigation.go(context, '/search'),
            ),
            PubgetNowActionData(
              id: 'anime',
              label: copy.nowAnime,
              icon: Icons.auto_awesome_outlined,
              onPressed: () => AppNavigation.go(context, '/anime'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ColdStartBanner extends StatelessWidget {
  const _ColdStartBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: PubgetCard(
        child: Text(
          AppStrings.of(context).coldStartBanner,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _HomeAdSlot extends StatefulWidget {
  const _HomeAdSlot();

  @override
  State<_HomeAdSlot> createState() => _HomeAdSlotState();
}

class _HomeAdSlotState extends State<_HomeAdSlot> {
  bool? _visible;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final economy = maybeEconomy(context, listen: false);
      setState(() {
        _visible = economy?.showAd(AdPlacement.homeFeed) ?? false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final economy = maybeEconomy(context);
    if (_visible == null) return const SizedBox.shrink();
    return AdPlacementView(
      visible: _visible!,
      adFree: economy?.isAdFree ?? false,
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SearchProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: PubgetSearchField(
        controller: controller,
        hint: AppStrings.of(context).searchHint,
        onChanged: provider.searchChanged,
        onClear: () {
          controller.clear();
          provider.searchChanged('');
        },
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.kind, required this.provider, super.key});

  final HomeSectionKind kind;
  final HomeProvider provider;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    if (kind == HomeSectionKind.editsPlaceholder) {
      final ranked = provider.feed.section('recommendedEdits').items;
      if (ranked.isNotEmpty) {
        return _SectionShell(
          title: copy.sectionEdits,
          child: SizedBox(
            height: 188,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              scrollDirection: Axis.horizontal,
              itemCount: ranked.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = ranked[index];
                final thumb = item.metadata['thumbnailUrl'] as String? ?? '';
                return PubgetMediaTile(
                  title: item.metadata['title'] as String? ?? copy.sectionEdits,
                  imageUrl: thumb,
                  onTap: () => AppNavigation.go(context, '/edits'),
                );
              },
            ),
          ),
        );
      }
      final edits = context.watch<EditsProvider>();
      if (edits.state == LoadingState.initial) {
        Future<void>.microtask(() => edits.load(limit: 4));
      }
      return _SectionShell(
        title: copy.sectionEdits,
        child: SizedBox(
          height: 188,
          child: edits.items.isEmpty
              ? const _SkeletonSection()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: edits.items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final edit = edits.items[index];
                    final title = edit.caption.trim().isNotEmpty
                        ? edit.caption
                        : edit.animeTag.trim().isNotEmpty
                        ? edit.animeTag
                        : copy.sectionEdits;
                    return PubgetMediaTile(
                      title: title,
                      imageUrl: edit.thumbnailUrl,
                      onTap: () => AppNavigation.go(context, '/edits'),
                    );
                  },
                ),
        ),
      );
    }
    if (kind == HomeSectionKind.eventsPlaceholder) {
      return const EventHomeStrip();
    }
    if (kind == HomeSectionKind.gamesPlaceholder) {
      return const GameHomeStrip();
    }
    if (kind == HomeSectionKind.fanWorksPlaceholder) {
      return const FanWorkHomeStrip();
    }
    if (kind == HomeSectionKind.animePlaceholder) {
      return const AnimeHomeStrip();
    }
    final state = provider.section(kind);
    if (state.state == LoadingState.initial) {
      Future<void>.microtask(() => provider.ensureLoaded(kind));
    }
    final title = switch (kind) {
      HomeSectionKind.promotedGroups => copy.sectionPromoted,
      HomeSectionKind.risingGroups => copy.sectionRising,
      HomeSectionKind.recommendedGroups => copy.sectionRecommended,
      HomeSectionKind.communityActivity => copy.sectionCommunity,
      HomeSectionKind.recommendedPeople => copy.sectionPeople,
      _ => copy.tabDiscover,
    };
    final reason = switch (kind) {
      HomeSectionKind.promotedGroups => copy.reasonPromoted,
      HomeSectionKind.risingGroups => copy.reasonRising,
      HomeSectionKind.recommendedGroups => copy.reasonForYou,
      _ => null,
    };
    if (state.state == LoadingState.loading && !state.hasContent) {
      return _SectionShell(title: title, child: const _SkeletonSection());
    }
    if (state.state == LoadingState.error && !state.hasContent) {
      return _SectionShell(
        title: title,
        child: PubgetErrorState(
          message: state.failure?.message ?? copy.sectionFailed,
          onRetry: () => provider.retrySection(kind),
        ),
      );
    }
    if (state.state == LoadingState.empty) {
      return _SectionShell(
        title: title,
        child: PubgetEmptyState(
          compact: true,
          icon: kind == HomeSectionKind.recommendedPeople
              ? Icons.person_search_outlined
              : Icons.groups_outlined,
          title: copy.nothingHereYet,
          message: kind == HomeSectionKind.recommendedPeople
              ? copy.findPeopleHint
              : copy.discoverGroupsHint,
          action: PubgetTextButton(
            onPressed: () => AppNavigation.go(
              context,
              kind == HomeSectionKind.recommendedPeople ? '/search' : '/groups',
            ),
            semanticLabel: kind == HomeSectionKind.recommendedPeople
                ? copy.searchPeople
                : copy.exploreGroups,
            child: Text(
              kind == HomeSectionKind.recommendedPeople
                  ? copy.searchPeople
                  : copy.exploreGroups,
            ),
          ),
        ),
      );
    }
    return _SectionShell(
      title: title,
      child: state.groups.isNotEmpty
          ? _GroupCarousel(
              groups: state.groups,
              hasMore: state.hasMore,
              isLoadingMore: state.state == LoadingState.loadingMore,
              onLoadMore: () => provider.loadMore(kind),
              reason: reason,
              highlighted: kind == HomeSectionKind.promotedGroups,
            )
          : _PeopleCarousel(
              people: state.people,
              hasMore: state.hasMore,
              isLoadingMore: state.state == LoadingState.loadingMore,
              onLoadMore: () => provider.loadMore(kind),
            ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PubgetSectionHeader(title: title),
        child,
      ],
    ),
  );
}

class _GroupCarousel extends StatelessWidget {
  const _GroupCarousel({
    required this.groups,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
    this.reason,
    this.highlighted = false,
  });
  final List<Group> groups;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final String? reason;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return SizedBox(
      height: 214,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: groups.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == groups.length) {
            return SizedBox(
              width: 120,
              child: Center(
                child: isLoadingMore
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: onLoadMore,
                        child: Text(copy.loadMore),
                      ),
              ),
            );
          }
          final group = groups[index];
          return PubgetGroupTile(
            name: group.name,
            imageUrl: group.imageUrl,
            description: group.description,
            typeLabel: copy.groupTypeLabel(group.type.name),
            reason: reason,
            highlighted: highlighted,
            meta: copy.membersCount(group.membersCount),
            onTap: () =>
                AppNavigation.go(context, '/group?groupId=${group.id}'),
          );
        },
      ),
    );
  }
}

class _PeopleCarousel extends StatelessWidget {
  const _PeopleCarousel({
    required this.people,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });
  final List<PublicProfile> people;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return SizedBox(
      height: 156,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: people.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == people.length) {
            return SizedBox(
              width: 120,
              child: Center(
                child: isLoadingMore
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: onLoadMore,
                        child: Text(copy.loadMore),
                      ),
              ),
            );
          }
          final person = people[index];
          return PubgetPersonTile(
            name: person.username ?? copy.pubgetUser,
            avatarUrl: person.avatarUrl,
            onTap: () =>
                AppNavigation.go(context, '/profile?uid=${person.uid}'),
          );
        },
      ),
    );
  }
}

class _SkeletonSection extends StatelessWidget {
  const _SkeletonSection();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 214,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      scrollDirection: Axis.horizontal,
      itemCount: 2,
      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
      itemBuilder: (_, _) => SizedBox(
        width: 248,
        child: PubgetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const PubgetSkeleton(height: 18, width: 150),
              const SizedBox(height: AppSpacing.sm),
              const PubgetSkeleton(height: 14, width: 200),
              const SizedBox(height: AppSpacing.xs),
              const PubgetSkeleton(height: 14, width: 170),
            ],
          ),
        ),
      ),
    ),
  );
}
