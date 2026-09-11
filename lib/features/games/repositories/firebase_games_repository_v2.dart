import 'dart:async';

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
      _firestore.collection('games');

  @override
  Future<Result<GameSessionV2>> create({
    required String groupId,
    required GameTypeV2 type,
    required String requestId,
  }) => _guard(() async {
    final result = await _functions.httpsCallable('createGame').call({
      'groupId': groupId,
      'type': type.name,
      'title': _titleFor(type),
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
    final callable = switch (request.command) {
      'join' => 'joinGame',
      'leave' => 'leaveGame',
      'start' => 'startGame',
      'cancel' => 'cancelGame',
      _ => 'submitGameAction',
    };
    final data = switch (request.command) {
      'join' || 'leave' || 'start' || 'cancel' => {
        'gameId': request.gameId,
        'requestId': request.requestId,
        'expectedVersion': request.expectedVersion,
      },
      _ => {
        'gameId': request.gameId,
        'actionType': request.command,
        'payload': request.payload,
        'clientActionId': request.requestId,
        'expectedVersion': request.expectedVersion,
        'schemaVersion': gamesSchemaVersion,
      },
    };
    await _functions.httpsCallable(callable).call(data);
  });

  @override
  Stream<Result<GameSessionV2>> watchSession(String gameId) {
    final controller = StreamController<Result<GameSessionV2>>();
    Map<String, dynamic>? gameData;
    List<Map<String, dynamic>> players = const [];
    late StreamSubscription<Map<String, dynamic>> gameSub;
    late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> playerSub;
    void emit() {
      final data = gameData;
      if (data == null) return;
      final merged = <String, dynamic>{...data, 'players': players};
      try {
        controller.add(Success(GameSessionV2.fromMap(merged, id: gameId)));
      } catch (error) {
        controller.add(FailureResult(_failure(error)));
      }
    }
    gameSub = _games.doc(gameId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        throw const NotFoundError('This game session no longer exists.');
      }
      return snapshot.data()!;
    }).listen((data) {
      gameData = data;
      emit();
    }, onError: (Object error) {
      controller.add(FailureResult(_failure(error)));
    });
    playerSub = _games.doc(gameId).collection('participants').snapshots().listen(
      (snapshot) {
        players = snapshot.docs.map((doc) => <String, dynamic>{
          ...doc.data(),
          'userId': doc.id,
        }).toList(growable: false);
        emit();
      },
      onError: (Object error) {
        controller.add(FailureResult(_failure(error)));
      },
    );
    controller.onCancel = () async {
      await gameSub.cancel();
      await playerSub.cancel();
    };
    return controller.stream;
  }

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
    var query = _firestore
        .collection('game_history')
        .where('groupId', isEqualTo: groupId)
        .orderBy('endedAt', descending: true)
        .limit(limit.clamp(1, 50));
    if (cursor != null && cursor.isNotEmpty) {
      final anchor = await _firestore.collection('game_history').doc(cursor).get();
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

  String _titleFor(GameTypeV2 type) => switch (type) {
    GameTypeV2.guessCharacter => 'Guess Character',
    GameTypeV2.animeChain => 'Anime Chain',
    GameTypeV2.emojiAnimeGuess => 'Emoji Anime Guess',
  };

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
