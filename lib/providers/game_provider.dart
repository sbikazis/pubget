import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_model.dart';
import '../services/firebase/firestore_service.dart';
import '../services/api/anime_api_service.dart';
import '../core/constants/firestore_paths.dart';
import '../core/constants/game_status.dart';
import '../core/logic/game_logic_validator.dart';
import '../core/utils/game_timer_manager.dart';
import '../core/utils/game_auto_judge.dart'; // ✅ إضافة الاستيراد الجديد

class GameProvider extends ChangeNotifier {
  final FirestoreService _firestore;
  final Uuid _uuid = const Uuid();

  GameProvider({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // =============================================================
  // 🛡️ إنشاء لعبة جديدة (مع فحص الحد الأقصى - لعبتين فقط)
  // =============================================================
  Future<String?> createGame({
    required String groupId,
    required String creatorUserId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. جلب الألعاب النشطة الحالية للمجموعة
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestorePaths.groupGames(groupId))
          .get();
      
      final activeGames = snapshot.docs
          .map((doc) => GameModel.fromMap(doc.id, doc.data()))
          .where((g) => !g.status.isOver)
          .toList();

      // 2. التحقق من قاعدة الحد الأقصى (عبر الـ Validator)
      if (!GameLogicValidator.canCreateNewGame(activeGames)) {
        throw Exception("المجموعة ممتلئة، هناك لعبتان قيد التنفيذ حالياً.");
      }

      // 3. تحديد الـ Slot المتاح
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
      );

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
  // 🛡️ الانضمام للعبة (حماية ذرية Transaction لمنع السبق)
  // =============================================================
  Future<void> joinGame({
    required String groupId,
    required String gameId,
    required String userId,
  }) async {
    final gameRef = FirebaseFirestore.instance
        .collection(FirestorePaths.groupGames(groupId))
        .doc(gameId);

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(gameRef);

      if (!snapshot.exists) throw Exception("اللعبة لم تعد موجودة!");

      final game = GameModel.fromMap(gameId, snapshot.data()!);

      // فحص الأمان عبر الـ Validator
      if (!GameLogicValidator.isSlotStillAvailable(game)) {
        throw Exception("آسفون! قام شخص آخر بالانضمام أثناء قراءتك للقواعد.");
      }

      transaction.update(gameRef, {
        'playerTwoId': userId,
        'status': GameStatus.setup.name,
        'setupStartedAt': FieldValue.serverTimestamp(), // بدء عداد الـ 60 ثانية
      });
    });
  }

  // =============================================================
  // 🛡️ اختيار الشخصية (API + تخزين الصورة + التحقق من الجاهزية)
  // =============================================================
  Future<void> setCharacter({
    required String groupId,
    required String gameId,
    required String userId,
    required List<int> animeIds,
    required String characterName,
  }) async {
    // 1. التحقق من MAL وجلب الصورة
    final charData = await AnimeApiService.getCharacterDetails(
      animeIds: animeIds,
      characterName: characterName,
    );

    if (charData == null) {
      throw Exception("هذه الشخصية غير موجودة في MAL لهذا الأنمي. تأكد من كتابة الاسم بدقة.");
    }

    final gameRef = FirebaseFirestore.instance
        .collection(FirestorePaths.groupGames(groupId))
        .doc(gameId);

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(gameRef);
      final game = GameModel.fromMap(gameId, snapshot.data()!);

      // التحقق من الوقت (60 ثانية)
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
  // 🛡️ نظام الجاهزية (بدء اللعبة الفعلي)
  // =============================================================
  Future<void> toggleReady({
    required String groupId,
    required String gameId,
    required String userId,
  }) async {
    final gameRef = FirebaseFirestore.instance
        .collection(FirestorePaths.groupGames(groupId))
        .doc(gameId);

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(gameRef);
      final game = GameModel.fromMap(gameId, snapshot.data()!);

      bool isP1 = userId == game.playerOneId;
      Map<String, dynamic> updates = {
        isP1 ? 'isPlayerOneReady' : 'isPlayerTwoReady': true,
      };

      // إذا أصبح كلاهما جاهزاً، تبدأ اللعبة فوراً
      bool willBeReady = isP1 ? game.isPlayerTwoReady : game.isPlayerOneReady;
      if (willBeReady) {
        updates['status'] = GameStatus.guessing.name;
        updates['currentTurnUserId'] = game.playerOneId; // اللاعب الأول يبدأ السؤال
        updates['lastActionAt'] = FieldValue.serverTimestamp(); // بدء عداد الـ 40 ثانية
      }

      transaction.update(gameRef, updates);
    });
  }

  // =============================================================
  // 🛡️ منطق التخمين (Win/Loss Logic)
  // =============================================================
  Future<void> guessCharacter({
    required String groupId,
    required String gameId,
    required String userId,
    required String guessedName,
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
      // فوز!
      await finishGame(groupId, gameId, winnerId: userId);
    } else {
      // خطأ -> نقل الدور للخصم
      await switchTurn(groupId, gameId);
    }
  }

  // =============================================================
  // 🛡️ تبادل الأدوار + تحديث العداد
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
      'lastActionAt': FieldValue.serverTimestamp(), // إعادة تصفير الـ 40 ثانية
    });
  }

  // =============================================================
  // 🛡️ التحكيم التلقائي (التحقق من العدادات)
  // =============================================================
  Future<void> processAutoJudge(String groupId, GameModel game) async {
    // 1. فحص نوع التايم آوت عبر الحكم الصامت
    final timeoutType = GameAutoJudge.checkTimeout(game);
    if (timeoutType == TimeoutType.none) return;

    // 2. تحديد الخاسر والرسالة
    String? timedOutPlayerId = GameAutoJudge.getTimedOutPlayerId(game);
    String reason = GameAutoJudge.getReasonMessage(timeoutType, timedOutPlayerId ?? "مجهول");

    // 3. تنفيذ الحكم في قاعدة البيانات
    if (timeoutType == TimeoutType.totalGameTimeout) {
      // تعادل (انتهت الـ 10 دقائق)
      await finishGame(groupId, game.id, isCancelled: false, reason: reason);
    } else {
      // خسارة بسبب الوقت (40ث أو 60ث)
      String? winnerId = (timedOutPlayerId == game.playerOneId) 
          ? game.playerTwoId 
          : game.playerOneId;
      await finishGame(groupId, game.id, winnerId: winnerId, reason: reason);
    }
  }

  // =============================================================
  // 🛡️ إنهاء اللعبة (فوز، تعادل، انسحاب)
  // =============================================================
  Future<void> finishGame(
    String groupId, 
    String gameId, {
    String? winnerId, 
    bool isCancelled = false,
    String? reason,
  }) async {
    await FirebaseFirestore.instance
        .collection(FirestorePaths.groupGames(groupId))
        .doc(gameId)
        .update({
      'status': isCancelled ? GameStatus.cancelled.name : GameStatus.finished.name,
      'winnerUserId': winnerId,
      'finishedAt': FieldValue.serverTimestamp(),
      'endReason': reason,
    });
  }

  // =============================================================
  // 🛰️ مراقبة الألعاب النشطة للمجموعة (مطلوب للشريط السفلي) - ✅ جديد
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

  // =============================================================
  // 🛰️ مراقبة حالة لعبة محددة (Streams)
  // =============================================================
  Stream<GameModel?> streamCurrentGame(String groupId, String gameId) {
    return _firestore.streamDocument(
      path: FirestorePaths.groupGames(groupId),
      docId: gameId,
    ).map((snap) => snap.exists ? GameModel.fromMap(snap.id, snap.data()!) : null);
  }
}
