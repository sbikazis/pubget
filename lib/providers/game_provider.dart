import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_model.dart';
import '../models/message_model.dart'; // ✅ مضاف للتعامل مع الرسائل
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
      : _firestore = firestore ?? FirestoreService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // =============================================================
  // 🛡️ إنشاء لعبة جديدة (تم تحديث منطق الحماية)
  // =============================================================
  Future<String?> createGame({
    required String groupId,
    required String creatorUserId,
    String? creatorName, // ✅ مضاف لتسجيل الاسم في الرسالة
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // ✅ التحقق من عدد الألعاب النشطة الفعلي
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestorePaths.groupGames(groupId))
          .get();
      
      final now = DateTime.now();
      final activeGames = snapshot.docs
          .map((doc) => GameModel.fromMap(doc.id, doc.data()))
          .where((g) {
            if (g.status.isOver) return false;
            // 🛡️ حماية: إذا كانت اللعبة في وضع الانتظار لأكثر من 5 دقائق، نعتبرها "ميتة" ولا تحسب من الحد
            if (g.status == GameStatus.waitingForOpponent) {
              return now.difference(g.createdAt).inMinutes < 5;
            }
            return true;
          })
          .toList();

      if (!GameLogicValidator.canCreateNewGame(activeGames)) {
        throw Exception("المجموعة ممتلئة، هناك لعبتان نشطتان حالياً.");
      }

      // ✅ تحديد الـ Slot المتاح (1 أو 2)
      String assignedSlot = activeGames.any((g) => g.gameSlot == 'game_1') 
          ? 'game_2' 
          : 'game_1';

      final gameId = _uuid.v4();
      final game = GameModel(
        id: gameId,
        groupId: groupId,
        gameSlot: assignedSlot,
        playerOneId: creatorUserId,
        status: GameStatus.waitingForOpponent,
        createdAt: DateTime.now(),
        lastActionType: null, // ابدأ بدون نوع
      );

      // إنشاء مستند اللعبة
      await _firestore.createDocument(
        path: FirestorePaths.groupGames(groupId),
        docId: gameId,
        data: game.toMap(),
      );

      return gameId;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =============================================================
  // 🛡️ الانضمام للعبة (مع حماية Race Condition صلبة)
  // =============================================================
  Future<String> joinGame({
    required String groupId,
    required String gameId,
    required String userId,
    String? userName,
  }) async {
    final gameRef = FirebaseFirestore.instance
        .collection(FirestorePaths.groupGames(groupId))
        .doc(gameId);

    String gameSlot = 'game_1';

    // ✅ Transaction تضمن قفل المستند أثناء التحقق لمنع دخول لاعبين معاً
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(gameRef);
      if (!snapshot.exists) throw Exception("اللعبة لم تعد موجودة!");

      final game = GameModel.fromMap(gameId, snapshot.data()!);

      // 🛡️ التحقق من أن المكان لا يزال متاحاً
      if (game.playerTwoId != null && game.playerTwoId != userId) {
        throw Exception("آسفون! قام شخص آخر بالانضمام لهذه اللعبة قبلك.");
      }
      
      if (game.status != GameStatus.waitingForOpponent) {
        throw Exception("هذه اللعبة بدأت بالفعل أو لم تعد متاحة.");
      }

      gameSlot = game.gameSlot;

      // ✅ تحديث فوري داخل الـ Transaction لضمان الحجز القطعي
      transaction.update(gameRef, {
        'playerTwoId': userId,
        'status': GameStatus.setup.name, // الانتقال لمرحلة التجهيز
        'setupStartedAt': FieldValue.serverTimestamp(),
      });
    });

    return gameSlot;
  }

  // =============================================================
  // 🛡️ اختيار الشخصية
  // =============================================================
  Future<void> setCharacter({
    required String groupId,
    required String gameId,
    required String userId,
    required List<int> animeIds,
    required String characterName,
    String? validatedName,
    String? validatedImageUrl,
  }) async {
    final charData = (validatedName != null && validatedImageUrl != null)
        ? {'name': validatedName, 'imageUrl': validatedImageUrl}
        : await AnimeApiService.getCharacterDetails(
            animeIds: animeIds,
            characterName: characterName,
          );

    if (charData == null) {
      throw Exception("هذه الشخصية غير موجودة في MAL.");
    }

    final gameRef = FirebaseFirestore.instance
        .collection(FirestorePaths.groupGames(groupId))
        .doc(gameId);

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(gameRef);
      final game = GameModel.fromMap(gameId, snapshot.data()!);

      if (game.setupStartedAt != null && 
          GameTimerManager.hasSetupTimeout(game.setupStartedAt!)) {
        throw Exception("انتهى الوقت المحدد للاختيار!");
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

  // =============================================================
  // 🛡️ نظام الجاهزية
  // =============================================================
  Future<void> toggleReady({
    required String groupId,
    required String gameId,
    required String userId,
  }) async {
    final gameRef = FirebaseFirestore.instance
        .collection(FirestorePaths.groupGames(groupId))
        .doc(gameId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(gameRef);
      if (!snapshot.exists) throw Exception("اللعبة غير موجودة");
      
      final game = GameModel.fromMap(gameId, snapshot.data()!);
      final isP1 = userId == game.playerOneId;
      
      final hasCharacter = isP1 
          ? game.playerOneCharacter != null 
          : game.playerTwoCharacter != null;
      
      if (!hasCharacter) {
        throw Exception("يجب اختيار الشخصية أولاً");
      }

      final updates = <String, dynamic>{
        isP1 ? 'isPlayerOneReady' : 'isPlayerTwoReady': true,
      };

      final otherReady = isP1 ? game.isPlayerTwoReady : game.isPlayerOneReady;
      
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

  // =============================================================
  // 🛡️ منطق التخمين
  // =============================================================
  Future<void> guessCharacter({
    required String groupId,
    required String gameId,
    required String userId,
    required String guessedName,
    String? userName,
  }) async {
    final gameRef = FirebaseFirestore.instance
        .collection(FirestorePaths.groupGames(groupId))
        .doc(gameId);

    final snapshot = await gameRef.get();
    final game = GameModel.fromMap(gameId, snapshot.data()!);

    final opponentChar = (userId == game.playerOneId) 
        ? game.playerTwoCharacter 
        : game.playerOneCharacter;

    if (GameLogicValidator.isGuessCorrect(guessedName, opponentChar ?? "")) {
      // ✅ فوز: إرسال تفاصيل التخمين الصحيح
      await _sendGameSystemMessage(
        groupId: groupId,
        gameId: gameId,
        action: 'guess',
        senderId: userId,
        senderName: userName ?? "لاعب",
        gameSlot: game.gameSlot,
        text: "✅ ${userName ?? 'لاعب'} خمّن '$guessedName' وهي صحيحة!",
      );
      await finishGame(groupId, gameId, 
        winnerId: userId, 
        winnerName: userName,
        guessedCharacter: guessedName
      );
    } else {
      // ❌ خطأ: إرسال تفاصيل التخمين الخاطئ
      await _sendGameSystemMessage(
        groupId: groupId,
        gameId: gameId,
        action: 'guess',
        senderId: userId,
        senderName: userName ?? "لاعب",
        gameSlot: game.gameSlot,
        text: "❌ ${userName ?? 'لاعب'} خمن '$guessedName' وهي خاطئة!",
      );
      await switchTurn(groupId, gameId);
    }
  }

  // =============================================================
  // 🛡️ تبادل الأدوار وتحديث الحركة
  // =============================================================
  Future<void> switchTurn(String groupId, String gameId) async {
    final gameRef = FirebaseFirestore.instance
        .collection(FirestorePaths.groupGames(groupId))
        .doc(gameId);

    final snapshot = await gameRef.get();
    final game = GameModel.fromMap(gameId, snapshot.data()!);

    final nextTurnId = (game.currentTurnUserId == game.playerOneId) 
        ? game.playerTwoId 
        : game.playerOneId;

    await gameRef.update({
      'currentTurnUserId': nextTurnId,
      'lastActionAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateLastAction(String groupId, String gameId, String? actionType) async {
    final gameRef = FirebaseFirestore.instance
        .collection(FirestorePaths.groupGames(groupId))
        .doc(gameId);

    await gameRef.update({
      'lastActionType': actionType,
      'lastActionAt': FieldValue.serverTimestamp(),
    });
  }

  // =============================================================
  // 🛡️ إنهاء اللعبة (تم تحديث منطق الرسائل الموجهة للـ Bubble)
  // =============================================================
  Future<void> finishGame(
    String groupId, 
    String gameId, {
    String? winnerId, 
    String? winnerName,
    bool isCancelled = false,
    String? reason,
    String? guessedCharacter,
  }) async {
    final gameRef = FirebaseFirestore.instance
        .collection(FirestorePaths.groupGames(groupId))
        .doc(gameId);

    final snapshot = await gameRef.get();
    if (!snapshot.exists) return;
    
    final game = GameModel.fromMap(gameId, snapshot.data()!);
    if (game.status.isOver) return;

    await gameRef.update({
      'status': isCancelled ? GameStatus.cancelled.name : GameStatus.finished.name,
      'winnerUserId': winnerId,
      'finishedAt': FieldValue.serverTimestamp(),
      'endReason': reason,
    });

    // ✅ بناء النص التفصيلي
    String loserName = (winnerId == game.playerOneId) 
        ? (game.playerTwoId ?? "الخصم") 
        : (game.playerOneId ?? "الخصم");

    String finalText;
    if (isCancelled) {
      finalText = "🏳️ انتهت اللعبة!\nالفائز: ${winnerName ?? '—'}\nالسبب: ${reason ?? 'انسحاب الخصم'}";
    } else if (guessedCharacter != null) {
      finalText = "🏆 فوز ساحق!\n${winnerName ?? 'لاعب'} كشف الشخصية: '$guessedCharacter'";
    } else {
      finalText = "⏰ انتهى التحدي!\nالفائز: ${winnerName ?? '—'}\nالسبب: ${reason ?? 'انتهى الوقت'}";
    }

    await _sendGameSystemMessage(
      groupId: groupId,
      gameId: gameId,
      action: isCancelled ? 'quit' : 'win',
      senderId: winnerId ?? "system",
      senderName: winnerName ?? "النظام",
      gameSlot: game.gameSlot,
      text: finalText,
    );
  }

  // =============================================================
  // 🛠️ إرسال رسائل النظام (مطابقة مع توقعات الـ Bubble)
  // =============================================================
  Future<void> _sendGameSystemMessage({
    required String groupId,
    required String gameId,
    required String action,
    required String senderId,
    required String senderName,
    required String gameSlot,
    String? text,
  }) async {
    final messageId = _uuid.v4();
    final messageData = {
      'id': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'type': 'text',
      'text': text ?? '', 
      'createdAt': FieldValue.serverTimestamp(), // ✅ استخدام المسمى الموحد
      'gameId': gameId,
      'gameAction': action,
      'gameSlot': gameSlot,
    };

    await FirebaseFirestore.instance
        .collection(FirestorePaths.groupMessages(groupId))
        .doc(messageId)
        .set(messageData);
  }

  // =============================================================
  // 🛰️ مراقبة وتحكيم
  // =============================================================
  Stream<List<GameModel>> streamActiveGames(String groupId) {
    return FirebaseFirestore.instance
        .collection(FirestorePaths.groupGames(groupId))
        .where('status', whereIn: [
          GameStatus.waitingForOpponent.name,
          GameStatus.setup.name,
          GameStatus.guessing.name,
        ])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GameModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<GameModel?> streamCurrentGame(String groupId, String gameId) {
    return _firestore.streamDocument(
      path: FirestorePaths.groupGames(groupId),
      docId: gameId,
    ).map((snap) => snap.exists ? GameModel.fromMap(snap.id, snap.data()!) : null);
  }

  Future<void> processAutoJudge(String groupId, GameModel game) async {
    final timeoutType = GameAutoJudge.checkTimeout(game);
    if (timeoutType == TimeoutType.none) return;

    String? timedOutPlayerId = GameAutoJudge.getTimedOutPlayerId(game);
    String reason = GameAutoJudge.getReasonMessage(timeoutType, timedOutPlayerId ?? "مجهول");

    if (timeoutType == TimeoutType.totalGameTimeout) {
      await finishGame(groupId, game.id, isCancelled: false, reason: reason);
    } else {
      String? winnerId = (timedOutPlayerId == game.playerOneId) ? game.playerTwoId : game.playerOneId;
      await finishGame(groupId, game.id, winnerId: winnerId, reason: reason);
    }
  }
}