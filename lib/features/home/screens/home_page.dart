import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../app/app_shell_scope.dart';
import '../../../core/branding/pubget_logo.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../authentication/providers/onboarding_provider.dart';
import '../../edits/models/edit_models.dart';
import '../../edits/providers/edits_provider.dart';
import '../../economy/models/economy_types.dart';
import '../../economy/providers/economy_provider.dart';
import '../../economy/widgets/economy_widgets.dart';
import '../../events/models/event_models.dart';
import '../../events/providers/event_providers.dart';
import '../../events/widgets/home_event_card.dart';
import '../../fan_works/providers/fan_work_providers.dart';
import '../../fan_works/widgets/home_fan_work_card.dart';
import '../../notifications/providers/unread_engine.dart';
import '../models/home_models.dart';
import '../providers/home_provider.dart';
import '../widgets/home_luxury_tiles.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
  Widget build(BuildContext context) {
    final profile = context.watch<OnboardingProvider>().profile;
    final auth = context.watch<AuthProvider>();
    final home = context.watch<HomeProvider>();
    final unread = context.watch<UnreadEngine>();
    final economy = maybeEconomy(context);
    final copy = AppStrings.of(context);
    final name =
        profile?.displayName ?? profile?.username ?? auth.currentUser?.email;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: HomeTopBar(
        name: name,
        avatarUrl: profile?.avatarUrl ?? auth.currentUser?.avatarUrl,
        frameId: economy?.equipped.frameId,
        coins: economy?.coins,
        notifyCount: unread.notifications,
      ),
      body: PubgetAtmosphere(
        child: RefreshIndicator(
          onRefresh: home.refresh,
          child: CustomScrollView(
            slivers: <Widget>[
              _groupSliver(
                key: const Key('home-promoted'),
                title: copy.sectionPromoted,
                kind: HomeSectionKind.promotedGroups,
                finish: HomeGroupFinish.gold,
              ),
              const SliverToBoxAdapter(child: _EditsSection()),
              _peopleSliver(),
              if (economy != null)
                const SliverToBoxAdapter(child: _HomeAdSlot()),
              const SliverToBoxAdapter(child: _EventsSection()),
              _groupSliver(
                key: const Key('home-suggested'),
                title: copy.sectionRecommended,
                kind: HomeSectionKind.recommendedGroups,
                finish: HomeGroupFinish.silver,
              ),
              _groupSliver(
                key: const Key('home-rising'),
                title: copy.sectionRising,
                kind: HomeSectionKind.risingGroups,
                finish: HomeGroupFinish.rising,
              ),
              const SliverToBoxAdapter(child: _FanWorksSection()),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupSliver({
    required Key key,
    required String title,
    required HomeSectionKind kind,
    required HomeGroupFinish finish,
  }) {
    return SliverToBoxAdapter(
      child: _GroupSection(key: key, title: title, kind: kind, finish: finish),
    );
  }

  Widget _peopleSliver() {
    return const SliverToBoxAdapter(child: _PeopleSection());
  }
}

class HomeTopBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeTopBar({
    required this.name,
    required this.avatarUrl,
    required this.frameId,
    required this.coins,
    required this.notifyCount,
    super.key,
  });

  final String? name;
  final String? avatarUrl;
  final String? frameId;
  final int? coins;
  final int notifyCount;

  static const barHeight = 56.0;
  static const iconSize = 36.0;
  static const logoSize = 54.0;
  static const coinStripHeight = 36.0;
  static const itemGap = 8.0;
  static const edgePad = 8.0;

  bool get _showCoins => coins != null;

  @override
  Size get preferredSize => Size.fromHeight(
    barHeight + (_showCoins ? coinStripHeight : 0),
  );

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: barHeight,
      titleSpacing: 0,
      clipBehavior: Clip.none,
      title: SizedBox(
        height: barHeight,
        width: double.infinity,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: edgePad),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _BarIconBox(
                          child: GestureDetector(
                            key: const Key('home-avatar'),
                            onTap: () => AppNavigation.go(context, '/profile'),
                            child: FittedBox(
                              child: EquippedAvatar(
                                imageUrl: avatarUrl,
                                name: name,
                                frameId: frameId,
                                size: PubgetAvatarSize.nav,
                                compactFrame: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: itemGap),
                        _BarIconBox(
                          child: PubgetLuxuryNotifyButton(
                            tooltip: copy.notifications,
                            badge: notifyCount,
                            size: iconSize,
                            onPressed: () =>
                                AppNavigation.go(context, '/notifications'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const PubgetLogoMark(key: Key('home-logo'), size: logoSize),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _BarIconBox(
                          child: PubgetLuxurySettingsButton(
                            tooltip: copy.settings,
                            size: iconSize,
                            onPressed: () =>
                                AppNavigation.go(context, '/settings'),
                          ),
                        ),
                        const SizedBox(width: itemGap),
                        const _BarIconBox(
                          child: AppShellMenuButton(size: iconSize),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottom: _showCoins
          ? PreferredSize(
              preferredSize: const Size.fromHeight(coinStripHeight),
              child: _HomeCoinStrip(
                balance: coins!,
                tooltip: copy.store,
              ),
            )
          : null,
    );
  }
}

class _BarIconBox extends StatelessWidget {
  const _BarIconBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(dimension: HomeTopBar.iconSize, child: child);
  }
}

class _HomeCoinStrip extends StatelessWidget {
  const _HomeCoinStrip({required this.balance, required this.tooltip});

  final int balance;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.royalNight.withValues(alpha: 0.38),
      child: SizedBox(
        height: HomeTopBar.coinStripHeight,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: PubgetKatanaCoinChip(
              balance: balance,
              tooltip: tooltip,
              compact: true,
              onPressed: () => AppNavigation.go(context, '/store'),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.title,
    required this.kind,
    required this.finish,
    super.key,
  });

  final String title;
  final HomeSectionKind kind;
  final HomeGroupFinish finish;

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final state = home.section(kind);
    if (state.state == LoadingState.initial) {
      Future<void>.microtask(() => home.ensureLoaded(kind));
    }
    return _SectionFrame(
      title: title,
      child: _stateChild(
        context,
        state: state,
        kind: kind,
        loaded: HomeHorizontalStrip(
          height: 214,
          itemCount: state.groups.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.groups.length) {
              return _MoreCell(
                loading: state.state == LoadingState.loadingMore,
                onPressed: () => home.loadMore(kind),
              );
            }
            return HomeSquareGroupCard(
              group: state.groups[index],
              finish: finish,
            );
          },
        ),
      ),
    );
  }
}

class _PeopleSection extends StatelessWidget {
  const _PeopleSection();

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    const kind = HomeSectionKind.recommendedPeople;
    final state = home.section(kind);
    if (state.state == LoadingState.initial) {
      Future<void>.microtask(() => home.ensureLoaded(kind));
    }
    final copy = AppStrings.of(context);
    return _SectionFrame(
      key: const Key('home-people'),
      title: copy.sectionPeople,
      child: _stateChild(
        context,
        state: state,
        kind: kind,
        loaded: HomeHorizontalStrip(
          height: 188,
          itemCount: state.people.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.people.length) {
              return _MoreCell(
                loading: state.state == LoadingState.loadingMore,
                onPressed: () => home.loadMore(kind),
              );
            }
            return HomePersonCard(person: state.people[index]);
          },
        ),
      ),
    );
  }
}

class _EditsSection extends StatelessWidget {
  const _EditsSection();

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final edits = context.watch<EditsProvider>();
    if (edits.state == LoadingState.initial) {
      Future<void>.microtask(() => edits.load(limit: 8));
    }
    final copy = AppStrings.of(context);
    final items = _editsForHome(home, edits);
    Widget child;
    if (items.isNotEmpty) {
      child = HomeHorizontalStrip(
        height: 228,
        itemCount: items.length,
        itemBuilder: (context, index) =>
            HomeEditPreviewCard(edit: items[index]),
      );
    } else if (edits.state == LoadingState.loading ||
        edits.state == LoadingState.initial ||
        edits.state == LoadingState.refreshing) {
      child = const _SkeletonSection();
    } else if (edits.state == LoadingState.error) {
      child = PubgetErrorState(
        title: copy.sectionFailed,
        message: edits.failure?.message ?? copy.tryAgainShort,
        onRetry: () => edits.load(refresh: true, limit: 8),
      );
    } else {
      child = PubgetEmptyState(
        compact: true,
        title: copy.nothingHereYet,
      );
    }
    return _SectionFrame(
      key: const Key('home-edits'),
      title: copy.sectionEdits,
      child: child,
    );
  }

  List<Edit> _editsForHome(HomeProvider home, EditsProvider edits) {
    if (edits.items.isNotEmpty) return edits.items.take(8).toList();
    return home.feed.section('recommendedEdits').items.map((item) {
      final meta = item.metadata;
      return Edit(
        id: item.targetId.isEmpty ? item.id : item.targetId,
        creatorId: meta['creatorId'] as String? ?? '',
        videoUrl: meta['videoUrl'] as String? ?? '',
        thumbnailUrl: meta['thumbnailUrl'] as String? ?? '',
        caption: meta['title'] as String? ?? meta['caption'] as String? ?? '',
        animeTag: meta['animeTag'] as String? ?? '',
        likesCount: (meta['likesCount'] as num?)?.toInt() ?? 0,
        commentsCount: 0,
        viewsCount: 0,
        score: item.score,
        createdAt: item.createdAt,
        status: 'published',
      );
    }).toList(growable: false);
  }
}

class _EventsSection extends StatelessWidget {
  const _EventsSection();

  @override
  Widget build(BuildContext context) {
    final list = context.watch<EventListProvider>();
    if (list.state == LoadingState.initial) {
      Future<void>.microtask(list.loadHome);
    }
    final copy = AppStrings.of(context);
    if (list.state == LoadingState.loading &&
        list.active.isEmpty &&
        list.upcoming.isEmpty) {
      return _SectionFrame(
        title: copy.sectionEvents,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: PubgetSkeleton.card(height: 160),
        ),
      );
    }
    final now = DateTime.now();
    final recent = list.recent.where((event) {
      final end = event.endAt;
      return end != null && now.difference(end) <= const Duration(hours: 24);
    });
    final picked = HomeEventsSection.pickHome(
      <PubgetEvent>[...list.active, ...list.upcoming, ...recent],
      now,
    );
    if (picked.isEmpty) {
      return _SectionFrame(
        title: copy.sectionEvents,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: PubgetEmptyState(
            compact: true,
            title: copy.nothingHereYet,
            action: PubgetTextButton(
              onPressed: () => AppNavigation.go(context, '/events'),
              semanticLabel: copy.seeMore,
              child: Text(copy.seeMore),
            ),
          ),
        ),
      );
    }
    return HomeEventsSection(events: picked);
  }
}

class _FanWorksSection extends StatelessWidget {
  const _FanWorksSection();

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FanWorkFeedProvider>();
    if (feed.state == LoadingState.initial) {
      Future<void>.microtask(feed.load);
    }
    final copy = AppStrings.of(context);
    final works = diversifyFanWorks(feed.items);
    return _SectionFrame(
      key: const Key('home-fan-works'),
      title: copy.sectionFanWorks,
      child: feed.state == LoadingState.loading && feed.items.isEmpty
          ? const _SkeletonSection()
          : works.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PubgetEmptyState(
                compact: true,
                title: copy.nothingHereYet,
              ),
            )
          : HomeHorizontalStrip(
              height: 286,
              itemCount: works.length + 1,
              itemBuilder: (context, index) {
                if (index == works.length) {
                  return const HomeFanWorksSeeAllCard();
                }
                return HomeFanWorkCard(work: works[index]);
              },
            ),
    );
  }
}

class _SectionFrame extends StatelessWidget {
  const _SectionFrame({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
}

Widget _stateChild(
  BuildContext context, {
  required HomeSectionState state,
  required HomeSectionKind kind,
  required Widget loaded,
}) {
  final copy = AppStrings.of(context);
  final home = context.read<HomeProvider>();
  if (state.state == LoadingState.loading && !state.hasContent) {
    return const _SkeletonSection();
  }
  if (state.state == LoadingState.error && !state.hasContent) {
    return PubgetErrorState(
      title: copy.sectionFailed,
      message: state.failure?.message ?? copy.tryAgainShort,
      onRetry: () => home.retrySection(kind),
    );
  }
  if (state.state == LoadingState.empty) {
    return PubgetEmptyState(
      compact: true,
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
    );
  }
  return loaded;
}

class _MoreCell extends StatelessWidget {
  const _MoreCell({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Center(
        child: loading
            ? const CircularProgressIndicator()
            : TextButton(
                onPressed: onPressed,
                child: Text(AppStrings.of(context).loadMore),
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
      itemBuilder: (_, _) => const SizedBox(
        width: 168,
        child: PubgetSkeleton.card(height: 200),
      ),
    ),
  );
}
