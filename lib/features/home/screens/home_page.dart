import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../../core/loading/loading_state.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../authentication/providers/onboarding_provider.dart';
import '../../groups/models/group_models.dart';
import '../../edits/providers/edits_provider.dart';
import '../../events/models/event_models.dart';
import '../../events/models/event_type_registry.dart';
import '../../events/widgets/event_widgets.dart';
import '../../anime/models/anime_models.dart';
import '../../anime/widgets/anime_widgets.dart';
import '../../notifications/providers/unread_engine.dart';
import '../../notifications/widgets/unread_badge.dart';
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
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final home = context.read<HomeProvider>();
    final uid = auth.currentUser?.id;
    if (uid != null) {
      Future<void>.microtask(() => home.load(uid));
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
    final unread = context.watch<UnreadEngine>();
    final name =
        profile?.displayName ?? profile?.username ?? auth.currentUser?.email;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: <Widget>[
          UnreadBadge(
            count: unread.notifications,
            child: PubgetIconButton(
              icon: Icons.notifications_none,
              tooltip: 'Notifications',
              onPressed: () => AppNavigation.go(context, '/notifications'),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          GestureDetector(
            onTap: () => AppNavigation.go(context, '/profile'),
            child: PubgetAvatar(
              imageUrl: profile?.avatarUrl ?? auth.currentUser?.avatarUrl,
              name: name,
              size: PubgetAvatarSize.small,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: home.refresh,
        child: CustomScrollView(
          controller: _scroll,
          slivers: <Widget>[
            SliverToBoxAdapter(child: _SearchBar(controller: _search)),
            if (_search.text.trim().isNotEmpty)
              SliverToBoxAdapter(child: _SearchResults(home: home)),
            if (_search.text.trim().isEmpty)
              SliverList.builder(
                itemCount: home.sectionOrder.length,
                itemBuilder: (context, index) => _SectionView(
                  key: ValueKey(home.sectionOrder[index]),
                  kind: home.sectionOrder[index],
                  provider: home,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNavigation(
        selectedIndex: _tab,
        unread: unread,
        onSelected: (index) => _selectTab(context, index),
      ),
    );
  }

  void _selectTab(BuildContext context, int index) {
    setState(() => _tab = index);
    switch (index) {
      case 1:
        AppNavigation.go(context, '/groups');
      case 2:
        AppNavigation.go(context, '/private');
      case 3:
        AppNavigation.go(context, '/edits');
    }
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<HomeProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: PubgetSearchField(
        controller: controller,
        hint: AnimeStrings.searchHomeHint,
        onChanged: provider.searchChanged,
        onClear: () {
          controller.clear();
          provider.searchChanged('');
        },
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.home});
  final HomeProvider home;

  @override
  Widget build(BuildContext context) {
    if (home.searchState == LoadingState.loading) {
      return const _SkeletonSection();
    }
    if (home.searchState == LoadingState.empty) {
      return const PubgetEmptyState(
        title: 'Nothing found',
        message: 'Try another group, username, event, or anime.',
      );
    }
    if (home.searchState == LoadingState.error) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(home.searchFailure?.message ?? 'Search failed.'),
      );
    }
    return Column(
      children: <Widget>[
        for (final group in home.searchResults.groups)
          _GroupRow(
            groupName: group.name,
            subtitle: 'Group',
            onTap: () {
              AppNavigation.go(context, '/group?groupId=${group.id}');
            },
          ),
        for (final person in home.searchResults.people)
          _PersonRow(person: person),
        for (final event in home.searchResults.events) _EventRow(event: event),
        for (final anime in home.searchResults.anime)
          AnimeResultTile(anime: anime),
      ],
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.kind, required this.provider, super.key});

  final HomeSectionKind kind;
  final HomeProvider provider;

  @override
  Widget build(BuildContext context) {
    if (kind == HomeSectionKind.editsPlaceholder) {
      final edits = context.watch<EditsProvider>();
      if (edits.state == LoadingState.initial) {
        Future<void>.microtask(() => edits.load(limit: 4));
      }
      return _SectionShell(
        title: 'Trending Edits',
        child: SizedBox(
          height: 150,
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
                  itemBuilder: (context, index) => SizedBox(
                    width: 120,
                    child: PubgetCard(
                      onTap: () => AppNavigation.go(context, '/edits'),
                      child: AppImageLoader(
                        imageUrl: edits.items[index].thumbnailUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
        ),
      );
    }
    if (kind == HomeSectionKind.eventsPlaceholder) {
      return const EventHomeStrip();
    }
    if (kind == HomeSectionKind.animePlaceholder) {
      return const AnimeHomeStrip();
    }
    final state = provider.section(kind);
    if (state.state == LoadingState.initial) {
      Future<void>.microtask(() => provider.ensureLoaded(kind));
    }
    final title = switch (kind) {
      HomeSectionKind.promotedGroups => 'Promoted groups',
      HomeSectionKind.risingGroups => 'Small groups rising',
      HomeSectionKind.recommendedGroups => 'Recommended groups',
      HomeSectionKind.communityActivity => 'Recent community activity',
      HomeSectionKind.recommendedPeople => 'People to discover',
      _ => 'Discover',
    };
    if (state.state == LoadingState.loading && !state.hasContent) {
      return _SectionShell(title: title, child: const _SkeletonSection());
    }
    if (state.state == LoadingState.error && !state.hasContent) {
      return _SectionShell(
        title: title,
        child: Text(state.failure?.message ?? 'This section could not load.'),
      );
    }
    if (state.state == LoadingState.empty) {
      return _SectionShell(
        title: title,
        child: const Text('Nothing here yet. Check back soon.'),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: AppSpacing.sm),
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
  });
  final List<Group> groups;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 142,
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
                      child: const Text('Load more'),
                    ),
            ),
          );
        }
        final group = groups[index];
        return SizedBox(
          width: 240,
          child: PubgetCard(
            onTap: () =>
                AppNavigation.go(context, '/group?groupId=${group.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  group.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  group.description.isEmpty
                      ? 'A Pubget community'
                      : group.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Text(
                  '${group.membersCount} members · score ${group.activityScore.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
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
  Widget build(BuildContext context) => SizedBox(
    height: 142,
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
                      child: const Text('Load more'),
                    ),
            ),
          );
        }
        return SizedBox(
          width: 180,
          child: PubgetCard(
            onTap: () =>
                AppNavigation.go(context, '/profile?uid=${people[index].uid}'),
            child: _PersonRow(person: people[index], compact: true),
          ),
        );
      },
    ),
  );
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, this.compact = false});
  final PublicProfile person;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      PubgetAvatar(
        imageUrl: person.avatarUrl,
        name: person.username,
        size: compact ? PubgetAvatarSize.small : PubgetAvatarSize.medium,
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          person.username ?? 'Pubget user',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final PubgetEvent event;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(event.title),
    subtitle: Text(EventTypeRegistry.of(event.type).label),
    leading: const Icon(Icons.celebration_outlined),
    onTap: () => EventLinks.open(context, event.id),
  );
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.groupName,
    required this.subtitle,
    required this.onTap,
  });
  final String groupName;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(groupName),
    subtitle: Text(subtitle),
    leading: const Icon(Icons.groups_outlined),
    onTap: onTap,
  );
}

class _SkeletonSection extends StatelessWidget {
  const _SkeletonSection();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 142,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      scrollDirection: Axis.horizontal,
      itemCount: 2,
      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
      itemBuilder: (_, _) => SizedBox(
        width: 240,
        child: PubgetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(height: 18, width: 150, color: Colors.black12),
              const SizedBox(height: AppSpacing.sm),
              Container(height: 14, width: 200, color: Colors.black12),
              const SizedBox(height: AppSpacing.xs),
              Container(height: 14, width: 170, color: Colors.black12),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.selectedIndex,
    required this.unread,
    required this.onSelected,
  });
  final int selectedIndex;
  final UnreadEngine unread;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    destinations: <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.explore_outlined),
        selectedIcon: Icon(Icons.explore),
        label: 'Discover',
      ),
      NavigationDestination(
        icon: UnreadBadge(
          count: unread.groups,
          child: const Icon(Icons.space_dashboard_outlined),
        ),
        selectedIcon: const Icon(Icons.space_dashboard),
        label: 'My Space',
      ),
      NavigationDestination(
        icon: UnreadBadge(
          count: unread.privateChats,
          child: const Icon(Icons.forum_outlined),
        ),
        selectedIcon: const Icon(Icons.forum),
        label: 'Private',
      ),
      const NavigationDestination(
        icon: Icon(Icons.auto_awesome_outlined),
        selectedIcon: Icon(Icons.auto_awesome),
        label: 'Edits',
      ),
    ],
  );
}
