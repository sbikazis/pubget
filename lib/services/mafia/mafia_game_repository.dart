import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_paths.dart';
import '../../models/mafia/mafia_action_model.dart';
import '../../models/mafia/mafia_chat_message_model.dart';
import '../../models/mafia/mafia_event_model.dart';
import '../../models/mafia/mafia_game_model.dart';
import '../../models/mafia/mafia_player_model.dart';
import '../../models/mafia/mafia_vote_model.dart';
import 'mafia_firestore_service.dart';

class MafiaGameRepository {
  final MafiaFirestoreService _firestoreService;
  final FirebaseFirestore _firestore;

  MafiaGameRepository({MafiaFirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? MafiaFirestoreService(),
        _firestore = FirebaseFirestore.instance;

  Future<void> createGame(MafiaGameModel game) async {
    await _firestoreService.createGame(game);
  }

  Future<void> createGameWithInitialPlayer(
    MafiaGameModel game,
    MafiaPlayerModel player,
  ) async {
    await _firestore.runTransaction((tx) async {
      final gameRef = _firestoreService.mafiaGameDoc(game.id);
      final playerRef = _firestoreService.mafiaGamePlayerDoc(game.id, player.id);
      final groupRef = _firestore.collection(FirestorePaths.groups).doc(game.groupId);

      final groupSnap = await tx.get(groupRef);
      if (!groupSnap.exists) {
        throw Exception('Group does not exist');
      }
      final groupData = groupSnap.data();
      if (groupData != null && groupData['hasRunningGame'] == true) {
        throw Exception('هناك مباراة جارية بالفعل في هذه المجموعة.');
      }

      tx.set(gameRef, game.toMap());
      tx.set(playerRef, player.toMap());
      tx.update(groupRef, {
        'activeGameId': game.id,
        'gameStatus': game.status.name,
        'hasRunningGame': true,
      });
    });
  }

  Future<void> updateGame(String gameId, Map<String, dynamic> data) async {
    await _firestoreService.updateGame(gameId, data);
  }

  Future<void> deleteGame(String gameId) async {
    await _firestoreService.deleteGame(gameId);
  }

  Stream<MafiaGameModel?> streamGame(String gameId) {
    return _firestoreService
        .streamGame(gameId)
        .map((snapshot) => snapshot.exists
            ? MafiaGameModel.fromMap(snapshot.id, snapshot.data()!)
            : null);
  }

  Stream<List<MafiaPlayerModel>> streamPlayers(String gameId) {
    return _firestoreService
        .streamPlayers(gameId)
        .map((snapshot) => snapshot.docs
            .map((doc) => MafiaPlayerModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<List<MafiaEventModel>> streamEvents(String gameId) {
    return _firestoreService
        .streamEvents(gameId)
        .map((snapshot) => snapshot.docs
            .map((doc) => MafiaEventModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<List<MafiaChatMessageModel>> streamChat(String gameId) {
    return _firestoreService
        .streamChat(gameId)
        .map((snapshot) => snapshot.docs
            .map((doc) => MafiaChatMessageModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> createPlayer(
    String gameId,
    MafiaPlayerModel player,
  ) async {
    await _firestore.runTransaction((tx) async {
      final gameRef = _firestoreService.mafiaGameDoc(gameId);
      final playerRef = _firestoreService.mafiaGamePlayerDoc(gameId, player.id);
      final gameSnapshot = await tx.get(gameRef);

      if (!gameSnapshot.exists) {
        throw Exception('Game does not exist');
      }

      final existingPlayer = await tx.get(playerRef);
      if (existingPlayer.exists) {
        return;
      }

      tx.set(playerRef, player.toMap());
      tx.update(gameRef, {'playersCount': FieldValue.increment(1)});
    });
  }

  Future<void> updatePlayer(
    String gameId,
    String playerId,
    Map<String, dynamic> data,
  ) async {
    await _firestoreService.updatePlayer(gameId, playerId, data);
  }

  Future<void> addNightAction(
    String gameId,
    MafiaActionModel action,
  ) async {
    await _firestoreService.createNightAction(gameId, action);
  }

  Future<void> addVote(
    String gameId,
    MafiaVoteModel vote,
  ) async {
    await _firestoreService.createVote(gameId, vote);
  }

  Future<void> addEvent(
    String gameId,
    MafiaEventModel event,
  ) async {
    await _firestoreService.createEvent(gameId, event);
  }

  Future<void> addChatMessage(
    String gameId,
    MafiaChatMessageModel message,
  ) async {
    await _firestoreService.createChatMessage(gameId, message);
  }

  Future<void> createHistory(String historyId, Map<String, dynamic> data) async {
    await _firestoreService.createHistory(historyId, data);
  }

  Future<void> updateGroupGameState(
    String groupId,
    String? activeGameId,
    String? gameStatus,
    bool hasRunningGame,
  ) async {
    await _firestore.collection(FirestorePaths.groups).doc(groupId).update({
      'activeGameId': activeGameId,
      'gameStatus': gameStatus,
      'hasRunningGame': hasRunningGame,
    });
  }
}
