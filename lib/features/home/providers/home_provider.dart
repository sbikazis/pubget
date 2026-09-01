import 'dart:async';

import 'package:flutter/foundation.dart';

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
    this.failure,
    this.hasMore = true,
  });

  final HomeSectionKind kind;
  final LoadingState state;
  final List<Group> groups;
  final List<PublicProfile> people;
  final Failure? failure;
  final bool hasMore;

  bool get hasContent => groups.isNotEmpty || people.isNotEmpty;

  HomeSectionState copyWith({
    LoadingState? state,
    List<Group>? groups,
    List<PublicProfile>? people,
    Failure? failure,
    bool clearFailure = false,
    bool? hasMore,
  }) => HomeSectionState(
    kind: kind,
    state: state ?? this.state,
    groups: groups ?? this.groups,
    people: people ?? this.people,
    failure: clearFailure ? null : failure ?? this.failure,
    hasMore: hasMore ?? this.hasMore,
  );
}

final class HomeProvider extends ChangeNotifier {
  HomeProvider({required HomeRepository repository})
    : _repository = repository {
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
    HomeSectionKind.editsPlaceholder,
    HomeSectionKind.eventsPlaceholder,
    HomeSectionKind.animePlaceholder,
  ];

  final HomeRepository _repository;
  late Map<HomeSectionKind, HomeSectionState> _sections;
  DiscoverySearchResults _searchResults = const DiscoverySearchResults();
  LoadingState _searchState = LoadingState.initial;
  Failure? _searchFailure;
  Timer? _searchDebounce;
  String? _userId;
  bool _disposed = false;
  static const _pageSize = 8;

  List<HomeSectionKind> get sectionOrder => _sectionOrder;
  HomeSectionState section(HomeSectionKind kind) => _sections[kind]!;
  DiscoverySearchResults get searchResults => _searchResults;
  LoadingState get searchState => _searchState;
  Failure? get searchFailure => _searchFailure;

  void load(String userId) {
    _userId = userId;
    ensureLoaded(HomeSectionKind.promotedGroups);
  }

  Future<void> refresh() async {
    final loaded = _sectionOrder.where(
      (kind) =>
          !_isPlaceholder(kind) && section(kind).state != LoadingState.initial,
    );
    await Future.wait(loaded.map((kind) => _loadSection(kind, refresh: true)));
  }

  void ensureLoaded(HomeSectionKind kind) {
    if (_userId == null ||
        _isPlaceholder(kind) ||
        section(kind).state != LoadingState.initial) {
      return;
    }
    unawaited(_loadSection(kind, refresh: false));
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

  void searchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      _searchResults = const DiscoverySearchResults();
      _searchState = LoadingState.initial;
      _safeNotify();
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 280),
      () => unawaited(_search(query)),
    );
  }

  Future<void> _search(String query) async {
    _searchState = LoadingState.loading;
    _searchFailure = null;
    _safeNotify();
    final result = await _repository.search(query);
    result.fold(
      onSuccess: (results) {
        _searchResults = results;
        _searchState = results.isEmpty
            ? LoadingState.empty
            : LoadingState.loaded;
      },
      onFailure: (failure) {
        _searchFailure = failure;
        _searchState = LoadingState.error;
      },
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
    HomeSectionKind.animePlaceholder => true,
    _ => false,
  };

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();
    super.dispose();
  }
}
