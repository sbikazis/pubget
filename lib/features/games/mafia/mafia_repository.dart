import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/game_errors.dart';
import '../repositories/game_repository.dart';
import 'mafia_models.dart';

/// Mafia-specific reads sit beside [GameRepository] without duplicating
/// Firebase infrastructure. Mutations always go through callables.
class MafiaRepository {
  MafiaRepository({
    required GameRepository games,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _games = games,
        _db = firestore,
        _functions = functions;

  final GameRepository _games;
  final FirebaseFirestore? _db;
  final FirebaseFunctions? _functions;

  GameRepository get games => _games;

  Stream<Result<MafiaPrivateState?>> watchPrivateState({
    required String gameId,
    required String userId,
  }) {
    final db = _db;
    if (db == null) {
      return Stream<Result<MafiaPrivateState?>>.value(
        const Success<MafiaPrivateState?>(null),
      );
    }
    return db
        .collection('games')
        .doc(gameId)
        .collection('private')
        .doc(userId)
        .snapshots()
        .map((snap) {
          if (!snap.exists || snap.data() == null) {
            return const Success<MafiaPrivateState?>(null);
          }
          return Success<MafiaPrivateState?>(
            MafiaPrivateState.fromMap(Map<String, Object?>.from(snap.data()!)),
          );
        })
        .handleError(
          (Object error) => FailureResult<MafiaPrivateState?>(
            _failure(error),
          ),
        );
  }

  Future<Result<void>> submitMafiaAction({
    required String gameId,
    required String type,
    String? targetId,
    String? clientRequestId,
  }) {
    return _games.submitAction(
      gameId: gameId,
      actionType: type,
      payload: targetId == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'targetId': targetId},
      clientActionId: clientRequestId,
    );
  }

  Future<Result<void>> vote({
    required String gameId,
    required String targetId,
    String? clientRequestId,
  }) {
    return submitMafiaAction(
      gameId: gameId,
      type: 'mafia_vote',
      targetId: targetId,
      clientRequestId: clientRequestId,
    );
  }

  Future<Result<void>> advancePhase(String gameId) async {
    final functions = _functions ??
        FirebaseFunctions.instanceFor(region: 'us-central1');
    try {
      await functions.httpsCallable('advanceMafiaPhase').call(
        <String, dynamic>{'gameId': gameId},
      );
      return const Success<void>(null);
    } on Object catch (error) {
      return FailureResult(_failure(error));
    }
  }

  Failure _failure(Object error) {
    if (error is GameException) return error.toFailure();
    if (error is FirebaseFunctionsException) {
      return switch (error.code) {
        'unauthenticated' || 'permission-denied' => PermissionError(
          error.message ?? "You don't have permission.",
        ),
        'not-found' => NotFoundError(error.message ?? 'Game not found.'),
        'unavailable' || 'resource-exhausted' => NetworkError(
          error.message ?? 'Check your connection and try again.',
        ),
        'already-exists' => ValidationError(
          error.message ?? 'That action was already submitted.',
        ),
        _ => ValidationError(error.message ?? 'This Mafia action failed.'),
      };
    }
    if (error is FirebaseException &&
        (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
      return const NetworkError('Check your connection and try again.');
    }
    return UnknownError(error.toString());
  }
}
