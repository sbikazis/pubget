// lib/services/mafia/mafia_game_repository.dart
//
// ✅ الإصلاح الجوهري (الباغ القاتل):
// 1. leaveGame(): إذا كان اللاعب الخارج آخر لاعب متبقٍ في waiting
//    (العدد بعد الحذف = صفر)، يُحذف مستند اللعبة بالكامل وتُصفَّر
//    hasRunningGame/activeGameId على المجموعة فوراً من العميل نفسه —
//    بدل انتظار Cloud Function قد تتأخر دقيقة كاملة. هذا هو السبب
//    المباشر لرسالة "هناك مباراة جارية بالفعل" رغم الخروج اليدوي.
// 2. createGameWithInitialPlayer(): فحص دفاعي إضافي — إذا كان
//    hasRunningGame == true لكن activeGameId يشير لمباراة غير
//    موجودة أصلاً أو status == finished/cancelled فعلياً، يُسمح
//    بالإنشاء رغم ذلك (يُصلح تلقائياً أي حالة تضارب مشابهة مستقبلية
//    دون تدخل يدوي من المستخدم في Firestore Console).

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/constants/mafia_constants.dart';
import '../../models/mafia/mafia_action_model.dart';
import '../../models/mafia/mafia_chat_message_model.dart';
import '../../models/mafia/mafia_event_model.dart';
import '../../models/mafia/mafia_game_model.dart';
import '../../models/mafia/mafia_history_model.dart';
import '../../models/mafia/mafia_player_model.dart';
import '../../models/mafia/mafia_player_private_model.dart';
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
      final privateRef =
          _firestoreService.mafiaGamePlayerPrivateDoc(game.id, player.id);
      final groupRef = _firestore.collection(FirestorePaths.groups).doc(game.groupId);

      final groupSnap = await tx.get(groupRef);
      if (!groupSnap.exists) {
        throw Exception('Group does not exist');
      }
      final groupData = groupSnap.data();

      if (groupData != null && groupData['hasRunningGame'] == true) {
        // ✅ فحص دفاعي: تحقق فعلياً من حالة المباراة المُشار إليها
        // قبل رفض الإنشاء. لو كانت منتهية/ملغاة/غير موجودة أصلاً،
        // هذا يعني أن hasRunningGame بقيت عالقة بالخطأ (حالة قديمة
        // من قبل هذا الإصلاح، أو أي سيناريو حافة لم نغطه بعد) —
        // نسمح بالإنشاء بدل حبس المجموعة للأبد.
        final staleGameId = groupData['activeGameId'] as String?;
        bool isStale = false;

        if (staleGameId == null || staleGameId.isEmpty) {
          isStale = true;
        } else {
          final staleGameSnap = await tx.get(_firestoreService.mafiaGameDoc(staleGameId));
          if (!staleGameSnap.exists) {
            isStale = true;
          } else {
            final staleStatus = staleGameSnap.data()?['status'] as String?;
            if (staleStatus == MafiaGameStatus.finished.name ||
                staleStatus == MafiaGameStatus.cancelled.name) {
              isStale = true;
            }
          }
        }

        if (!isStale) {
          throw Exception('هناك مباراة جارية بالفعل في هذه المجموعة.');
        }
      }

      tx.set(gameRef, game.toMap());
      tx.set(playerRef, player.toMap());
      tx.set(
        privateRef,
        const MafiaPlayerPrivateModel(
          role: MafiaRoles.citizen,
          team: MafiaTeams.citizens,
        ).toMap(),
      );
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

  Stream<MafiaPlayerPrivateModel?> streamMyPrivateData(
      String gameId, String playerId) {
    return _firestoreService.streamPlayerPrivate(gameId, playerId).map(
        (snapshot) => snapshot.exists
            ? MafiaPlayerPrivateModel.fromMap(snapshot.data()!)
            : null);
  }

  Stream<List<MafiaVoteModel>> streamVotes(String gameId) {
    return _firestoreService
        .streamVotes(gameId)
        .map((snapshot) => snapshot.docs
            .map((doc) => MafiaVoteModel.fromMap(doc.id, doc.data()))
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

  Future<MafiaHistoryModel?> fetchGameHistory(String gameId) async {
    final doc = await _firestoreService.mafiaHistoryCollection().doc(gameId).get();
    if (!doc.exists) return null;
    return MafiaHistoryModel.fromMap(doc.id, doc.data()!);
  }

  Stream<List<Map<String, dynamic>>> streamUserHistory(String userId) {
    return _firestoreService
        .userMafiaHistory(userId)
        .orderBy('endedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
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

  Future<void> joinGame({
    required String gameId,
    required MafiaPlayerModel player,
  }) async {
    await _firestore.runTransaction((tx) async {
      final gameRef = _firestoreService.mafiaGameDoc(gameId);
      final playerRef = _firestoreService.mafiaGamePlayerDoc(gameId, player.id);
      final privateRef =
          _firestoreService.mafiaGamePlayerPrivateDoc(gameId, player.id);

      final gameSnap = await tx.get(gameRef);
      if (!gameSnap.exists) {
        throw Exception('اللعبة غير موجودة.');
      }
      final game = MafiaGameModel.fromMap(gameSnap.id, gameSnap.data()!);

      if (game.status != MafiaGameStatus.waiting) {
        throw Exception('انتهى وقت الانضمام لهذه المباراة.');
      }
      if (game.isLocked) {
        throw Exception('اكتمل عدد اللاعبين بالفعل.');
      }

      final existingPlayer = await tx.get(playerRef);
      if (existingPlayer.exists) {
        return;
      }

      final newCount = game.playersCount + 1;
      tx.set(playerRef, player.toMap());
      tx.set(
        privateRef,
        const MafiaPlayerPrivateModel(
          role: MafiaRoles.citizen,
          team: MafiaTeams.citizens,
        ).toMap(),
      );

      if (newCount >= game.maxPlayers) {
        tx.update(gameRef, {
          'playersCount': newCount,
          'isLocked': true,
          'status': MafiaGameStatus.starting.name,
          'currentPhase': MafiaGameStatus.starting.name,
          'countdownEndsAt': Timestamp.fromDate(
            DateTime.now()
                .add(const Duration(seconds: MafiaTimers.startingCountdownSeconds)),
          ),
        });
      } else {
        tx.update(gameRef, {'playersCount': newCount});
      }
    });
  }

  /// ✅ الإصلاح الجوهري: إذا كان الخارج آخر لاعب في waiting (العدد
  /// بعد الحذف = صفر)، نحذف اللعبة بالكامل ونحرّر المجموعة فوراً —
  /// من العميل نفسه، ضمن نفس الـ transaction، دون انتظار Cloud
  /// Function قد تتأخر حتى دقيقة كاملة (processExpiredLobbies).
  /// هذا هو السبب المباشر لعلوق "هناك مباراة جارية بالفعل".
  Future<void> leaveGame({
    required String gameId,
    required String playerId,
  }) async {
    await _firestore.runTransaction((tx) async {
      final gameRef = _firestoreService.mafiaGameDoc(gameId);
      final playerRef = _firestoreService.mafiaGamePlayerDoc(gameId, playerId);
      final privateRef =
          _firestoreService.mafiaGamePlayerPrivateDoc(gameId, playerId);

      final gameSnap = await tx.get(gameRef);
      if (!gameSnap.exists) return;
      final game = MafiaGameModel.fromMap(gameSnap.id, gameSnap.data()!);

      final playerSnap = await tx.get(playerRef);
      if (!playerSnap.exists) return;

      final notStarted = game.status == MafiaGameStatus.waiting ||
          game.status == MafiaGameStatus.starting;

      if (notStarted) {
        tx.delete(playerRef);
        tx.delete(privateRef);
        final newCount = (game.playersCount - 1).clamp(0, game.maxPlayers);
        final groupRef =
            _firestore.collection(FirestorePaths.groups).doc(game.groupId);

        if (newCount <= 0) {
          // ✅ آخر لاعب خرج قبل بدء المباراة فعلياً: احذف اللعبة
          // بالكامل وحرّر المجموعة فوراً، بدل تركها معلّقة بالحالة
          // waiting بعدد صفر — هذا هو الإصلاح الجوهري لهذه المرحلة.
          tx.delete(gameRef);
          tx.update(groupRef, {
            'activeGameId': FieldValue.delete(),
            'gameStatus': FieldValue.delete(),
            'hasRunningGame': false,
          });
        } else if (game.status == MafiaGameStatus.starting) {
          tx.update(gameRef, {
            'playersCount': newCount,
            'isLocked': false,
            'status': MafiaGameStatus.waiting.name,
            'currentPhase': MafiaGameStatus.waiting.name,
            'countdownEndsAt': Timestamp.fromDate(
              DateTime.now()
                  .add(const Duration(seconds: MafiaTimers.lobbyWaitSeconds)),
            ),
          });
        } else {
          tx.update(gameRef, {'playersCount': newCount});
        }
      } else {
        tx.update(playerRef, {
          'hasLeft': true,
          'isAlive': false,
          'canVote': false,
          'canSpeak': false,
          'canUseAbility': false,
        });
      }
    });
  }

  Future<void> updatePlayer(
    String gameId,
    String playerId,
    Map<String, dynamic> data,
  ) async {
    await _firestoreService.updatePlayer(gameId, playerId, data);
  }

  Future<void> sendHeartbeat({
    required String gameId,
    required String playerId,
  }) async {
    try {
      await _firestoreService.updatePlayer(gameId, playerId, {
        'lastSeenAt': FieldValue.serverTimestamp(),
        'isDisconnected': false,
      });
    } catch (_) {}
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
