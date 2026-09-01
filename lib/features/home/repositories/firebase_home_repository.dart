import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../groups/models/group_models.dart';
import '../../events/models/event_models.dart';
import '../../social/models/public_profile.dart';
import '../models/home_models.dart';
import 'home_repository.dart';

final class FirebaseHomeRepository implements HomeRepository {
  FirebaseHomeRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
        .orderBy('activityScore', descending: true)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (after != null) {
      query = query.startAfter(<Object?>[
        after.activityScore,
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
  }) {
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
  Future<Result<DiscoverySearchResults>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const Success(DiscoverySearchResults());
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
      final results = await Future.wait([
        groupsFuture,
        peopleFuture,
        eventsFuture,
      ]);
      final groups = results[0];
      final people = results[1];
      final events = results[2];
      return Success(
        DiscoverySearchResults(
          groups: groups.docs
              .map((doc) => Group.fromMap(doc.data(), id: doc.id))
              .toList(growable: false),
          people: people.docs
              .map((doc) => PublicProfile.fromMap(doc.data(), uid: doc.id))
              .toList(growable: false),
          events: events.docs
              .map((doc) => PubgetEvent.fromMap(doc.data(), id: doc.id))
              .toList(growable: false),
        ),
      );
    } on Object catch (error) {
      return FailureResult(_failure(error));
    }
  }
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
      _ => UnknownError(error.message ?? 'Discovery could not load.'),
    };
  }
  return UnknownError(error.toString());
}
