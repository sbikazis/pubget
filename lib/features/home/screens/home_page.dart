import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../app/app_shell_scope.dart';
import '../../../core/branding/pubget_logo.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../achievements/widgets/home_achievements_strip.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../authentication/providers/onboarding_provider.dart';
import '../../anime/l10n/anime_copy.dart';
import '../../anime/models/anime_models.dart';
import '../../anime/providers/anime_providers.dart';
import '../../anime/widgets/anime_widgets.dart';
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
import '../discovery_module.dart';
import '../models/home_models.dart';
import '../providers/home_provider.dart';
import '../section_rotation.dart';
import '../repositories/discovery_errors.dart';
import '../widgets/home_luxury_tiles.dart';
import '../widgets/home_ranked_section.dart';

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
            // §5.2 fixes promoted groups first, personalized edits second, and
            // a people strip third; everything after that rotates between
            // visits so the same discovery surfaces do not own the same screen
            // twice. The order and membership live in
            // [DiscoveryModuleRegistry], not in this widget.
            slivers: <Widget>[
              for (final module in DiscoveryModuleRegistry.pinned)
                _moduleSliver(context, copy, module),
              ...<Widget>[
                for (final module in DiscoveryModuleRegistry.rotating)
                  _moduleSliver(context, copy, module),
              ].rotate(home.rotationSeed),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],
          ),
        ),
      ),
    );
  }

  /// A single registry entry as a sliver. Every module renders through
  /// [_moduleWidget], which is the one place that maps a
  /// [DiscoveryModuleType] to a concrete section widget.
  Widget _moduleSliver(
    BuildContext context,
    AppStrings copy,
    DiscoveryModule module,
  ) {
    return SliverToBoxAdapter(child: _moduleWidget(context, copy, module));
  }

  Widget _moduleWidget(
    BuildContext context,
    AppStrings copy,
    DiscoveryModule module,
  ) {
    switch (module.type) {
      case DiscoveryModuleType.groupStrip:
        final groupKind = module.kind!;
        return _GroupSection(
          key: Key('home-${module.id}'),
          title: _groupTitle(copy, groupKind),
          kind: groupKind,
          finish: _groupFinish(groupKind),
        );
      case DiscoveryModuleType.peopleStrip:
        return const _PeopleSection();
      case DiscoveryModuleType.edits:
        return const _EditsSection();
      case DiscoveryModuleType.adSlot:
        return const _HomeAdSlot();
      case DiscoveryModuleType.events:
        return const _EventsSection();
      case DiscoveryModuleType.rankedRow:
        final rankedKind = module.kind!;
        return HomeRankedSection(
          key: Key('home-${module.id}'),
          kind: rankedKind,
          title: _rankedTitle(copy, rankedKind),
          seeMorePath: module.seeMorePath,
        );
      case DiscoveryModuleType.achievements:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: _SectionFrame(
            title: copy.sectionAchievements,
            child: HomeAchievementsStrip(
              onSeeAll: () => AppNavigation.go(
                context,
                '/profile/${context.read<AuthProvider>().currentUser?.id ?? ''}',
              ),
            ),
          ),
        );
      case DiscoveryModuleType.fanWorks:
        return const _FanWorksSection();
      case DiscoveryModuleType.animeCatalog:
        return const _AnimeSection();
    }
  }

  String _groupTitle(AppStrings copy, HomeSectionKind kind) => switch (kind) {
    HomeSectionKind.promotedGroups => copy.sectionPromoted,
    HomeSectionKind.risingGroups => copy.sectionRising,
    _ => copy.sectionRecommended,
  };

  HomeGroupFinish _groupFinish(HomeSectionKind kind) => switch (kind) {
    HomeSectionKind.promotedGroups => HomeGroupFinish.gold,
    HomeSectionKind.risingGroups => HomeGroupFinish.rising,
    _ => HomeGroupFinish.silver,
  };

  String _rankedTitle(AppStrings copy, HomeSectionKind kind) => switch (kind) {
    HomeSectionKind.animeOfTheWeek => copy.sectionAnimeOfTheWeek,
    HomeSectionKind.popularCharacters => copy.sectionPopularCharacters,
    HomeSectionKind.risingCreators => copy.sectionRisingCreators,
    HomeSectionKind.friendsActivity => copy.sectionFriendsActivity,
    _ => copy.sectionFreshestContent,
  };
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

  /// Live wallet balance. `null` means the balance is not known yet, so the
  /// chip is hidden rather than shown as a fake zero (§0.4).
  final int? coins;

  final int notifyCount;

  static const barHeight = 56.0;
  static const iconSize = 36.0;
  static const logoSize = 54.0;
  static const itemGap = 8.0;
  static const edgePad = 8.0;

  /// Narrow-phone metrics. The logo stays 1.5x the icons.
  static const iconSizeCompact = 32.0;
  static const logoSizeCompact = 48.0;
  static const itemGapCompact = 4.0;
  static const edgePadCompact = 6.0;

  /// Below this width the controls stop fitting at full size.
  static const _compactBreakpoint = 380.0;

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: barHeight,
      titleSpacing: 0,
      clipBehavior: Clip.none,
      // Master Spec §4.1 fixes this order:
      //   logo ← coins (+) ← dragon store ← search ← notifications ← profile ← ☰
      // The row is directional, so declaring the children in that order
      // produces that reading order in Arabic and mirrors it in English.
      // There is no forced `TextDirection.ltr` anywhere — that is what used to
      // place the avatar on the wrong side of the bar in the Arabic UI.
      title: LayoutBuilder(
        builder: (context, constraints) {
          // Seven controls at full size do not fit a narrow phone, so the bar
          // scales its metrics down together rather than clipping or dropping
          // a control. The 1.5x logo ratio from §4.1 is preserved at every
          // size, and the bar height never changes.
          final compact = constraints.maxWidth < _compactBreakpoint;
          final icon = compact ? iconSizeCompact : iconSize;
          final logo = compact ? logoSizeCompact : logoSize;
          final gap = compact ? itemGapCompact : itemGap;
          final pad = compact ? edgePadCompact : edgePad;
          return SizedBox(
            height: barHeight,
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: Row(
                children: <Widget>[
                  PubgetLogoMark(key: const Key('home-logo'), size: logo),
                  SizedBox(width: gap),
                  // The coin chip is the only variable-width control. It is
                  // allowed to shrink (never to push the row over) so a very
                  // large balance can never overflow the bar.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: _CoinChipSlot(
                        balance: coins,
                        tooltip: copy.store,
                        compact: compact,
                      ),
                    ),
                  ),
                  SizedBox(width: gap),
                  SizedBox.square(
                    dimension: icon,
                    child: PubgetLuxuryStoreButton(
                      tooltip: copy.store,
                      size: icon,
                      onPressed: () => AppNavigation.go(context, '/store'),
                    ),
                  ),
                  SizedBox(width: gap),
                  SizedBox.square(
                    dimension: icon,
                    child: PubgetLuxurySearchButton(
                      tooltip: copy.search,
                      size: icon,
                      onPressed: () => AppNavigation.go(context, '/search'),
                    ),
                  ),
                  SizedBox(width: gap),
                  SizedBox.square(
                    dimension: icon,
                    child: PubgetLuxuryNotifyButton(
                      tooltip: copy.notifications,
                      badge: notifyCount,
                      size: icon,
                      onPressed: () =>
                          AppNavigation.go(context, '/notifications'),
                    ),
                  ),
                  SizedBox(width: gap),
                  SizedBox.square(
                    dimension: icon,
                    child: Semantics(
                      button: true,
                      label: name ?? copy.profile,
                      child: InkWell(
                        key: const Key('home-avatar'),
                        onTap: () => AppNavigation.go(context, '/profile'),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: FittedBox(
                          child: EquippedAvatar(
                            imageUrl: avatarUrl,
                            name: name,
                            frameId: frameId,
                            size: compact
                                ? PubgetAvatarSize.small
                                : PubgetAvatarSize.nav,
                            compactFrame: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: gap),
                  SizedBox.square(
                    dimension: icon,
                    child: AppShellMenuButton(size: icon),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Inline coins, as required by §4.1 ("عداد العملات (+)"). The previous layout
/// parked coins in a second strip under the bar; the spec puts them in the bar
/// itself. When the balance is unknown the slot collapses to nothing so the UI
/// never advertises a fake zero.
class _CoinChipSlot extends StatelessWidget {
  const _CoinChipSlot({
    required this.balance,
    required this.tooltip,
    this.compact = false,
  });

  final int? balance;
  final String tooltip;

  /// True on narrow phones, where the chip gives up its horizontal padding
  /// before any control is dropped.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (balance == null) return const SizedBox.shrink();
    // The chip owns its own tap target and semantics, so it is used directly
    // rather than being nested in another InkWell.
    return PubgetKatanaCoinChip(
      balance: balance!,
      tooltip: tooltip,
      compact: compact,
      onPressed: () => AppNavigation.go(context, '/store'),
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
      // Every group section lands on the real groups discovery surface; there
      // is no separate promoted/recommended listing page to deep-link to.
      onSeeAll: () => AppNavigation.go(context, '/groups'),
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
      onSeeAll: () => AppNavigation.go(context, '/search'),
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
    final edits = context.watch<EditsProvider>();
    if (edits.state == LoadingState.initial) {
      Future<void>.microtask(() => edits.load(limit: 8));
    }
    final copy = AppStrings.of(context);
    // §5.2.2 puts personalized edits second on Home. `EditsProvider` defaults
    // to FeedType.forYou, which is the server-ranked per-user feed, so these are
    // real edits chosen for this viewer.
    final items = edits.items.take(8).toList(growable: false);
    Widget child;
    if (items.isNotEmpty) {
      child = HomePreviewStrip(height: 228, items: items);
    } else if (edits.state == LoadingState.loading ||
        edits.state == LoadingState.initial ||
        edits.state == LoadingState.refreshing) {
      child = const _SkeletonSection();
    } else if (edits.state == LoadingState.error) {
      child = PubgetErrorState(
        title: copy.sectionFailed,
        message: edits.failure == null
            ? copy.discoveryUnavailable
            : discoveryFailureMessage(copy, edits.failure!),
        onRetry: () => edits.load(refresh: true, limit: 8),
      );
    } else {
      child = PubgetEmptyState(compact: true, title: copy.nothingHereYet);
    }
    return _SectionFrame(
      key: const Key('home-edits'),
      title: copy.sectionEdits,
      onSeeAll: () => AppNavigation.go(context, '/reels'),
      child: child,
    );
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
    final picked = HomeEventsSection.pickHome(<PubgetEvent>[
      ...list.active,
      ...list.upcoming,
      ...recent,
    ], now);
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

class _AnimeSection extends StatelessWidget {
  const _AnimeSection();

  @override
  Widget build(BuildContext context) {
    final hub = maybeAnimeHub(context);
    if (hub == null) return const SizedBox.shrink();
    final kind = AnimeCatalogKind.thisSeason;
    final snapshot = hub.section(kind);
    if (snapshot.state == LoadingState.initial) {
      Future<void>.microtask(hub.load);
    }
    if (snapshot.items.isEmpty) {
      return const SizedBox.shrink();
    }
    return AnimeHorizontalStrip(
      key: const Key('home-anime'),
      title: AnimeCopy.of(context).catalog(kind),
      subtitle: AnimeCopy.of(context).thisSeasonSubtitle,
      items: snapshot.items,
      state: snapshot.state,
      failure: snapshot.failure == null
          ? null
          : discoveryFailureMessage(AppStrings.of(context), snapshot.failure!),
      posterWidth: 168,
      highlightFirst: true,
      onSeeAll: () => AnimeLinks.openCatalog(context, kind),
      onRetry: () => hub.load(),
    );
  }
}

class _SectionFrame extends StatelessWidget {
  const _SectionFrame({
    required this.title,
    required this.child,
    this.onSeeAll,
    super.key,
  });

  final String title;
  final Widget child;

  /// Master Spec §5.3 requires a "See all" in every section that has a
  /// standalone section page. Null deliberately omits the action: a section
  /// without a real listing page must not link somewhere unrelated.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PubgetSectionHeader(
            title: title,
            actionLabel: onSeeAll == null ? null : copy.seeAll,
            onAction: onSeeAll,
          ),
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
  // §2.1 lists Offline as its own mandatory state, separate from Error and
  // from Empty. Offline with cached rows keeps the strip and adds a retry
  // banner, so a failed refresh never silently claims everything is fine.
  if (state.state == LoadingState.offline && state.hasContent) {
    return _staleColumn(home, kind, loaded);
  }
  // Offline or failed with nothing cached has to say the section could not be
  // fetched. Falling through to `loaded` rendered a blank rail that read as a
  // broken screen; falling through to the empty state told the user there is
  // nothing when the truth is that nothing could be fetched.
  if ((state.state == LoadingState.error ||
          state.state == LoadingState.offline) &&
      !state.hasContent) {
    return PubgetErrorState(
      title: copy.sectionFailed,
      message: state.state == LoadingState.offline
          ? copy.discoveryOffline
          : state.failure == null
          ? copy.discoveryUnavailable
          : discoveryFailureMessage(copy, state.failure!),
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

/// §2.1 — a refresh that failed keeps the rows the user can already act on, so
/// the section is marked stale instead of being replaced by an error.
Widget _staleColumn(HomeProvider home, HomeSectionKind kind, Widget loaded) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: PubgetStaleBanner(onRetry: () => home.retrySection(kind)),
      ),
      loaded,
    ],
  );
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
      itemBuilder: (_, _) =>
          const SizedBox(width: 168, child: PubgetSkeleton.card(height: 200)),
    ),
  );
}
