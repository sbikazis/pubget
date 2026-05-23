import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_model.dart';
import '../models/message_model.dart';
import '../services/firebase/firestore_service.dart';
import '../services/api/anime_api_service.dart';
import '../core/constants/firestore_paths.dart';
import '../core/constants/game_status.dart';
import '../core/logic/game_logic_validator.dart';
import '../core/utils/game_timer_manager.dart';
import '../core/utils/game_auto_judge.dart';
import 'package:flutter/foundation.dart';

class GameProvider extends ChangeNotifier {
  final FirestoreService _firestore;
  final Uuid _uuid = const Uuid();

  GameProvider({FirestoreService? firestore})
      : _firestore = firestore?? FirestoreService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<Map<String, String>?> createGame({
    required String groupId,
    required String creatorUserId,
    String? creatorName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
         .collection(FirestorePaths.groupGames(groupId))
         .get();

      final activeGames = snapshot.docs
         .map((doc) => GameModel.fromMap(doc.id, doc.data()))
         .where((g) =>!g.status.isOver && g.gameType == 'guess')
         .toList();

      if (!GameLogicValidator.canCreateNewGame(activeGames)) {
        throw Exception("المجموعة ممتلئة، هناك لعبتان قيد التنفيذ حالياً.");
      }

      String assignedSlot = activeGames.any((g) => g.gameSlot == 'game_1')
         ? 'game_2'
          : 'game_1';

      final gameId = _uuid.v4();
      final game = GameModel(
        id: gameId,
        groupId: groupId,
        gameSlot: assignedSlot,
        playerOneId: creatorUserId,
        gameType: 'guess',
        status: GameStatus.waitingForOpponent,
        createdAt: DateTime.now(),
        lastActionType: null,
      );

      await _firestore.createDocument(
        path: FirestorePaths.groupGames(groupId),
        docId: gameId,
        data: game.toMap(),
      );

      return {'gameId': gameId, 'gameSlot': assignedSlot};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ====== ألعاب سلسلة الأنمي الجديدة ======
  Future<String> startAnimeChain({
    required String groupId,
    required String creatorUserId,
    required String startWord,
  }) async {
    final gameId = _uuid.v4();
    final cleanStart = startWord.toLowerCase().trim();

    final game = GameModel(
      id: gameId,
      groupId: groupId,
      gameSlot: 'chain', // لا نستخدم slots هنا
      playerOneId: creatorUserId,
      gameType: 'anime_chain',
      currentWord: cleanStart,
      lastLetter: cleanStart.substring(cleanStart.length - 1),
      usedWords: [cleanStart],
      players: [creatorUserId],
      status: GameStatus.guessing,
      createdAt: DateTime.now(),
    );

    await _firestore.createDocument(
      path: FirestorePaths.groupGames(groupId),
      docId: gameId,
      data: game.toMap(),
    );

    // أرسل رسالة في الشات
    await _sendGameSystemMessage(
      groupId: groupId,
      gameId: gameId,
      action: 'chain_start',
      senderId: creatorUserId,
      senderName: 'النظام',
      gameSlot: 'chain',
      text: '🔗 بدأت سلسلة الأنمي! الكلمة الأولى: $startWord',
    );

    return gameId;
  }

  Future<bool> submitChainWord({
    required String groupId,
    required String gameId,
    required String word,
    required String userId,
    String? userName,
  }) async {
    final ref = FirebaseFirestore.instance
       .collection(FirestorePaths.groupGames(groupId))
       .doc(gameId);

    return FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;

      final game = GameModel.fromMap(gameId, snap.data()!);
      final cleanWord = word.toLowerCase().trim();

      if (cleanWord.isEmpty) return false;
      if (game.lastLetter == null) return false;

      final firstLetter = cleanWord[0];
      if (firstLetter!= game.lastLetter) return false;
      if (game.usedWords.contains(cleanWord)) return false;

      // أضف اللاعب للقائمة إذا جديد
      final updatedPlayers = List<String>.from(game.players);
      if (!updatedPlayers.contains(userId)) {
        updatedPlayers.add(userId);
      }

      tx.update(ref, {
        'currentWord': cleanWord,
        'lastLetter': cleanWord.substring(cleanWord.length - 1),
        'usedWords': FieldValue.arrayUnion([cleanWord]),
        'players': updatedPlayers,
        'lastActionAt': FieldValue.serverTimestamp(),
        'currentTurnUserId': userId,
      });

      // أرسل للشات
      tx.set(
        FirebaseFirestore.instance
           .collection(FirestorePaths.groupMessages(groupId))
           .doc(_uuid.v4()),
        {
          'id': _uuid.v4(),
          'senderId': userId,
          'senderName': userName?? 'لاعب',
          'type': 'text',
          'text': '➡️ $word',
          'createdAt': FieldValue.serverTimestamp(),
          'gameId': gameId,
          'gameAction': 'chain_word',
          'gameSlot': 'chain',
        },
      );

      return true;
    });
  }

  // ====== باقي دوال التخمين (بدون تغيير) ======
  Future<String> joinGame({required String groupId, required String gameId, required String userId, String? userName}) async {
    final gameRef = FirebaseFirestore.instance.collection(FirestorePaths.groupGames(groupId)).doc(gameId);
    String gameSlot = 'game_1';
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(gameRef);
      if (!snapshot.exists) throw Exception("اللعبة لم تعد موجودة!");
      final game = GameModel.fromMap(gameId, snapshot.data()!);
      if (game.playerTwoId!= null && game.playerTwoId!= userId) {
        throw Exception("آسفون! قام شخص آخر بالانضمام لهذه اللعبة قبلك.");
      }
      if (game.status!= GameStatus.waitingForOpponent) {
        throw Exception("هذه اللعبة بدأت بالفعل أو لم تعد متاحة للانضمام.");
      }
      gameSlot = game.gameSlot;
      transaction.update(gameRef, {
        'playerTwoId': userId,
        'status': GameStatus.setup.name,
        'setupStartedAt': FieldValue.serverTimestamp(),
      });
    });
    return gameSlot;
  }

  Future<void> setCharacter({required String groupId, required String gameId, required String userId, required List<int> animeIds, required String characterName, String? validatedName, String? validatedImageUrl}) async {
    final charData = (validatedName!= null && validatedImageUrl!= null)
       ? {'name': validatedName, 'imageUrl': validatedImageUrl}
        : await AnimeApiService.getCharacterDetails(animeIds: animeIds, characterName: characterName);
    if (charData == null) throw Exception("هذه الشخصية غير موجودة. تأكد من كتابة الاسم الإنجليزي بدقة كما في MAL.");
    final gameRef = FirebaseFirestore.instance.collection(FirestorePaths.groupGames(groupId)).doc(gameId);
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(gameRef);
      final game = GameModel.fromMap(gameId, snapshot.data()!);
      if (game.setupStartedAt!= null && GameTimerManager.hasSetupTimeout(game.setupStartedAt!)) {
        throw Exception("انتهى الوقت المحدد للاختيار (60 ثانية)!");
      }
      Map<String, dynamic> updates = {};
      if (userId == game.playerOneId) {
        updates['playerOneCharacter'] = charData['name'];
        updates['playerOneImage'] = charData['imageUrl'];
      } else {
        updates['playerTwoCharacter'] = charData['name'];
        updates['playerTwoImage'] = charData['imageUrl'];
      }
      transaction.update(gameRef, updates);
    });
  }

  Future<void> toggleReady({required String groupId, required String gameId, required String userId}) async {
    final gameRef = FirebaseFirestore.instance.collection(FirestorePaths.groupGames(groupId)).doc(gameId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(gameRef);
      if (!snapshot.exists) throw Exception("اللعبة غير موجودة");
      final game = GameModel.fromMap(gameId, snapshot.data()!);
      final isP1 = userId == game.playerOneId;
      final hasCharacter = isP1? game.playerOneCharacter!= null : game.playerTwoCharacter!= null;
      if (!hasCharacter) throw Exception("يجب اختيار الشخصية أولاً");
      final updates = <String, dynamic>{isP1? 'isPlayerOneReady' : 'isPlayerTwoReady': true};
      final otherReady = isP1? game.isPlayerTwoReady : game.isPlayerOneReady;
      if (otherReady) {
        updates['status'] = GameStatus.guessing.name;
        updates['currentTurnUserId'] = game.playerOneId;
        updates['lastActionAt'] = FieldValue.serverTimestamp();
        updates['lastActionType'] = null;
      }
      transaction.update(gameRef, updates);
    });
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> guessCharacter({required String groupId, required String gameId, required String userId, required String guessedName, String? userName}) async {
    final gameRef = FirebaseFirestore.instance.collection(FirestorePaths.groupGames(groupId)).doc(gameId);
    final snapshot = await gameRef.get();
    final game = GameModel.fromMap(gameId, snapshot.data()!);
    final opponentChar = (userId == game.playerOneId)? game.playerTwoCharacter : game.playerOneCharacter;
    if (GameLogicValidator.isGuessCorrect(guessedName, opponentChar?? "")) {
      await _sendGameSystemMessage(groupId: groupId, gameId: gameId, action: 'guess', senderId: userId, senderName: userName?? "لاعب", gameSlot: game.gameSlot, text: "✅ ${userName?? 'لاعب'} خمّن '$guessedName' وهي صحيحة!");
      await finishGame(groupId, gameId, winnerId: userId, winnerName: userName, guessedCharacter: guessedName);
    } else {
      await _sendGameSystemMessage(groupId: groupId, gameId: gameId, action: 'guess', senderId: userId, senderName: userName?? "لاعب", gameSlot: game.gameSlot, text: "❌ ${userName?? 'لاعب'} خمن '$guessedName' وهي خاطئة!");
      await switchTurn(groupId, gameId);
    }
  }

  Future<void> switchTurn(String groupId, String gameId) async {
    final gameRef = FirebaseFirestore.instance.collection(FirestorePaths.groupGames(groupId)).doc(gameId);
    final snapshot = await gameRef.get();
    final game = GameModel.fromMap(gameId, snapshot.data()!);
    final nextTurnId = (game.currentTurnUserId == game.playerOneId)? game.playerTwoId : game.playerOneId;
    await gameRef.update({'currentTurnUserId': nextTurnId, 'lastActionAt': FieldValue.serverTimestamp()});
  }

  Future<void> updateLastAction(String groupId, String gameId, String? actionType) async {
    final gameRef = FirebaseFirestore.instance.collection(FirestorePaths.groupGames(groupId)).doc(gameId);
    await gameRef.update({'lastActionType': actionType, 'lastActionAt': FieldValue.serverTimestamp()});
  }

  Future<void> finishGame(String groupId, String gameId, {String? winnerId, String? winnerName, bool isCancelled = false, String? reason, String? guessedCharacter, String? loserName}) async {
    final gameRef = FirebaseFirestore.instance.collection(FirestorePaths.groupGames(groupId)).doc(gameId);
    final snapshot = await gameRef.get();
    if (!snapshot.exists) return;
    final game = GameModel.fromMap(gameId, snapshot.data()!);
    if (game.status.isOver) return;
    await gameRef.update({'status': isCancelled? GameStatus.cancelled.name : GameStatus.finished.name, 'winnerUserId': winnerId, 'finishedAt': FieldValue.serverTimestamp(), 'endReason': reason});
    String resolvedLoserName = loserName?? "الخصم";
    if (loserName == null) {
      final loserId = winnerId == game.playerOneId? game.playerTwoId : game.playerOneId;
      if (loserId!= null) {
        try {
          final loserDoc = await FirebaseFirestore.instance.collection('users').doc(loserId).get();
          resolvedLoserName = loserDoc.data()?['username']?? "الخصم";
        } catch (_) { resolvedLoserName = "الخصم"; }
      }
    }
    String finalText;
    if (isCancelled) {
      finalText = "🏳️ انتهت اللعبة!\nالفائز: ${winnerName?? '—'}\nالخاسر: $resolvedLoserName\nالسبب: ${reason?? 'انسحاب'}";
    } else if (guessedCharacter!= null) {
      finalText = "🏆 انتهت اللعبة!\nالفائز: ${winnerName?? 'لاعب'}\nالخاسر: $resolvedLoserName\nالسبب: خمّن الشخصية '$guessedCharacter' بشكل صحيح";
    } else {
      finalText = "⏰ انتهت اللعبة!\nالفائز: ${winnerName?? '—'}\nالخاسر: $resolvedLoserName\nالسبب: ${reason?? 'انتهى الوقت'}";
    }
    await _sendGameSystemMessage(groupId: groupId, gameId: gameId, action: isCancelled? 'quit' : 'win', senderId: winnerId?? "", senderName: winnerName?? "النظام", gameSlot: game.gameSlot, text: finalText);
  }

  Future<void> _sendGameSystemMessage({required String groupId, required String gameId, required String action, required String senderId, required String senderName, required String gameSlot, String? text}) async {
    final messageId = _uuid.v4();
    final messageData = {'id': messageId, 'senderId': senderId, 'senderName': senderName, 'type': 'text', 'text': text?? '', 'createdAt': FieldValue.serverTimestamp(), 'gameId': gameId, 'gameAction': action, 'gameSlot': gameSlot};
    await FirebaseFirestore.instance.collection(FirestorePaths.groupMessages(groupId)).doc(messageId).set(messageData);
  }

  Stream<List<GameModel>> streamActiveGames(String groupId) {
    return FirebaseFirestore.instance.collection(FirestorePaths.groupGames(groupId)).where('status', whereIn: [GameStatus.waitingForOpponent.name, GameStatus.setup.name, GameStatus.guessing.name]).snapshots().map((snapshot) => snapshot.docs.map((doc) => GameModel.fromMap(doc.id, doc.data())).toList());
  }

  Stream<GameModel?> streamCurrentGame(String groupId, String gameId) {
    return _firestore.streamDocument(path: FirestorePaths.groupGames(groupId), docId: gameId).map((snap) => snap.exists? GameModel.fromMap(snap.id, snap.data()!) : null);
  }

  Future<void> processAutoJudge(String groupId, GameModel game) async {
    final timeoutType = GameAutoJudge.checkTimeout(game);
    if (timeoutType == TimeoutType.none) return;
    String? timedOutPlayerId = GameAutoJudge.getTimedOutPlayerId(game);
    String reason = GameAutoJudge.getReasonMessage(timeoutType, timedOutPlayerId?? "مجهول");
    if (timeoutType == TimeoutType.totalGameTimeout) {
      await finishGame(groupId, game.id, isCancelled: false, reason: reason);
    } else {
      String? winnerId = (timedOutPlayerId == game.playerOneId)? game.playerTwoId : game.playerOneId;
      await finishGame(groupId, game.id, winnerId: winnerId, reason: reason);
    }
  }
}