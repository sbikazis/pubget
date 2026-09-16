import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/anime_list_models.dart';
import '../models/anime_rating_models.dart';
import 'anime_hub_social_repository.dart';

final class FirebaseAnimeHubSocialRepository
    implements AnimeHubSocialRepository {
  FirebaseAnimeHubSocialRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<Result<AnimeCommunityStats?>> getAnimeStats(String animeId) =>
      _guard(() async {
        final snap = await _firestore.collection('anime_stats').doc(animeId).get();
        if (!snap.exists || snap.data() == null) return null;
        return AnimeCommunityStats.fromMap(snap.data()!, id: snap.id);
      });

  @override
  Future<Result<AnimeReview?>> getMyRating(String animeId) => _guard(() async {
    final uid = _uid;
    if (uid == null) return null;
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('anime_ratings')
        .doc(animeId)
        .get();
    if (!snap.exists || snap.data() == null) return null;
    return AnimeReview.fromMap(snap.data()!, id: uid);
  });

  @override
  Future<Result<List<AnimeReview>>> listReviews(
    String animeId, {
    int limit = 30,
  }) => _guard(() async {
    final snap = await _firestore
        .collection('anime_stats')
        .doc(animeId)
        .collection('reviews')
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((doc) => AnimeReview.fromMap(doc.data(), id: doc.id))
        .toList(growable: false);
  });

  @override
  Future<Result<AnimeReview>> upsertRating({
    required String animeId,
    required AnimeCriteriaScores criteria,
    String title = '',
    String? imageUrl,
    String comment = '',
  }) => _guard(() async {
    final result = await _functions.httpsCallable('upsertAnimeRating').call(
      <String, dynamic>{
        'animeId': animeId,
        'criteria': criteria.toMap(),
        'title': title,
        'imageUrl': ?imageUrl,
        'comment': comment,
      },
    );
    final data = Map<String, dynamic>.from(result.data as Map);
    return AnimeReview(
      animeId: data['animeId'] as String? ?? animeId,
      userId: _uid ?? '',
      criteria: AnimeCriteriaScores.fromMap(
        data['criteria'] is Map
            ? Map<String, dynamic>.from(data['criteria'] as Map)
            : criteria.toMap(),
      ),
      overall: (data['overall'] as num?)?.toDouble() ?? criteria.overall,
      comment: data['comment'] as String? ?? comment,
      title: title,
      imageUrl: imageUrl,
    );
  });

  @override
  Future<Result<void>> deleteRating(String animeId) => _guard(() async {
    await _functions.httpsCallable('deleteAnimeRating').call(
      <String, dynamic>{'animeId': animeId},
    );
  });

  @override
  Future<Result<void>> reportReview({
    required String animeId,
    required String targetUserId,
    required String reason,
    String details = '',
  }) => _guard(() async {
    await _functions.httpsCallable('reportAnimeReview').call(
      <String, dynamic>{
        'animeId': animeId,
        'targetUserId': targetUserId,
        'reason': reason,
        'details': details,
      },
    );
  });

  @override
  Future<Result<List<AnimeCommunityStats>>> listTopRated({int limit = 40}) =>
      _guard(() async {
        final snap = await _firestore
            .collection('anime_stats')
            .orderBy('averageScore', descending: true)
            .orderBy('ratingCount', descending: true)
            .limit(limit)
            .get();
        return snap.docs
            .map((doc) => AnimeCommunityStats.fromMap(doc.data(), id: doc.id))
            .where((item) => item.ratingCount > 0)
            .toList(growable: false);
      });

  @override
  Future<Result<List<CharacterCommunityStats>>> listPopularCharacters({
    int limit = 40,
  }) => _guard(() async {
    final snap = await _firestore
        .collection('character_stats')
        .orderBy('favoritesCount', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map(
          (doc) => CharacterCommunityStats.fromMap(doc.data(), id: doc.id),
        )
        .where((item) => item.favoritesCount > 0)
        .toList(growable: false);
  });

  @override
  Future<Result<CharacterCommunityStats?>> getCharacterStats(
    String characterId,
  ) => _guard(() async {
    final snap = await _firestore
        .collection('character_stats')
        .doc(characterId)
        .get();
    if (!snap.exists || snap.data() == null) return null;
    return CharacterCommunityStats.fromMap(snap.data()!, id: snap.id);
  });

  @override
  Future<Result<List<AnimeReview>>> listUserRatings(String userId) =>
      _guard(() async {
        final snap = await _firestore
            .collection('users')
            .doc(userId)
            .collection('anime_ratings')
            .get();
        final items = snap.docs
            .map((doc) => AnimeReview.fromMap(doc.data(), id: userId))
            .toList(growable: false);
        items.sort((a, b) => b.overall.compareTo(a.overall));
        return items;
      });

  @override
  Future<Result<List<AnimeListEntry>>> listUserAnimeList(String userId) =>
      _guard(() async {
        final snap = await _firestore
            .collection('users')
            .doc(userId)
            .collection('anime_lists')
            .get();
        return snap.docs
            .map((doc) => AnimeListEntry.fromMap(doc.data(), id: doc.id))
            .toList(growable: false);
      });

  @override
  Future<Result<List<CharacterFavorite>>> listUserCharacterFavorites(
    String userId,
  ) => _guard(() async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('character_favorites')
        .limit(80)
        .get();
    return snap.docs
        .map((doc) => CharacterFavorite.fromMap(doc.data(), id: doc.id))
        .toList(growable: false);
  });

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on Object catch (error) {
      return FailureResult(_fail(error));
    }
  }
}

Failure _fail(Object error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' || 'permission-denied' => PermissionError(
        error.message ?? 'Anime ratings require a signed-in account.',
      ),
      'resource-exhausted' => CooldownActiveError(
        error.message ?? 'Please wait before rating again.',
      ),
      'unavailable' || 'deadline-exceeded' => const NetworkError(
        'Check your connection and try again.',
      ),
      'invalid-argument' => ValidationError(
        error.message ?? 'That rating is not valid.',
      ),
      _ => UnknownError(error.message ?? 'Anime rating update failed.'),
    };
  }
  return const UnknownError('Anime rating update failed.');
}
