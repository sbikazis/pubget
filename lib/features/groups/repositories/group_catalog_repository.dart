import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/group_catalog_models.dart';

/// Master Spec 7.3 / 11: the anime a roleplay group is bound to, and the cast
/// it can draw from, are read from the canonical server catalog. The client
/// never holds a list of titles: it asks, the server answers with real IDs
/// resolved from MyAnimeList through AniList, and the answer is cached there so
/// an offline phone still gets a roster instead of an empty list.
abstract interface class GroupCatalogRepository {
  /// One page of the catalog. A blank [query] browses by [request.kind];
  /// a non-blank [query] searches the whole catalog instead.
  Future<Result<GroupCatalogPage>> browseAnime(
    GroupCatalogRequest request, {
    int page = 1,
  });

  /// One page of roleplay characters. With [animeId] the answer is the whole
  /// work — every season of it — with each character tagged by season. Without
  /// one it is a free search of the character catalog, which is what an open
  /// roleplay group uses.
  Future<Result<GroupCharacterPage>> browseCharacters(
    GroupCharacterRequest request, {
    int page = 1,
  });
}

/// How a group browse is scoped. Mirrors the server's `browseAnime` axis set.
final class GroupCatalogRequest {
  const GroupCatalogRequest({
    this.kind = GroupCatalogKind.popular,
    this.query = '',
    this.year,
    this.season,
    this.genre,
    this.type,
  });

  const GroupCatalogRequest.search(this.query)
    : kind = GroupCatalogKind.popular,
      year = null,
      season = null,
      genre = null,
      type = null;

  const GroupCatalogRequest.seasonOf(int this.year, String this.season)
    : kind = GroupCatalogKind.season,
      query = '',
      genre = null,
      type = null;

  final GroupCatalogKind kind;
  final String query;
  final int? year;
  final String? season;
  final String? genre;
  final String? type;

  /// A cache/identity key: two requests that resolve the same titles share one
  /// request, two that do not never collide.
  String get cacheKey => switch (this) {
    _ when query.trim().isNotEmpty => 'search:${query.trim().toLowerCase()}',
    _ when kind == GroupCatalogKind.season =>
      'season:$year:${(season ?? '').toLowerCase()}',
    _ => '${kind.name}:${(genre ?? '').toLowerCase()}:${(type ?? '').toLowerCase()}',
  };

  Map<String, dynamic> toMap(int page, int limit) => <String, dynamic>{
    'kind': kind.name,
    'page': page,
    'limit': limit,
    if (query.trim().isNotEmpty) 'query': query.trim(),
    if (year != null) 'year': year,
    if (season != null && season!.isNotEmpty) 'season': season,
    if (genre != null && genre!.isNotEmpty) 'genre': genre,
    if (type != null && type!.isNotEmpty) 'type': type,
  };
}

/// A roleplay roster request: a work's whole family, or the free catalog.
final class GroupCharacterRequest {
  const GroupCharacterRequest.forAnime(
    this.animeId, {
    this.query = '',
    this.groupId,
  }) : open = false;

  const GroupCharacterRequest.open({this.query = '', this.groupId})
    : animeId = null,
      open = true;

  /// A search that keeps whichever scope it was opened in.
  factory GroupCharacterRequest.search({
    String? animeId,
    String query = '',
    String? groupId,
  }) {
    final id = animeId?.trim() ?? '';
    return id.isEmpty
        ? GroupCharacterRequest.open(query: query, groupId: groupId)
        : GroupCharacterRequest.forAnime(id, query: query, groupId: groupId);
  }

  final String? animeId;
  final String query;

  /// The group whose reserved characters should be locked. Only meaningful for
  /// a join, not for a group's own creation wizard.
  final String? groupId;
  final bool open;

  String get cacheKey {
    final scope = animeId ?? 'open';
    return '$scope:${query.trim().toLowerCase()}';
  }

  Map<String, dynamic> toMap(int page, int limit) => <String, dynamic>{
    'page': page,
    'limit': limit,
    if (animeId != null && animeId!.isNotEmpty) 'animeId': animeId,
    if (query.trim().isNotEmpty) 'query': query.trim(),
    if (groupId != null && groupId!.isNotEmpty) 'groupId': groupId,
  };
}

final class FirebaseGroupCatalogRepository implements GroupCatalogRepository {
  FirebaseGroupCatalogRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  @override
  Future<Result<GroupCatalogPage>> browseAnime(
    GroupCatalogRequest request, {
    int page = 1,
  }) => _guard(() async {
    final data = await _call('browseAnimeCatalog', request.toMap(page, 25));
    return GroupCatalogPage.fromMap(data);
  });

  @override
  Future<Result<GroupCharacterPage>> browseCharacters(
    GroupCharacterRequest request, {
    int page = 1,
  }) => _guard(() async {
    final data = await _call('browseRoleplayCharacters', request.toMap(page, 25));
    return GroupCharacterPage.fromMap(data);
  });

  /// The characters already taken in a group. The picker locks them without
  /// learning who holds them.
  Future<Result<Set<String>>> reservedCharacterKeys(String groupId) =>
      _guard(() async {
        final data = await _call('reservedGroupCharacters', <String, dynamic>{
          'groupId': groupId,
        });
        final keys = (data['reservedKeys'] as List<Object?>? ?? const <Object?>[])
            .whereType<String>()
            .toSet();
        return keys;
      });

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    final result = await _functions.httpsCallable(name).call(payload);
    final data = result.data;
    if (data is! Map) {
      throw const FormatException('Unexpected catalog response.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success<T>(await action());
    } on Object catch (error) {
      return FailureResult<T>(catalogFailure(error));
    }
  }
}

/// Reports the catalog as unavailable, never as "no results": a picker that
/// cannot tell the two apart shows an empty list and looks like a dead feature.
Failure catalogFailure(Object error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' || 'permission-denied' => PermissionError(
        error.message ?? 'You are not allowed to browse the catalog.',
      ),
      'unavailable' || 'deadline-exceeded' => NetworkError(
        error.message ?? 'The catalog is unreachable right now.',
      ),
      'resource-exhausted' => RateLimitedError(
        error.message ?? 'Too many requests. Please wait a moment.',
      ),
      _ => UnavailableError(error.message ?? 'The catalog could not be read.'),
    };
  }
  if (error is FormatException) {
    return const MalformedDataError();
  }
  if (error is TimeoutException) {
    return const TimeoutError();
  }
  return UnavailableError(error.toString());
}

/// Read-only stand-in used when the platform has no callable backend (tests,
/// a build without Firebase). It never pretends to have titles: the picker
/// shows an explicit unavailable state instead of an empty list.
final class UnavailableGroupCatalogRepository implements GroupCatalogRepository {
  const UnavailableGroupCatalogRepository();

  @override
  Future<Result<GroupCatalogPage>> browseAnime(
    GroupCatalogRequest request, {
    int page = 1,
  }) async => const FailureResult<GroupCatalogPage>(
    UnavailableError('The anime catalog is unavailable right now.'),
  );

  @override
  Future<Result<GroupCharacterPage>> browseCharacters(
    GroupCharacterRequest request, {
    int page = 1,
  }) async => const FailureResult<GroupCharacterPage>(
    UnavailableError('The character catalog is unavailable right now.'),
  );
}
