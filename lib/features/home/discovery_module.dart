import 'models/home_models.dart';

/// How a discovery module renders. The registry is deliberately data-only:
/// the Home screen owns a single `switch` that maps each [DiscoveryModuleType]
/// to its widget, so sections can be added, removed, reordered, pinned, or
/// disabled by editing [DiscoveryModuleRegistry.all] instead of hand-editing
/// the Home sliver list.
enum DiscoveryModuleType {
  groupStrip,
  peopleStrip,
  edits,
  adSlot,
  events,
  rankedRow,
  achievements,
  fanWorks,
  animeCatalog,
}

/// One entry in the Home discovery feed.
///
/// A module is either **pinned** (its position is fixed by Master Spec §5.2) or
/// **rotating** (shuffled once per visit through `rotate()`). Disabled modules
/// stay in the registry so the reason is recorded in one place; the constructor
/// asserts that a disabled module documents why, so silent disablement is
/// impossible.
final class DiscoveryModule {
  const DiscoveryModule({
    required this.id,
    required this.type,
    required this.pinned,
    this.kind,
    this.seeMorePath,
    this.enabled = true,
    this.disabledReason,
  }) : assert(
         enabled || disabledReason != null,
         'A disabled discovery module must document its disabledReason.',
       );

  /// Stable identifier. Used by tests and by `Key('home-$id')` where relevant.
  final String id;
  final DiscoveryModuleType type;

  /// Pinned modules never rotate; §5.2 fixes their order.
  final bool pinned;

  /// Provider-backed section kind, for modules backed by `HomeProvider`.
  final HomeSectionKind? kind;

  /// Destination of a "See all" that opens a standalone page, or null when the
  /// section has no real listing page (in which case no action is shown).
  final String? seeMorePath;

  final bool enabled;

  /// Required when [enabled] is false. Explains why the module is not shown.
  final String? disabledReason;
}

/// The single source of truth for what the Home feed renders and in what order.
///
/// §5.2 pins promoted groups first, personalized edits second, and a people
/// strip third; everything after that rotates once per visit. Only modules
/// backed by real providers/repositories are registered here — a section is
/// disabled (with a reason) rather than faked when its source is unavailable.
abstract final class DiscoveryModuleRegistry {
  static const List<DiscoveryModule> all = <DiscoveryModule>[
    // --- Pinned (§5.2.1–§5.2.3) -------------------------------------------
    DiscoveryModule(
      id: 'promoted',
      type: DiscoveryModuleType.groupStrip,
      kind: HomeSectionKind.promotedGroups,
      pinned: true,
      seeMorePath: '/groups',
    ),
    DiscoveryModule(
      id: 'edits',
      type: DiscoveryModuleType.edits,
      pinned: true,
      seeMorePath: '/reels',
    ),
    DiscoveryModule(
      id: 'people',
      type: DiscoveryModuleType.peopleStrip,
      kind: HomeSectionKind.recommendedPeople,
      pinned: true,
      seeMorePath: '/search',
    ),

    // --- Rotating ----------------------------------------------------------
    DiscoveryModule(id: 'ad', type: DiscoveryModuleType.adSlot, pinned: false),
    DiscoveryModule(
      id: 'events',
      type: DiscoveryModuleType.events,
      pinned: false,
      seeMorePath: '/events',
    ),
    DiscoveryModule(
      id: 'suggested',
      type: DiscoveryModuleType.groupStrip,
      kind: HomeSectionKind.recommendedGroups,
      pinned: false,
      seeMorePath: '/groups',
    ),
    DiscoveryModule(
      id: 'rising',
      type: DiscoveryModuleType.groupStrip,
      kind: HomeSectionKind.risingGroups,
      pinned: false,
      seeMorePath: '/groups',
    ),
    DiscoveryModule(
      id: 'anime-of-week',
      type: DiscoveryModuleType.rankedRow,
      kind: HomeSectionKind.animeOfTheWeek,
      pinned: false,
      seeMorePath: '/anime',
    ),
    DiscoveryModule(
      id: 'popular-characters',
      type: DiscoveryModuleType.rankedRow,
      kind: HomeSectionKind.popularCharacters,
      pinned: false,
      seeMorePath: '/anime/characters',
    ),
    DiscoveryModule(
      id: 'rising-creators',
      type: DiscoveryModuleType.rankedRow,
      kind: HomeSectionKind.risingCreators,
      pinned: false,
    ),
    DiscoveryModule(
      id: 'friends-activity',
      type: DiscoveryModuleType.rankedRow,
      kind: HomeSectionKind.friendsActivity,
      pinned: false,
    ),
    DiscoveryModule(
      id: 'freshest',
      type: DiscoveryModuleType.rankedRow,
      kind: HomeSectionKind.freshestContent,
      pinned: false,
    ),
    DiscoveryModule(
      id: 'achievements',
      type: DiscoveryModuleType.achievements,
      pinned: false,
    ),
    DiscoveryModule(
      id: 'fan-works',
      type: DiscoveryModuleType.fanWorks,
      pinned: false,
    ),
    DiscoveryModule(
      id: 'anime',
      type: DiscoveryModuleType.animeCatalog,
      pinned: false,
    ),
  ];

  static List<DiscoveryModule> get pinned => pinnedOf(all);

  /// Modules eligible for per-visit rotation, in registry order.
  static List<DiscoveryModule> get rotating => rotatingOf(all);

  /// Enabled modules from [modules], preserving order. Disabled modules are
  /// dropped here rather than silently skipped at the call site.
  static List<DiscoveryModule> enabledOf(Iterable<DiscoveryModule> modules) =>
      modules.where((module) => module.enabled).toList(growable: false);

  static List<DiscoveryModule> pinnedOf(Iterable<DiscoveryModule> modules) =>
      enabledOf(
        modules,
      ).where((module) => module.pinned).toList(growable: false);

  static List<DiscoveryModule> rotatingOf(Iterable<DiscoveryModule> modules) =>
      enabledOf(
        modules,
      ).where((module) => !module.pinned).toList(growable: false);
}
