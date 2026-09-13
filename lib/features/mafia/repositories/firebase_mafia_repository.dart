import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/mafia_models.dart';
import 'mafia_repository.dart';

final class FirebaseMafiaRepository implements MafiaRepository {
  FirebaseMafiaRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _games =>
      _firestore.collection('mafia_games');

  @override
  Future<Result<String>> create({
    required String groupId,
    int minPlayers = 4,
    int maxPlayers = 8,
  }) => _guard(() async {
    final result = await _functions.httpsCallable('createMafiaGame').call({
      'groupId': groupId,
      'minPlayers': minPlayers,
      'maxPlayers': maxPlayers,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['gameId'] as String;
  });

  @override
  Future<Result<void>> join(String gameId) =>
      _call('joinMafiaGame', {'gameId': gameId});

  @override
  Future<Result<void>> start(String gameId) =>
      _call('startMafiaGame', {'gameId': gameId});

  @override
  Future<Result<void>> leave(String gameId) =>
      _call('leaveMafiaGame', {'gameId': gameId});

  @override
  Future<Result<void>> submitNightAction({
    required String gameId,
    required String targetId,
    required int nightNumber,
    String? actionId,
  }) => _call('submitMafiaAction', {
    'gameId': gameId,
    'type': 'night_action',
    'targetId': targetId,
    'actionId': actionId ?? '${DateTime.now().microsecondsSinceEpoch}-night-$targetId',
  });

  @override
  Future<Result<void>> submitVote({
    required String gameId,
    required String targetId,
    required int dayNumber,
    String? actionId,
  }) => _call('submitMafiaAction', {
    'gameId': gameId,
    'type': 'vote',
    'targetId': targetId,
    'actionId': actionId ?? '${DateTime.now().microsecondsSinceEpoch}-vote-$targetId',
  });

  @override
  Future<Result<void>> endTurn(String gameId, {String? actionId}) =>
      _call('submitMafiaAction', {
        'gameId': gameId,
        'type': 'end_turn',
        'actionId': actionId ?? '${DateTime.now().microsecondsSinceEpoch}-turn',
      });

  @override
  Future<Result<void>> submitLastWords(
    String gameId,
    String text, {
    String? actionId,
  }) => _call('submitMafiaAction', {
    'gameId': gameId,
    'type': 'last_words',
    'text': text.trim(),
    'actionId': actionId ?? '${DateTime.now().microsecondsSinceEpoch}-last-words',
  });

  @override
  Future<Result<void>> sendMafiaMessage(
    String gameId,
    String text, {
    String? actionId,
  }) => _call('submitMafiaAction', {
    'gameId': gameId,
    'type': 'mafia_message',
    'text': text.trim(),
    'actionId': actionId ?? '${DateTime.now().microsecondsSinceEpoch}-mafia-chat',
  });

  @override
  Future<Result<void>> sendChat({
    required String gameId,
    required String text,
    required MafiaPlayer self,
  }) => _call('sendMafiaChat', {'gameId': gameId, 'text': text.trim()});

  @override
  Future<Result<void>> heartbeat(String gameId) =>
      _call('heartbeatMafia', {'gameId': gameId});

  @override
  Stream<Result<MafiaGame>> watchGame(String gameId) {
    return _games
        .doc(gameId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) {
            return const FailureResult<MafiaGame>(
              NotFoundError('This Mafia game no longer exists.'),
            );
          }
          return Success(MafiaGame.fromMap(snapshot.data()!, id: snapshot.id));
        })
        .handleError(
          (Object error) => FailureResult<MafiaGame>(_fail(error)),
        );
  }

  @override
  Stream<Result<List<MafiaPlayer>>> watchPlayers(String gameId) {
    return _games
        .doc(gameId)
        .collection('players')
        .snapshots()
        .map((snapshot) {
          return Success(
            snapshot.docs
                .map((doc) => MafiaPlayer.fromMap(doc.data(), id: doc.id))
                .toList(growable: false),
          );
        })
        .handleError(
          (Object error) => FailureResult<List<MafiaPlayer>>(_fail(error)),
        );
  }

  @override
  Stream<Result<MafiaPrivateState>> watchPrivate({
    required String gameId,
    required String userId,
  }) {
    return _games
        .doc(gameId)
        .collection('players')
        .doc(userId)
        .collection('private')
        .doc('data')
        .snapshots()
        .map((snapshot) {
          return Success(MafiaPrivateState.fromMap(snapshot.data()));
        })
        .handleError(
          (Object error) => FailureResult<MafiaPrivateState>(_fail(error)),
        );
  }

  @override
  Stream<Result<List<Map<String, dynamic>>>> watchEvents(String gameId) {
    return _games
        .doc(gameId)
        .collection('events')
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map((snapshot) {
          return Success(
            snapshot.docs.map((doc) => doc.data()).toList(growable: false),
          );
        })
        .handleError(
          (Object error) =>
              FailureResult<List<Map<String, dynamic>>>(_fail(error)),
        );
  }

  @override
  Stream<Result<List<Map<String, dynamic>>>> watchChat(String gameId) {
    return _games
        .doc(gameId)
        .collection('chat')
        .orderBy('time')
        .limit(80)
        .snapshots()
        .map((snapshot) {
          return Success(
            snapshot.docs.map((doc) => doc.data()).toList(growable: false),
          );
        })
        .handleError(
          (Object error) =>
              FailureResult<List<Map<String, dynamic>>>(_fail(error)),
        );
  }

  @override
  Stream<Result<List<Map<String, dynamic>>>> watchMafiaMessages(String gameId) {
    return _games
        .doc(gameId)
        .collection('mafia_messages')
        .orderBy('createdAt')
        .limit(80)
        .snapshots()
        .map((snapshot) => Success(
              snapshot.docs.map((doc) => doc.data()).toList(growable: false),
            ))
        .handleError(
          (Object error) =>
              FailureResult<List<Map<String, dynamic>>>(_fail(error)),
        );
  }

  Future<Result<void>> _call(String name, Map<String, dynamic> data) =>
      _guard(() async {
        await _functions.httpsCallable(name).call(data);
      });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success<T>(await action());
    } on Object catch (error) {
      return FailureResult<T>(_fail(error));
    }
  }
}

Failure _fail(Object error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' || 'permission-denied' => PermissionError(
        error.message ?? "You don't have permission.",
      ),
      'not-found' => NotFoundError(error.message ?? 'Mafia game not found.'),
      'unavailable' => NetworkError(
        error.message ?? 'Check your connection and try again.',
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
