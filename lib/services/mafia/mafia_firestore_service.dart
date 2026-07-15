// lib/services/mafia/mafia_firestore_service.dart
//
// ✅ الإضافة الوحيدة: streamVotes — بقية الملف كما هو من المرحلة 4.5
// دون أي تغيير.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_paths.dart';
import '../../models/mafia/mafia_action_model.dart';
import '../../models/mafia/mafia_chat_message_model.dart';
import '../../models/mafia/mafia_event_model.dart';
import '../../models/mafia/mafia_game_model.dart';
import '../../models/mafia/mafia_player_model.dart';
import '../../models/mafia/mafia_player_private_model.dart';
import '../../models/mafia/mafia_vote_model.dart';

class MafiaFirestoreService {
  final FirebaseFirestore _firestore;

  MafiaFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get mafiaGamesCollection =>
      _firestore.collection(FirestorePaths.mafiaGames());

  DocumentReference<Map<String, dynamic>> mafiaGameDoc(String gameId) =>
      mafiaGamesCollection.doc(gameId);

  CollectionReference<Map<String, dynamic>> mafiaGamePlayers(String gameId) =>
      mafiaGameDoc(gameId).collection('players');

  DocumentReference<Map<String, dynamic>> mafiaGamePlayerDoc(
          String gameId, String playerId) =>
      mafiaGamePlayers(gameId).doc(playerId);

  DocumentReference<Map<String, dynamic>> mafiaGamePlayerPrivateDoc(
          String gameId, String playerId) =>
      mafiaGamePlayerDoc(gameId, playerId).collection('private').doc('data');

  CollectionReference<Map<String, dynamic>> mafiaGameNightActions(
          String gameId) =>
      mafiaGameDoc(gameId).collection('night_actions');

  CollectionReference<Map<String, dynamic>> mafiaGameVotes(String gameId) =>
      mafiaGameDoc(gameId).collection('votes');

  CollectionReference<Map<String, dynamic>> mafiaGameEvents(String gameId) =>
      mafiaGameDoc(gameId).collection('events');

  CollectionReference<Map<String, dynamic>> mafiaGameChat(String gameId) =>
      mafiaGameDoc(gameId).collection('chat');

  CollectionReference<Map<String, dynamic>> mafiaHistoryCollection() =>
      _firestore.collection(FirestorePaths.mafiaHistory());

  CollectionReference<Map<String, dynamic>> userMafiaHistory(String userId) =>
      _firestore.collection(FirestorePaths.userMafiaHistory(userId));

  Future<void> createGame(MafiaGameModel game) async {
    await mafiaGamesCollection.doc(game.id).set(game.toMap());
  }

  Future<void> updateGame(String gameId, Map<String, dynamic> data) async {
    await mafiaGameDoc(gameId).update(data);
  }

  Future<void> deleteGame(String gameId) async {
    await mafiaGameDoc(gameId).delete();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamGame(String gameId) {
    return mafiaGameDoc(gameId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamPlayers(String gameId) {
    return mafiaGamePlayers(gameId).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamPlayerPrivate(
      String gameId, String playerId) {
    return mafiaGamePlayerPrivateDoc(gameId, playerId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamEvents(String gameId) {
    return mafiaGameEvents(gameId)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamChat(String gameId) {
    return mafiaGameChat(gameId)
        .orderBy('time', descending: false)
        .snapshots();
  }

  /// ✅ جديد: تدفّق حي لكل الأصوات — يُستخدم لعرض عدّاد تصويت حي
  /// في الواجهة (شفاف بطبيعته في لعبة المافيا التقليدية).
  Stream<QuerySnapshot<Map<String, dynamic>>> streamVotes(String gameId) {
    return mafiaGameVotes(gameId).snapshots();
  }

  Future<void> createPlayer(
    String gameId,
    MafiaPlayerModel player,
  ) async {
    await mafiaGamePlayerDoc(gameId, player.id).set(player.toMap());
  }

  Future<void> updatePlayer(
    String gameId,
    String playerId,
    Map<String, dynamic> data,
  ) async {
    await mafiaGamePlayerDoc(gameId, playerId).update(data);
  }

  Future<void> deletePlayer(String gameId, String playerId) async {
    await mafiaGamePlayerDoc(gameId, playerId).delete();
  }

  Future<void> createPlayerPrivate(
    String gameId,
    String playerId,
    MafiaPlayerPrivateModel data,
  ) async {
    await mafiaGamePlayerPrivateDoc(gameId, playerId).set(data.toMap());
  }

  Future<void> updatePlayerPrivate(
    String gameId,
    String playerId,
    Map<String, dynamic> data,
  ) async {
    await mafiaGamePlayerPrivateDoc(gameId, playerId).update(data);
  }

  Future<void> deletePlayerPrivate(String gameId, String playerId) async {
    await mafiaGamePlayerPrivateDoc(gameId, playerId).delete();
  }

  Future<void> createNightAction(
    String gameId,
    MafiaActionModel action,
  ) async {
    await mafiaGameNightActions(gameId).doc(action.id).set(action.toMap());
  }

  Future<void> updateNightAction(
    String gameId,
    String actionId,
    Map<String, dynamic> data,
  ) async {
    await mafiaGameNightActions(gameId).doc(actionId).update(data);
  }

  Future<void> createVote(
    String gameId,
    MafiaVoteModel vote,
  ) async {
    await mafiaGameVotes(gameId).doc(vote.id).set(vote.toMap());
  }

  Future<void> createEvent(
    String gameId,
    MafiaEventModel event,
  ) async {
    await mafiaGameEvents(gameId).doc(event.id).set(event.toMap());
  }

  Future<void> createChatMessage(
    String gameId,
    MafiaChatMessageModel message,
  ) async {
    await mafiaGameChat(gameId).doc(message.id).set(message.toMap());
  }

  Future<void> createHistory(
    String historyId,
    Map<String, dynamic> data,
  ) async {
    await mafiaHistoryCollection().doc(historyId).set(data);
  }
}