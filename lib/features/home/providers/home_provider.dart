import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../../groups/models/group_models.dart';
import '../../social/models/public_profile.dart';
import '../models/home_models.dart';
import '../repositories/home_repository.dart';

final class HomeSectionState {
  const HomeSectionState({
    required this.kind,
    required this.state,
    this.groups = const <Group>[],
    this.people = const <PublicProfile>[],
    this.items = const <DiscoveryItem>[],
    this.failure,
    this.hasMore = true,
  });

  final HomeSectionKind kind;
  final LoadingState state;
  final List<Group> groups;
  final List<PublicProfile> people;

  /// Ranked rows for the sections served by `getHomeSections`.
  final List<DiscoveryItem> items;
  final Failure? failure;
  final bool hasMore;

  bool get hasContent =>
      groups.isNotEmpty || people.isNotEmpty || items.isNotEmpty;

  HomeSectionState copyWith({
    LoadingState? state,
    List<Group>? groups,
    List<PublicProfile>? people,
    List<DiscoveryItem>? items,
    Failure? failure,
    bool clearFailure = false,
    bool? hasMore,
  }) => HomeSectionState(
    kind: kind,
    state: state ?? this.state,
    groups: groups ?? this.groups,
    people: people ?? this.people,
    items: items ?? this.items,
    failure: clearFailure ? null : failure ?? this.failure,
    hasMore: hasMore ?? this.hasMore,
  );
}

final class HomeProvider extends ChangeNotifier {
  HomeProvider({required HomeRepository repository, Analytics? analytics})
    : _repository = repository,
      _analytics = analytics {
    _sections = {
      for (final kind in _sectionOrder)
        kind: HomeSectionState(kind: kind, state: LoadingState.initial),
    };
  }

  static const _sectionOrder = <HomeSectionKind>[
    HomeSectionKind.promotedGroups,
    HomeSectionKind.risingGroups,
    HomeSectionKind.recommendedGroups,
    HomeSectionKind.communityActivity,
    HomeSectionKind.recommendedPeople,
    HomeSectionKind.animeOfTheWeek,
    HomeSectionKind.popularCharacters,
    HomeSectionKind.risingCreators,
    HomeSectionKind.friendsActivity,
    HomeSectionKind.freshestContent,
    HomeSectionKind.editsPlaceholder,
    HomeSectionKind.eventsPlaceholder,
    HomeSectionKind.gamesPlaceholder,
    HomeSectionKind.fanWorksPlaceholder,
    HomeSectionKind.animePlaceholder,
  ];

  /// Maps each ranked Home section onto the callable key that serves it.
  static const _callableSections = <HomeSectionKind, String>{
    HomeSectionKind.animeOfTheWeek: HomeSectionKeys.animeOfTheWeek,
    HomeSectionKind.popularCharacters: HomeSectionKeys.popularCharacters,
    HomeSectionKind.risingCreators: HomeSectionKeys.risingCreators,
    HomeSectionKind.friendsActivity: HomeSectionKeys.friendsActivity,
    HomeSectionKind.freshestContent: HomeSectionKeys.freshestContent,
  };

  final HomeRepository _repository;
  final Analytics? _analytics;
  late Map<HomeSectionKind, HomeSectionState> _sections;
  DiscoveryFeed _feed = const DiscoveryFeed();
  String? _userId;

  /// §5.2.3 rotation seed, redrawn on every [load].
  int _rotationSeed = 0;

  /// The seed Home shuffles its non-fixed sections with.
  int get rotationSeed => _rotationSeed;
  bool _disposed = false;
  static const _pageSize = 8;

  List<HomeSectionKind> get sectionOrder => _sectionOrder;
  List<HomeSectionKind> get displayOrder {
    final active = <HomeSectionKind>[];
    final empty = <HomeSectionKind>[];
    for (final kind in _sectionOrder) {
      if (_isPlaceholder(kind) ||
          section(kind).hasContent ||
          section(kind).state == LoadingState.initial ||
          section(kind).state == LoadingState.loading ||
          section(kind).state == LoadingState.refreshing ||
          section(kind).state == LoadingState.loadingMore) {
        active.add(kind);
      } else {
        empty.add(kind);
      }
    }
    return <HomeSectionKind>[...active, ...empty];
  }

  HomeSectionState section(HomeSectionKind kind) => _sections[kind]!;
  String? get userId => _userId;
  DiscoveryFeed get feed => _feed;
  bool get coldStart => _feed.coldStart;

  void bindUser(String? userId) {
    if (userId == _userId) return;
    resetSession();
    if (userId != null) load(userId);
  }

  void resetSession() {
    _userId = null;
    _feed = const DiscoveryFeed();
    _sections = {
      for (final kind in _sectionOrder)
        kind: HomeSectionState(kind: kind, state: LoadingState.initial),
    };
    _safeNotify();
  }

  void load(String userId) {
    _userId = userId;
    // §5.2.3 rotates the sections after the two fixed ones once per visit, so a
    // new seed is drawn on every Home load.
    _rotationSeed = DateTime.now().microsecondsSinceEpoch;
    _analytics?.logEvent('home_impression');
    unawaited(_prefetchFeed());
    unawaited(_loadHomeSections());
    ensureLoaded(HomeSectionKind.promotedGroups);
  }

  Future<void> refresh() async {
    unawaited(_prefetchFeed(refresh: true));
    final loaded = _sectionOrder.where(
      (kind) =>
          !_isPlaceholder(kind) &&
          !_callableSections.containsKey(kind) &&
          section(kind).state != LoadingState.initial,
    );
    // The ranked sections come from one callable, so they refresh as one unit
    // rather than showing five independent spinners.
    await Future.wait(<Future<void>>[
      _loadHomeSections(refresh: true),
      ...loaded.map((kind) => _loadSection(kind, refresh: true)),
    ]);
  }

  /// Loads every ranked section in one callable round-trip.
  ///
  /// These sections come from a single server response, so they are refreshed
  /// together rather than section by section: firing five callables would show
  /// five independent spinners for one coherent piece of data.
  Future<void> _loadHomeSections({bool refresh = false}) async {
    final kinds = _callableSections.keys.toList(growable: false);
    for (final kind in kinds) {
      // A refresh must not blank rows the user is already reading, so the
      // section keeps its content and only its spinner state changes.
      final next = refresh && section(kind).hasContent
          ? LoadingState.refreshing
          : LoadingState.loading;
      if (section(kind).state != next) {
        _sections[kind] = section(
          kind,
        ).copyWith(state: next, clearFailure: true);
      }
    }
    _safeNotify();

    final result = await _repository.getHomeSections(limit: _pageSize);
    if (_disposed || _userId == null) return;

    result.fold(
      onSuccess: (pages) {
        for (final entry in _callableSections.entries) {
          final page = pages[entry.value] ?? const DiscoverySectionPage();
          _sections[entry.key] = section(entry.key).copyWith(
            state: page.items.isEmpty
                ? LoadingState.empty
                : LoadingState.loaded,
            items: page.items,
            clearFailure: true,
            hasMore: false,
          );
        }
        _analytics?.logEvent(
          'home_ranked_sections_loaded',
          parameters: {
            'sections': _callableSections.length,
            'nonEmpty': _callableSections.entries
                .where((entry) => section(entry.key).items.isNotEmpty)
                .length,
          },
        );
      },
      onFailure: (failure) {
        for (final kind in kinds) {
          // Content that already loaded stays visible; only an empty section
          // degrades to an error, so a refresh failure does not wipe the page.
          _sections[kind] = section(kind).copyWith(
            state: section(kind).hasContent
                ? LoadingState.offline
                : LoadingState.error,
            failure: failure,
          );
        }
      },
    );
    _safeNotify();
  }

  void ensureLoaded(HomeSectionKind kind) {
    if (_userId == null ||
        _isPlaceholder(kind) ||
        section(kind).state != LoadingState.initial) {
      return;
    }
    // The ranked sections are already served by the single Home callable, so
    // they must not also be fetched one at a time or the two paths would
    // overwrite each other.
    if (_callableSections.containsKey(kind)) {
      unawaited(_loadHomeSections());
      return;
    }
    unawaited(_loadSection(kind, refresh: false));
  }

  Future<void> retrySection(HomeSectionKind kind) async {
    if (_userId == null || _isPlaceholder(kind)) return;
    if (_callableSections.containsKey(kind)) {
      await _loadHomeSections();
      return;
    }
    await _loadSection(kind, refresh: true);
  }

  Future<void> loadMore(HomeSectionKind kind) async {
    final current = section(kind);
    if (!current.hasMore ||
        current.state == LoadingState.loadingMore ||
        !current.hasContent) {
      return;
    }
    await _loadSection(kind, refresh: false, loadMore: true);
  }

  Future<void> _prefetchFeed({bool refresh = false}) async {
    final result = await _repository.getDiscoveryFeed(limit: _pageSize);
    if (_disposed) return;
    result.fold(
      onSuccess: (feed) {
        _feed = feed;
        _analytics?.logEvent(
          'home_feed_loaded',
          parameters: {
            'coldStart': feed.coldStart ? 1 : 0,
            'sections': feed.sections.length,
            if (refresh) 'refresh': 1,
          },
        );
      },
      onFailure: (_) {},
    );
    _safeNotify();
  }

  Future<void> _loadSection(
    HomeSectionKind kind, {
    required bool refresh,
    bool loadMore = false,
  }) async {
    final current = section(kind);
    _sections[kind] = current.copyWith(
      state: loadMore
          ? LoadingState.loadingMore
          : refresh
          ? LoadingState.refreshing
          : LoadingState.loading,
      clearFailure: true,
    );
    _safeNotify();
    _analytics?.logEvent(
      'section_impression',
      parameters: {'section': kind.name},
    );
    if (kind == HomeSectionKind.recommendedPeople) {
      final result = await _repository.getRecommendedPeople(
        userId: _userId!,
        limit: _pageSize,
        after: loadMore ? current.people.last : null,
      );
      if (_disposed) return;
      result.fold(
        onSuccess: (people) {
          final combined = loadMore
              ? <PublicProfile>[...current.people, ...people]
              : people;
          _sections[kind] = current.copyWith(
            state: combined.isEmpty ? LoadingState.empty : LoadingState.loaded,
            people: combined,
            hasMore: people.length == _pageSize,
          );
        },
        onFailure: (failure) => _setSectionFailure(kind, current, failure),
      );
    } else {
      final result = switch (kind) {
        HomeSectionKind.promotedGroups => _repository.getPromotedGroups(
          limit: _pageSize,
          after: loadMore ? current.groups.last : null,
        ),
        HomeSectionKind.risingGroups => _repository.getRisingGroups(
          limit: _pageSize,
          after: loadMore ? current.groups.last : null,
        ),
        HomeSectionKind.recommendedGroups => _repository.getRecommendedGroups(
          limit: _pageSize,
          after: loadMore ? current.groups.last : null,
        ),
        HomeSectionKind.communityActivity => _repository.getCommunityActivity(
          limit: _pageSize,
          after: loadMore ? current.groups.last : null,
        ),
        _ => Future.value(const Success(<Group>[])),
      };
      final groupResult = await result;
      if (_disposed) return;
      groupResult.fold(
        onSuccess: (groups) {
          final combined = loadMore
              ? <Group>[...current.groups, ...groups]
              : groups;
          _sections[kind] = current.copyWith(
            state: combined.isEmpty ? LoadingState.empty : LoadingState.loaded,
            groups: combined,
            hasMore: groups.length == _pageSize,
          );
        },
        onFailure: (failure) => _setSectionFailure(kind, current, failure),
      );
    }
    _safeNotify();
  }

  void _setSectionFailure(
    HomeSectionKind kind,
    HomeSectionState current,
    Failure failure,
  ) {
    _sections[kind] = current.copyWith(
      state: current.hasContent ? LoadingState.offline : LoadingState.error,
      failure: failure,
    );
  }

  bool _isPlaceholder(HomeSectionKind kind) => switch (kind) {
    HomeSectionKind.editsPlaceholder ||
    HomeSectionKind.eventsPlaceholder ||
    HomeSectionKind.gamesPlaceholder ||
    HomeSectionKind.fanWorksPlaceholder ||
    HomeSectionKind.animePlaceholder => true,
    _ => false,
  };

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
