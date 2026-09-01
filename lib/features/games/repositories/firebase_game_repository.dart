import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/game_errors.dart';
import '../models/game_models.dart';
import 'game_repository.dart';

final class FirebaseGameRepository implements GameRepository {
  FirebaseGameRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _games =>
      _firestore.collection('games');

  @override
  Future<Result<PubgetGame>> create(GameDraft draft) => _guard(() async {
    final result = await _functions
        .httpsCallable('createGame')
        .call(draft.toCallableMap());
    final data = Map<String, dynamic>.from(result.data as Map);
    final gameId = data['gameId'] as String;
    final snapshot = await _games.doc(gameId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw const GameException(GameErrorCode.notFound, 'Game not found.');
    }
    return PubgetGame.fromMap(snapshot.data()!, id: gameId);
  });

  @override
  Future<Result<void>> initialize(String gameId) =>
      _call('initializeGame', {'gameId': gameId});

  @override
  Future<Result<void>> join(String gameId) =>
      _call('joinGame', {'gameId': gameId});

  @override
  Future<Result<void>> leave(String gameId) =>
      _call('leaveGame', {'gameId': gameId});

  @override
  Future<Result<void>> start(String gameId) =>
      _call('startGame', {'gameId': gameId});

  @override
  Future<Result<void>> pause(String gameId) =>
      _call('pauseGame', {'gameId': gameId});

  @override
  Future<Result<void>> resume(String gameId) =>
      _call('resumeGame', {'gameId': gameId});

  @override
  Future<Result<void>> submitAction({
    required String gameId,
    required String actionType,
    Map<String, dynamic> payload = const <String, dynamic>{},
    String? clientActionId,
  }) => _call('submitGameAction', {
    'gameId': gameId,
    'actionType': actionType,
    'payload': payload,
    if (clientActionId != null) 'clientActionId': clientActionId,
  });

  @override
  Future<Result<void>> end(String gameId) =>
      _call('endGame', {'gameId': gameId});

  @override
  Future<Result<void>> cancel(String gameId) =>
      _call('cancelGame', {'gameId': gameId});

  @override
  Stream<Result<PubgetGame>> watchGame(String gameId) {
    return _games
        .doc(gameId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) {
            return const FailureResult<PubgetGame>(
              NotFoundError('This game no longer exists.'),
            );
          }
          return Success(
            PubgetGame.fromMap(snapshot.data()!, id: snapshot.id),
          );
        })
        .handleError(
          (Object error) => FailureResult<PubgetGame>(_gameFailure(error)),
        );
  }

  @override
  Stream<Result<List<GameParticipant>>> watchParticipants(String gameId) {
    return _games
        .doc(gameId)
        .collection('participants')
        .snapshots()
        .map((snapshot) {
          final people = snapshot.docs
              .map(
                (doc) => GameParticipant.fromMap(doc.data(), userId: doc.id),
              )
              .toList(growable: false);
          return Success(people);
        })
        .handleError(
          (Object error) =>
              FailureResult<List<GameParticipant>>(_gameFailure(error)),
        );
  }

  @override
  Future<Result<List<PubgetGame>>> getActiveGames({int limit = 20}) => _query(
    _games
        .where('status', isEqualTo: 'active')
        .orderBy('updatedAt', descending: true)
        .limit(limit),
  );

  @override
  Future<Result<List<PubgetGame>>> getWaitingGames({int limit = 20}) => _query(
    _games
        .where('status', isEqualTo: 'waiting')
        .orderBy('updatedAt', descending: true)
        .limit(limit),
  );

  @override
  Future<Result<List<PubgetGame>>> getGroupGames({
    required String groupId,
    int limit = 20,
  }) => _query(
    _games
        .where('groupId', isEqualTo: groupId)
        .where(
          'status',
          whereIn: <String>['waiting', 'active', 'paused', 'completed'],
        )
        .orderBy('updatedAt', descending: true)
        .limit(limit),
  );

  @override
  Future<Result<List<PubgetGame>>> getMyGames({
    required String userId,
    int limit = 20,
  }) => _query(
    _games
        .where('creatorId', isEqualTo: userId)
        .where('status', isNotEqualTo: 'draft')
        .orderBy('status')
        .orderBy('updatedAt', descending: true)
        .limit(limit),
  );

  @override
  Future<Result<List<GameParticipant>>> getParticipants(String gameId) =>
      _guard(() async {
        final snapshot = await _games
            .doc(gameId)
            .collection('participants')
            .get();
        return snapshot.docs
            .map((doc) => GameParticipant.fromMap(doc.data(), userId: doc.id))
            .toList(growable: false);
      });

  Future<Result<List<PubgetGame>>> _query(Query<Map<String, dynamic>> query) =>
      _guard(() async {
        final snapshot = await query.get();
        return snapshot.docs
            .map((doc) => PubgetGame.fromMap(doc.data(), id: doc.id))
            .toList(growable: false);
      });

  Future<Result<void>> _call(String name, Map<String, dynamic> data) =>
      _guard(() async {
        await _functions.httpsCallable(name).call(data);
      });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success<T>(await action());
    } on GameException catch (error) {
      return FailureResult<T>(error.toFailure());
    } on Object catch (error) {
      return FailureResult<T>(_gameFailure(error));
    }
  }
}

Failure _gameFailure(Object error) {
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
        error.message ?? 'That game action was already submitted.',
      ),
      _ => ValidationError(error.message ?? 'This game action failed.'),
    };
  }
  if (error is FirebaseException &&
      (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
    return const NetworkError('Check your connection and try again.');
  }
  return UnknownError(error.toString());
}
