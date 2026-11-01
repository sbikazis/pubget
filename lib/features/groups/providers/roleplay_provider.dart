import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/group_catalog_models.dart';
import '../models/group_models.dart';
import '../repositories/group_catalog_repository.dart';
import '../repositories/roleplay_repository.dart';

/// The reserve tray on a roleplay group.
///
/// The roster comes from the server catalog, not from a device table: an anime
/// group gets the cast of the whole work — every season of it — and an open
/// group gets the character catalog itself. The previous version asked the
/// client-side anime repository for one season's cast and, for open groups, a
/// `character_stats` popularity table that is empty until the community has
/// rated characters, so a new product could not open a roleplay group at all.
final class RoleplayProvider extends ChangeNotifier {
  RoleplayProvider({
    required RoleplayRepository repository,
    required GroupCatalogRepository catalogRepository,
    this.pageSize = 25,
    this.maxPages = 12,
  }) : _repository = repository,
       _catalog = catalogRepository;

  final RoleplayRepository _repository;
  final GroupCatalogRepository _catalog;
  final int pageSize;

  /// A bound on how far the tray will page. The catalog caps a work's family,
  /// so this reads the whole roster rather than the first page while never
  /// turning one screen into an unbounded crawl.
  final int maxPages;
  List<RoleplayCharacter> _characters = const <RoleplayCharacter>[];
  LoadingState _state = LoadingState.initial;
  Failure? _failure;

  List<RoleplayCharacter> get characters => _characters;
  LoadingState get state => _state;
  Failure? get failure => _failure;

  Future<void> load(String groupId) async {
    _state = LoadingState.loading;
    notifyListeners();
    final context = await _repository.roleplayContext(groupId);
    if (context.isSuccess) {
      await _loadCatalog(context.valueOrNull!);
    } else {
      _setFailure(context.failureOrNull!);
    }
  }

  Future<void> _loadCatalog(RoleplayGroupContext context) async {
    final reserved = context.reservedKeys;
    final catalog = await _roster(context, reserved);
    catalog.fold(
      onSuccess: (characters) {
        _characters = characters;
        _state = characters.isEmpty ? LoadingState.empty : LoadingState.loaded;
        _failure = null;
      },
      onFailure: _setFailure,
    );
    notifyListeners();
  }

  /// Reads the roster page by page and drops the characters the group has
  /// already taken, so the tray shows what is actually left to pick.
  Future<Result<List<RoleplayCharacter>>> _roster(
    RoleplayGroupContext context,
    Set<String> reserved,
  ) async {
    final type = context.type;
    if (type == null || type == GroupType.public) {
      return const Success(<RoleplayCharacter>[]);
    }
    final animeId = context.animeId?.trim() ?? '';
    final bound = type == GroupType.animeRoleplay;
    if (bound && animeId.isEmpty) {
      return const Success(<RoleplayCharacter>[]);
    }
    final collected = <String, RoleplayCharacter>{};
    var hasNextPage = true;
    for (var page = 1; page <= maxPages && hasNextPage; page += 1) {
      final request = bound
          ? GroupCharacterRequest.forAnime(animeId)
          : const GroupCharacterRequest.open();
      final result = await _catalog.browseCharacters(request, page: page);
      if (result case FailureResult<GroupCharacterPage> failure) {
        // A partial roster that already has something in it is a usable
        // answer; an empty one is the failure itself.
        return collected.isEmpty
            ? FailureResult<List<RoleplayCharacter>>(failure.failure)
            : Success<List<RoleplayCharacter>>(
                collected.values.toList(growable: false),
              );
      }
      final pageData = result.valueOrNull!;
      for (final character in pageData.items) {
        if (reserved.contains(character.key)) continue;
        collected.putIfAbsent(character.key, () => character);
      }
      hasNextPage = pageData.hasNextPage && pageData.items.isNotEmpty;
    }
    return Success<List<RoleplayCharacter>>(collected.values.toList(growable: false));
  }

  Future<Result<void>> reserve(
    String groupId,
    RoleplayCharacter character,
  ) async {
    _state = LoadingState.refreshing;
    notifyListeners();
    final result = await _repository.reserveCharacter(
      groupId: groupId,
      characterKey: character.key,
      character: character,
    );
    result.fold(
      onSuccess: (_) {
        _characters = _characters
            .where((item) => item.key != character.key)
            .toList(growable: false);
        _state = LoadingState.loaded;
        notifyListeners();
      },
      onFailure: _setFailure,
    );
    return result;
  }

  void _setFailure(Failure failure) {
    _failure = failure;
    _state = failure is NetworkError
        ? LoadingState.offline
        : LoadingState.error;
    notifyListeners();
  }
}