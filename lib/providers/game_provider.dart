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
  // 🛡️ إنشاء لعبة جديدة
  // =============================================================
  Future<String?> createGame({
    required String groupId,
    required String creatorUserId,
    String? creatorName, // ✅ مضاف لتسجيل الاسم في الرسالة
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // ✅ التحقق من عدد الألعاب النشطة لمنع تجاوز لعبتين
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestorePaths.groupGames(groupId))
          .get();
      
      final activeGames = snapshot.docs
          .map((doc) => GameModel.fromMap(doc.id, doc.data()))
          .where((g) => !g.status.isOver)
          .toList();

      if (!GameLogicValidator.canCreateNewGame(activeGames)) {
        throw Exception("المجموعة ممتلئة، هناك لعبتان قيد التنفيذ حالياً.");
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

    // ✅ التعديل الجوهري: Transaction تضمن قفل المستند أثناء التحقق لمنع دخول لاعبين معاً
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(gameRef);
      if (!snapshot.exists) throw Exception("اللعبة لم تعد موجودة!");

      final game = GameModel.fromMap(gameId, snapshot.data()!);

      // 🛡️ التحقق المنطقي القاتل: هل تم حجز المكان بالفعل أثناء قراءتك للقواعد؟
      if (game.playerTwoId != null && game.playerTwoId != userId) {
        throw Exception("آسفون! قام شخص آخر بالانضمام لهذه اللعبة قبلك.");
      }
      
      // 🛡️ التأكد من أن الحالة لا تزال "انتظار خصم" حصراً
      if (game.status != GameStatus.waitingForOpponent) {
        throw Exception("هذه اللعبة بدأت بالفعل أو لم تعد متاحة للانضمام.");
      }

      gameSlot = game.gameSlot;

      // ✅ تحديث فوري داخل الـ Transaction لضمان الحجز القطعي
      transaction.update(gameRef, {
        'playerTwoId': userId,
        'status': GameStatus.setup.name, // نقله فوراً لمرحلة التجهيز
        'setupStartedAt': FieldValue.serverTimestamp(), // بدء عداد الـ 60 ثانية
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
  }) async {
    // جلب التفاصيل من API (يتم التحقق عالمياً أو محلياً داخل الخدمة)
    final charData = await AnimeApiService.getCharacterDetails(
      animeIds: animeIds,
      characterName: characterName,
    );

    if (charData == null) {
      throw Exception("هذه الشخصية غير موجودة. تأكد من كتابة الاسم الإنجليزي بدقة كما في MAL.");
    }

    final gameRef = FirebaseFirestore.instance
        .collection(FirestorePaths.groupGames(groupId))
        .doc(gameId);

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(gameRef);
      final game = GameModel.fromMap(gameId, snapshot.data()!);

      // التحقق من الوقت (60 ثانية للتجهيز)
      if (game.setupStartedAt != null && 
          GameTimerManager.hasSetupTimeout(game.setupStartedAt!)) {
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
      
      // تحقق أن الشخصية محفوظة قبل الجاهزية
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
        // الاثنين جاهزين - نبدأ اللعبة لكن نبقى في setup لمدة 2 ثانية
        // عشان الاثنين يشوفون علامة الصح قبل الانتقال
        updates['status'] = GameStatus.guessing.name;
        updates['currentTurnUserId'] = game.playerOneId;
        updates['lastActionAt'] = FieldValue.serverTimestamp();
        updates['lastActionType'] = null; // أول دور هو سؤال
        // لا تغير setupStartedAt - نخليه للعداد
      }

      transaction.update(gameRef, updates);
    });
    
    // انتظر ثانيتين قبل ما نرجع للواجهة - هذا يمنع الخروج المفاجئ
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
      // ✅ فوز!
      await finishGame(groupId, gameId, winnerId: userId, winnerName: userName);
    } else {
      // خطأ، يتم نقل الدور للخصم
      await switchTurn(groupId, gameId);
    }
  }

  // =============================================================
  // 🛡️ تبادل الأدوار
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

  // =============================================================
  // 🛡️ تحديث نوع آخر حركة (سؤال/جواب)
  // =============================================================
  Future<void> updateLastAction(String groupId, String gameId, String actionType) async {
    final gameRef = FirebaseFirestore.instance
        .collection(FirestorePaths.groupGames(groupId))
        .doc(gameId);

    await gameRef.update({
      'lastActionType': actionType,
      'lastActionAt': FieldValue.serverTimestamp(),
    });
  }

  // =============================================================
  // 🛡️ إنهاء اللعبة
  // =============================================================
  Future<void> finishGame(
    String groupId, 
    String gameId, {
    String? winnerId, 
    String? winnerName,
    bool isCancelled = false,
    String? reason,
  }) async {
    final gameRef = FirebaseFirestore.instance
        .collection(FirestorePaths.groupGames(groupId))
        .doc(gameId);

    final snapshot = await gameRef.get();
    if (!snapshot.exists) return;
    
    final game = GameModel.fromMap(gameId, snapshot.data()!);
    if (game.status.isOver) return; // منع الإنهاء المتكرر

    await gameRef.update({
      'status': isCancelled ? GameStatus.cancelled.name : GameStatus.finished.name,
      'winnerUserId': winnerId,
      'finishedAt': FieldValue.serverTimestamp(),
      'endReason': reason,
    });

    // ✅ إرسال رسالة الحالة النهائية للدردشة مع Slot اللعبة للتمييز
    await _sendGameSystemMessage(
      groupId: groupId,
      gameId: gameId,
      action: isCancelled ? 'quit' : 'win',
      senderId: winnerId ?? (isCancelled ? game.playerOneId : ""), 
      senderName: winnerName ?? (isCancelled ? "لاعب منسحب" : "النظام"),
      gameSlot: game.gameSlot,
    );
  }

  // =============================================================
  // 🛠️ دالة مساعدة داخلية لإرسال رسائل النظام (مع دعم Slot للتمييز)
  // =============================================================
  Future<void> _sendGameSystemMessage({
    required String groupId,
    required String gameId,
    required String action,
    required String senderId,
    required String senderName,
    required String gameSlot,
  }) async {
    final messageId = _uuid.v4();
    final messageData = {
      'id': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'type': 'text',
      'text': '', // الـ Bubble يحدد النص برمجياً بناءً على الـ action
      'timestamp': FieldValue.serverTimestamp(),
      'gameId': gameId,
      'gameAction': action,
      'gameSlot': gameSlot, // ✅ مهم جداً للتمييز البصري بين اللعبتين في الدردشة
    };

    await FirebaseFirestore.instance
        .collection(FirestorePaths.groupMessages(groupId))
        .doc(messageId)
        .set(messageData);
  }

  // =============================================================
  // 🛰️ مراقبة الألعاب النشطة والتحكيم التلقائي
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