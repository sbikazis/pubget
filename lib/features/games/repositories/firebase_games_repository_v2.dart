import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/games_schema_v2.dart';
import 'games_repository_v2.dart';

final class FirebaseGamesRepositoryV2 implements GamesRepositoryV2 {
  FirebaseGamesRepositoryV2({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  CollectionReference<Map<String, dynamic>> get _games =>
      _firestore.collection('games_v2');

  @override
  Future<Result<GameSessionV2>> create({
    required String groupId,
    required GameTypeV2 type,
    required String requestId,
  }) => _guard(() async {
    final result = await _functions.httpsCallable('gamesV2Create').call({
      'groupId': groupId,
      'type': type.name,
      'requestId': requestId,
      'schemaVersion': gamesSchemaVersion,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final id = data['gameId'] as String;
    final snapshot = await _games.doc(id).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('Created game was not returned by the server.');
    }
    return GameSessionV2.fromMap(snapshot.data()!, id: id);
  });

  @override
  Future<Result<void>> command(GameCommandRequest request) => _guard(() async {
    await _functions.httpsCallable('gamesV2Command').call(request.toMap());
  });

  @override
  Stream<Result<GameSessionV2>> watchSession(String gameId) => _games
      .doc(gameId)
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return const FailureResult<GameSessionV2>(
            NotFoundError('This game session no longer exists.'),
          );
        }
        return Success(
          GameSessionV2.fromMap(snapshot.data()!, id: snapshot.id),
        );
      })
      .handleError(
        (Object error) => FailureResult<GameSessionV2>(_failure(error)),
      );

  @override
  Stream<Result<Map<String, dynamic>>> watchPrivateState({
    required String gameId,
    required String userId,
  }) => _games
      .doc(gameId)
      .collection('private')
      .doc(userId)
      .snapshots()
      .map((snapshot) => Success(snapshot.data() ?? const <String, dynamic>{}));

  @override
  Future<Result<GameHistoryPage>> groupHistory({
    required String groupId,
    String? cursor,
    int limit = 20,
  }) => _guard(() async {
    var query = _games
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'completed')
        .orderBy('endedAt', descending: true)
        .limit(limit.clamp(1, 50));
    if (cursor != null && cursor.isNotEmpty) {
      final anchor = await _games.doc(cursor).get();
      if (anchor.exists) query = query.startAfterDocument(anchor);
    }
    final snapshot = await query.get();
    return GameHistoryPage(
      games: snapshot.docs
          .map((doc) => GameSessionV2.fromMap(doc.data(), id: doc.id))
          .toList(growable: false),
      nextCursor: snapshot.docs.length == limit ? snapshot.docs.last.id : null,
    );
  });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on Object catch (error) {
      return FailureResult(_failure(error));
    }
  }

  Failure _failure(Object error) {
    if (error is FirebaseFunctionsException) {
      if (error.code == 'unavailable') {
        return NetworkError(error.message ?? 'Network unavailable.');
      }
      if (error.code == 'permission-denied' ||
          error.code == 'unauthenticated') {
        return PermissionError(error.message ?? 'Permission denied.');
      }
      if (error.code == 'resource-exhausted' ||
          error.code == 'daily-creation-limit') {
        return ValidationError(
          error.message ??
              'Daily game creation limit reached (2 games per day).',
        );
      }
      return ValidationError(error.message ?? 'Game command failed.');
    }
    return UnknownError(error.toString());
  }
}
