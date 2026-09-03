import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../groups/models/group_models.dart';
import '../../events/models/event_models.dart';
import '../../fan_works/models/fan_work_models.dart';
import '../../search/search_query.dart';
import '../../social/models/public_profile.dart';
import '../models/home_models.dart';
import 'home_repository.dart';

final class FirebaseHomeRepository implements HomeRepository {
  FirebaseHomeRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Query<Map<String, dynamic>> _groups() =>
      _firestore.collection('groups').where('isSearchable', isEqualTo: true);

  Future<Result<List<Group>>> _groupQuery(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      final snapshot = await query.get();
      return Success(
        snapshot.docs
            .map((doc) => Group.fromMap(doc.data(), id: doc.id))
            .toList(growable: false),
      );
    } on Object catch (error) {
      return FailureResult(_failure(error));
    }
  }

  @override
  Future<Result<List<Group>>> getPromotedGroups({
    int limit = 10,
    Group? after,
  }) {
    var query = _groups()
        .where('isPromoted', isEqualTo: true)
        .where('promotionExpiresAt', isGreaterThan: Timestamp.now())
        .orderBy('promotionExpiresAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (after != null) {
      query = query.startAfter(<Object?>[after.promotionExpiresAt, after.id]);
    }
    return _groupQuery(query.limit(limit));
  }

  @override
  Future<Result<List<Group>>> getRisingGroups({int limit = 10, Group? after}) {
    var query = _groups()
        .where('risingEligible', isEqualTo: true)
        .orderBy('risingScore', descending: true)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (after != null) {
      query = query.startAfter(<Object?>[
        after.risingScore,
        after.createdAt,
        after.id,
      ]);
    }
    return _groupQuery(query.limit(limit));
  }

  @override
  Future<Result<List<Group>>> getRecommendedGroups({
    int limit = 10,
    Group? after,
  }) async {
    final ranked = await getDiscoveryFeed(
      section: 'recommendedGroups',
      cursor: after?.id,
      limit: limit,
    );
    if (ranked.isSuccess) {
      final groups = ranked.valueOrNull
              ?.section('recommendedGroups')
              .items
              .map(_groupFromItem)
              .whereType<Group>()
              .toList(growable: false) ??
          const <Group>[];
      if (groups.isNotEmpty) return Success(groups);
    }
    var query = _groups()
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (after != null) {
      query = query.startAfter(<Object?>[after.createdAt, after.id]);
    }
    return _groupQuery(query.limit(limit));
  }

  @override
  Future<Result<List<Group>>> getCommunityActivity({
    int limit = 10,
    Group? after,
  }) {
    var query = _groups()
        .orderBy('lastMessageAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (after != null) {
      query = query.startAfter(<Object?>[after.lastActivityAt, after.id]);
    }
    return _groupQuery(query.limit(limit));
  }

  @override
  Future<Result<List<PublicProfile>>> getRecommendedPeople({
    required String userId,
    int limit = 10,
    PublicProfile? after,
  }) async {
    final ranked = await getDiscoveryFeed(
      section: 'recommendedPeople',
      cursor: after?.uid,
      limit: limit,
    );
    if (ranked.isSuccess) {
      final people = ranked.valueOrNull
              ?.section('recommendedPeople')
              .items
              .map(_personFromItem)
              .where((person) => person.uid != userId)
              .toList(growable: false) ??
          const <PublicProfile>[];
      if (people.isNotEmpty) return Success(people);
    }
    try {
      var query = _firestore
          .collection('public_profiles')
          .orderBy('totalRespect', descending: true)
          .orderBy(FieldPath.documentId, descending: true);
      if (after != null) {
        query = query.startAfter(<Object>[after.totalRespect, after.uid]);
      }
      final snapshot = await query.limit(limit + 1).get();
      return Success(
        snapshot.docs
            .where((doc) => doc.id != userId)
            .take(limit)
            .map((doc) => PublicProfile.fromMap(doc.data(), uid: doc.id))
            .toList(growable: false),
      );
    } on Object catch (error) {
      return FailureResult(_failure(error));
    }
  }

  @override
  Future<Result<DiscoveryFeed>> getDiscoveryFeed({
    String? section,
    String? cursor,
    int limit = 8,
  }) async {
    try {
      final result = await _functions.httpsCallable('getDiscoveryFeed').call(
        <String, dynamic>{
          if (section != null) 'section': section,
          if (cursor != null) 'cursor': cursor,
          'limit': limit,
        },
      );
      final data = Map<String, dynamic>.from(result.data as Map);
      return Success(DiscoveryFeed.fromMap(data));
    } on Object catch (error) {
      return FailureResult(_failure(error));
    }
  }

  @override
  Future<Result<DiscoverySearchResults>> search(String query) async {
    final normalized = SearchQuery.prefix(query);
    if (normalized.length < SearchQuery.minLength) {
      return const Success(DiscoverySearchResults());
    }
    try {
      final end = '$normalized\uf8ff';
      final groupsFuture = _firestore
          .collection('groups')
          .where('isSearchable', isEqualTo: true)
          .where('searchName', isGreaterThanOrEqualTo: normalized)
          .where('searchName', isLessThanOrEqualTo: end)
          .limit(20)
          .get();
      final peopleFuture = _firestore
          .collection('public_profiles')
          .where('username', isGreaterThanOrEqualTo: normalized)
          .where('username', isLessThanOrEqualTo: end)
          .limit(20)
          .get();
      final eventsFuture = _firestore
          .collection('events')
          .where('status', whereIn: <String>['active', 'scheduled', 'ended'])
          .where('searchName', isGreaterThanOrEqualTo: normalized)
          .where('searchName', isLessThanOrEqualTo: end)
          .limit(20)
          .get();
      final fanWorksFuture = _firestore
          .collection('fanWorks')
          .where('status', isEqualTo: 'published')
          .where('moderationStatus', isEqualTo: 'approved')
          .where('searchTitle', isGreaterThanOrEqualTo: normalized)
          .where('searchTitle', isLessThanOrEqualTo: end)
          .limit(20)
          .get();
      final results = await Future.wait([
        groupsFuture,
        peopleFuture,
        eventsFuture,
        fanWorksFuture,
      ]);
      final groups = results[0];
      final people = results[1];
      final events = results[2];
      final fanWorks = results[3];
      return Success(
        DiscoverySearchResults(
          groups: _uniqueBy(
            groups.docs.map((doc) => Group.fromMap(doc.data(), id: doc.id)),
            (group) => group.id,
          ),
          people: _uniqueBy(
            people.docs.map(
              (doc) => PublicProfile.fromMap(doc.data(), uid: doc.id),
            ),
            (person) => person.uid,
          ),
          events: _uniqueBy(
            events.docs.map(
              (doc) => PubgetEvent.fromMap(doc.data(), id: doc.id),
            ),
            (event) => event.id,
          ),
          fanWorks: _uniqueBy(
            fanWorks.docs.map(
              (doc) => FanWorkPreview.fromMap(doc.data(), id: doc.id),
            ),
            (work) => work.id,
          ),
        ),
      );
    } on Object catch (error) {
      return FailureResult(_failure(error));
    }
  }
}

Group? _groupFromItem(DiscoveryItem item) {
  final data = Map<String, dynamic>.from(item.metadata);
  if (item.targetId.isEmpty) return null;
  return Group.fromMap(data, id: item.targetId);
}

PublicProfile _personFromItem(DiscoveryItem item) {
  return PublicProfile.fromMap(item.metadata, uid: item.targetId);
}

List<T> _uniqueBy<T>(Iterable<T> items, String Function(T value) idOf) {
  final seen = <String>{};
  final unique = <T>[];
  for (final item in items) {
    final id = idOf(item);
    if (id.isEmpty || !seen.add(id)) continue;
    unique.add(item);
  }
  return List<T>.unmodifiable(unique);
}

Failure _failure(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'unavailable' || 'deadline-exceeded' => const NetworkError(
        'Check your connection and try again.',
      ),
      'permission-denied' => const PermissionError(
        'Discovery is not available for this account.',
      ),
      _ => const UnknownError('Discovery could not load.'),
    };
  }
  return const UnknownError('Discovery could not load.');
}
