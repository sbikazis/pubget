// lib/providers/mafia_game_provider.dart
//
// ✅ التعديل الوحيد: sendGameChatMessage تقبل senderAvatar الآن،
// وتكتب senderId في الرسالة. بقية الملف من Stage 7 دون أي تغيير.

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mafia/mafia_game_model.dart';
import '../models/mafia/mafia_player_model.dart';
import '../models/mafia/mafia_player_private_model.dart';
import '../models/mafia/mafia_event_model.dart';
import '../models/mafia/mafia_action_model.dart';
import '../models/mafia/mafia_chat_message_model.dart';
import '../models/mafia/mafia_vote_model.dart';
import '../services/mafia/mafia_game_repository.dart';
import '../core/constants/mafia_constants.dart';
import 'user_provider.dart';

class MafiaGameProvider extends ChangeNotifier {
  final MafiaGameRepository _repository;
  final UserProvider _userProvider;

  MafiaGameProvider({
    MafiaGameRepository? repository,
    required UserProvider userProvider,
  })  : _repository = repository ?? MafiaGameRepository(),
        _userProvider = userProvider;

  static const Duration _heartbeatInterval = Duration(seconds: 25);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  MafiaGameModel? _currentGame;
  MafiaGameModel? get currentGame => _currentGame;

  List<MafiaPlayerModel> _players = [];
  List<MafiaPlayerModel> get players => _players;

  MafiaPlayerPrivateModel? _myPrivateData;
  MafiaPlayerPrivateModel? get myPrivateData => _myPrivateData;

  List<MafiaVoteModel> _votes = [];
  List<MafiaVoteModel> get votes => _votes;

  List<MafiaEventModel> _events = [];
  List<MafiaEventModel> get events => _events;

  List<MafiaChatMessageModel> _chatMessages = [];
  List<MafiaChatMessageModel> get chatMessages => _chatMessages;

  StreamSubscription? _gameSubscription;
  StreamSubscription? _playersSubscription;
  StreamSubscription? _privateSubscription;
  StreamSubscription? _votesSubscription;
  StreamSubscription? _eventsSubscription;
  StreamSubscription? _chatSubscription;
  Timer? _heartbeatTimer;
  String? _heartbeatGameId;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<String> createGame({
    required String groupId,
    required String createdBy,
    int minPlayers = 8,
    int maxPlayers = 8,
    String version = 'classic',
  }) async {
    setLoading(true);
    try {
      final gameId = '${groupId}_${DateTime.now().millisecondsSinceEpoch}';
      final game = MafiaGameModel(
        id: gameId,
        groupId: groupId,
        createdBy: createdBy,
        createdAt: DateTime.now(),
        version: version,
        status: MafiaGameStatus.waiting,
        currentPhase: MafiaGameStatus.waiting.name,
        playersCount: 1,
        minPlayers: minPlayers,
        maxPlayers: maxPlayers,
        isLocked: false,
        countdownEndsAt:
            DateTime.now().add(const Duration(seconds: MafiaTimers.lobbyWaitSeconds)),
      );

      final user = _userProvider.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final player = MafiaPlayerModel(
        id: user.id,
        userId: user.id,
        username: user.username,
        avatar: user.avatarUrl,
        isAlive: true,
        isDisconnected: false,
        isMuted: false,
        hasLeft: false,
        joinedAt: DateTime.now(),
        coinsEarned: 0,
        votesReceived: 0,
        canSpeak: true,
        canVote: true,
        canUseAbility: true,
        revealedRole: false,
      );

      await _repository.createGameWithInitialPlayer(game, player);
      return gameId;
    } finally {
      setLoading(false);
    }
  }

  Future<void> joinCurrentUser({required String gameId}) async {
    final user = _userProvider.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final player = MafiaPlayerModel(
      id: user.id,
      userId: user.id,
      username: user.username,
      avatar: user.avatarUrl,
      isAlive: true,
      isDisconnected: false,
      isMuted: false,
      hasLeft: false,
      joinedAt: DateTime.now(),
      coinsEarned: 0,
      votesReceived: 0,
      canSpeak: true,
      canVote: true,
      canUseAbility: true,
      revealedRole: false,
    );

    setLoading(true);
    try {
      await _repository.joinGame(gameId: gameId, player: player);
    } finally {
      setLoading(false);
    }
  }

  Future<void> leaveCurrentUser({required String gameId}) async {
    final user = _userProvider.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    setLoading(true);
    try {
      await _repository.leaveGame(gameId: gameId, playerId: user.id);
    } finally {
      setLoading(false);
    }
  }

  void subscribeToGame({required String gameId}) {
    _gameSubscription?.cancel();
    _playersSubscription?.cancel();
    _privateSubscription?.cancel();
    _votesSubscription?.cancel();
    _eventsSubscription?.cancel();
    _chatSubscription?.cancel();
    _stopHeartbeat();

    _gameSubscription = _repository.streamGame(gameId).listen((game) {
      _currentGame = game;
      notifyListeners();
    });

    _playersSubscription = _repository.streamPlayers(gameId).listen((players) {
      _players = players;
      notifyListeners();
    });

    final currentUserId = _userProvider.currentUser?.id;
    if (currentUserId != null) {
      _privateSubscription = _repository
          .streamMyPrivateData(gameId, currentUserId)
          .listen((privateData) {
        _myPrivateData = privateData;
        notifyListeners();
      });

      _startHeartbeat(gameId: gameId, playerId: currentUserId);
    }

    _votesSubscription = _repository.streamVotes(gameId).listen((votes) {
      _votes = votes;
      notifyListeners();
    });

    _eventsSubscription = _repository.streamEvents(gameId).listen((events) {
      _events = events;
      notifyListeners();
    });

    _chatSubscription = _repository.streamChat(gameId).listen((chatMessages) {
      _chatMessages = chatMessages;
      notifyListeners();
    });
  }

  void _startHeartbeat({required String gameId, required String playerId}) {
    _heartbeatGameId = gameId;
    _repository.sendHeartbeat(gameId: gameId, playerId: playerId);
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _repository.sendHeartbeat(gameId: gameId, playerId: playerId);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatGameId = null;
  }

  void unsubscribe() {
    _gameSubscription?.cancel();
    _playersSubscription?.cancel();
    _privateSubscription?.cancel();
    _votesSubscription?.cancel();
    _eventsSubscription?.cancel();
    _chatSubscription?.cancel();
    _stopHeartbeat();
  }

  /// ✅ الآن تقبل senderAvatar (اختياري) وتكتب senderId في الرسالة —
  /// ضروري لعرض الصورة الرمزية وتحديد isMe بدقة في MafiaChatBubble.
  Future<void> sendGameChatMessage({
    required String gameId,
    required String senderId,
    required String senderName,
    required String text,
    String senderAvatar = '',
    String type = 'player',
  }) async {
    final message = MafiaChatMessageModel(
      id: '${senderId}_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      sender: senderName,
      senderAvatar: senderAvatar,
      text: text,
      time: DateTime.now(),
      type: type,
    );
    await _repository.addChatMessage(gameId, message);
  }

  Future<void> submitNightAction({
    required String gameId,
    required String playerId,
    required String role,
    String? targetId,
  }) async {
    final nightNumber = _currentGame?.currentNight ?? 0;
    final action = MafiaActionModel(
      id: '${playerId}_n$nightNumber',
      playerId: playerId,
      role: role,
      targetId: targetId,
      nightNumber: nightNumber,
      submittedAt: DateTime.now(),
      isCompleted: true,
    );
    await _repository.addNightAction(gameId, action);
  }

  Future<void> submitVote({
    required String gameId,
    required String voterId,
    required String targetId,
  }) async {
    final dayNumber = _currentGame?.currentDay ?? 0;
    final vote = MafiaVoteModel(
      id: '${voterId}_d$dayNumber',
      voterId: voterId,
      targetId: targetId,
      dayNumber: dayNumber,
      time: DateTime.now(),
    );
    await _repository.addVote(gameId, vote);
  }

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
  }
}