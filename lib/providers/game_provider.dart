import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/game_model.dart';
import '../services/firebase/firestore_service.dart';
import '../services/api/anime_api_service.dart';
import '../core/constants/firestore_paths.dart';
import '../core/constants/game_status.dart';

class GameProvider extends ChangeNotifier {
  final FirestoreService _firestore;

  GameProvider({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  final Uuid _uuid = const Uuid();

  GameModel? _currentGame;
  GameModel? get currentGame => _currentGame;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ===============================
  // CREATE GAME
  // ===============================

  Future<String> createGame({
    required String groupId,
    required String creatorUserId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final gameId = _uuid.v4();

      final game = GameModel(
        id: gameId,
        groupId: groupId,
        playerOneId: creatorUserId,
        playerTwoId: null,
        playerOneCharacter: null,
        playerTwoCharacter: null,
        currentTurnUserId: null,
        status: GameStatus.waiting,
        winnerUserId: null,
        createdAt: DateTime.now(),
        finishedAt: null,
      );

      await _firestore.createDocument(
        path: FirestorePaths.groupGames(groupId),
        docId: gameId,
        data: game.toMap(),
      );

      _currentGame = game;

      return gameId;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===============================
  // JOIN GAME
  // ===============================

  Future<void> joinGame({
    required String groupId,
    required String gameId,
    required String userId,
  }) async {
    final data = await _firestore.getDocument(
      path: FirestorePaths.groupGames(groupId),
      docId: gameId,
    );

    if (data == null) {
      throw Exception("Game not found");
    }

    final game = GameModel.fromMap(gameId, data);

    if (!game.status.canAcceptOpponent) {
      throw Exception("Game already started");
    }

    if (game.playerTwoId != null) {
      throw Exception("Game already has two players");
    }

    await _firestore.updateDocument(
      path: FirestorePaths.groupGames(groupId),
      docId: gameId,
      data: {
        'playerTwoId': userId,
      },
    );
  }

  // ===============================
  // SET CHARACTER
  // ===============================

  Future<void> setCharacter({
    required String groupId,
    required String gameId,
    required String userId,
    required String animeName,
    required String characterName,
  }) async {
    final valid = await AnimeApiService.validateCharacterExists(
      animeName: animeName,
      characterName: characterName,
    );

    if (!valid) {
      throw Exception("Character not valid for this anime");
    }

    final data = await _firestore.getDocument(
      path: FirestorePaths.groupGames(groupId),
      docId: gameId,
    );

    if (data == null) {
      throw Exception("Game not found");
    }

    final game = GameModel.fromMap(gameId, data);

    Map<String, dynamic> update = {};

    if (userId == game.playerOneId) {
      update['playerOneCharacter'] = characterName;
    } else if (userId == game.playerTwoId) {
      update['playerTwoCharacter'] = characterName;
    }

    await _firestore.updateDocument(
      path: FirestorePaths.groupGames(groupId),
      docId: gameId,
      data: update,
    );

    final refreshed = await _firestore.getDocument(
      path: FirestorePaths.groupGames(groupId),
      docId: gameId,
    );

    if (refreshed == null) return;

    final updatedGame = GameModel.fromMap(gameId, refreshed);

    if (updatedGame.playerOneCharacter != null &&
        updatedGame.playerTwoCharacter != null &&
        updatedGame.status == GameStatus.waiting) {
      await startGame(groupId: groupId, gameId: gameId);
    }
  }

  // ===============================
  // START GAME
  // ===============================

  Future<void> startGame({
    required String groupId,
    required String gameId,
  }) async {
    final data = await _firestore.getDocument(
      path: FirestorePaths.groupGames(groupId),
      docId: gameId,
    );

    if (data == null) return;

    final game = GameModel.fromMap(gameId, data);

    await _firestore.updateDocument(
      path: FirestorePaths.groupGames(groupId),
      docId: gameId,
      data: {
        'status': GameStatus.active.name,
        'currentTurnUserId': game.playerOneId,
      },
    );
  }

  // ===============================
  // SWITCH TURN
  // ===============================

  Future<void> switchTurn({
    required String groupId,
    required String gameId,
  }) async {
    final data = await _firestore.getDocument(
      path: FirestorePaths.groupGames(groupId),
      docId: gameId,
    );

    if (data == null) return;

    final game = GameModel.fromMap(gameId, data);

    final nextTurn =
        game.currentTurnUserId == game.playerOneId
            ? game.playerTwoId
            : game.playerOneId;

    await _firestore.updateDocument(
      path: FirestorePaths.groupGames(groupId),
      docId: gameId,
      data: {
        'currentTurnUserId': nextTurn,
      },
    );
  }

  // ===============================
  // GUESS CHARACTER
  // ===============================

  Future<void> guessCharacter({
    required String groupId,
    required String gameId,
    required String userId,
    required String guessedCharacter,
  }) async {
    final data = await _firestore.getDocument(
      path: FirestorePaths.groupGames(groupId),
      docId: gameId,
    );

    if (data == null) return;

    final game = GameModel.fromMap(gameId, data);

    if (!game.status.isActive) {
      throw Exception("Game not active");
    }

    final opponentCharacter =
        userId == game.playerOneId
            ? game.playerTwoCharacter
            : game.playerOneCharacter;

    if (opponentCharacter == null) return;

    if (guessedCharacter.toLowerCase() ==
        opponentCharacter.toLowerCase()) {
      await declareWinner(
        groupId: groupId,
        gameId: gameId,
        winnerUserId: userId,
      );
    } else {
      await switchTurn(
        groupId: groupId,
        gameId: gameId,
      );
    }
  }

  // ===============================
  // DECLARE WINNER
  // ===============================

  Future<void> declareWinner({
    required String groupId,
    required String gameId,
    required String winnerUserId,
  }) async {
    await _firestore.updateDocument(
      path: FirestorePaths.groupGames(groupId),
      docId: gameId,
      data: {
        'status': GameStatus.finished.name,
        'winnerUserId': winnerUserId,
        'finishedAt': DateTime.now(),
      },
    );
  }

  // ===============================
  // CANCEL GAME
  // ===============================

  Future<void> cancelGame({
    required String groupId,
    required String gameId,
  }) async {
    await _firestore.updateDocument(
      path: FirestorePaths.groupGames(groupId),
      docId: gameId,
      data: {
        'status': GameStatus.cancelled.name,
        'finishedAt': DateTime.now(),
      },
    );
  }

  // ===============================
  // STREAM GAME
  // ===============================

  Stream<GameModel?> streamGame({
    required String groupId,
    required String gameId,
  }) {
    return _firestore
        .streamDocument(
          path: FirestorePaths.groupGames(groupId),
          docId: gameId,
        )
        .map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;

      return GameModel.fromMap(snapshot.id, data);
    });
  }

  // ===============================
  // STREAM GROUP GAMES
  // ===============================

  Stream<List<GameModel>> streamGroupGames({
    required String groupId,
  }) {
    return _firestore
        .streamCollection(
          path: FirestorePaths.groupGames(groupId),
        )
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              GameModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }
}