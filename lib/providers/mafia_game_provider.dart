import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mafia/mafia_game_model.dart';
import '../models/mafia/mafia_player_model.dart';
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

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  MafiaGameModel? _currentGame;
  MafiaGameModel? get currentGame => _currentGame;

  List<MafiaPlayerModel> _players = [];
  List<MafiaPlayerModel> get players => _players;

  List<MafiaEventModel> _events = [];
  List<MafiaEventModel> get events => _events;

  List<MafiaChatMessageModel> _chatMessages = [];
  List<MafiaChatMessageModel> get chatMessages => _chatMessages;

  StreamSubscription? _gameSubscription;
  StreamSubscription? _playersSubscription;
  StreamSubscription? _eventsSubscription;
  StreamSubscription? _chatSubscription;

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
        role: MafiaRoles.citizen,
        team: MafiaTeams.citizens,
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

  Future<void> joinGame({
    required String gameId,
    required MafiaPlayerModel player,
  }) async {
    setLoading(true);
    try {
      await _repository.createPlayer(gameId, player);
    } finally {
      setLoading(false);
    }
  }

  void subscribeToGame({required String gameId}) {
    _gameSubscription?.cancel();
    _playersSubscription?.cancel();
    _eventsSubscription?.cancel();
    _chatSubscription?.cancel();

    _gameSubscription = _repository.streamGame(gameId).listen((game) {
      _currentGame = game;
      notifyListeners();
    });

    _playersSubscription = _repository.streamPlayers(gameId).listen((players) {
      _players = players;
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

  void unsubscribe() {
    _gameSubscription?.cancel();
    _playersSubscription?.cancel();
    _eventsSubscription?.cancel();
    _chatSubscription?.cancel();
  }

  Future<void> sendGameChatMessage({
    required String gameId,
    required String senderId,
    required String senderName,
    required String text,
    String type = 'player',
  }) async {
    final message = MafiaChatMessageModel(
      id: '${senderId}_${DateTime.now().millisecondsSinceEpoch}',
      sender: senderName,
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
    final action = MafiaActionModel(
      id: '${playerId}_${DateTime.now().millisecondsSinceEpoch}',
      playerId: playerId,
      role: role,
      targetId: targetId,
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
    final vote = MafiaVoteModel(
      id: '${voterId}_${DateTime.now().millisecondsSinceEpoch}',
      voterId: voterId,
      targetId: targetId,
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
