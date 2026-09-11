import 'package:cloud_firestore/cloud_firestore.dart';

/// Versioned contracts for the rebuilt Games domain.  These models deliberately
/// do not reference chat events; chat integration consumes system messages only.
const gamesSchemaVersion = 2;

enum GameLifecycleStatusV2 {
  created,
  waiting,
  starting,
  inProgress,
  completed,
  cancelled,
}

enum GameOutcomeV2 { win, draw, loss }

enum GameTypeV2 { guessCharacter, animeChain, emojiAnimeGuess }

GameTypeV2 parseGameTypeV2(Object? value) => switch (value) {
  'guessCharacter' || 'guess_character' => GameTypeV2.guessCharacter,
  'animeChain' || 'anime_chain' => GameTypeV2.animeChain,
  'emojiAnimeGuess' || 'emoji_anime_guess' => GameTypeV2.emojiAnimeGuess,
  _ => throw FormatException('Unsupported game type: $value'),
};

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

final class GameCommandRequest {
  const GameCommandRequest({
    required this.requestId,
    required this.gameId,
    required this.expectedVersion,
    required this.command,
    this.payload = const <String, dynamic>{},
  });
  final String requestId;
  final String gameId;
  final int expectedVersion;
  final String command;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toMap() => {
    'requestId': requestId,
    'gameId': gameId,
    'expectedVersion': expectedVersion,
    'command': command,
    'payload': payload,
    'schemaVersion': gamesSchemaVersion,
  };
}

final class GamePlayerV2 {
  const GamePlayerV2({
    required this.userId,
    required this.joinedAt,
    this.displayName = '',
    this.score = 0,
    this.connected = true,
  });
  final String userId;
  final String displayName;
  final DateTime? joinedAt;
  final int score;
  final bool connected;

  factory GamePlayerV2.fromMap(Map<String, dynamic> map, String userId) =>
      GamePlayerV2(
        userId: userId,
        displayName: map['displayName'] as String? ?? userId,
        joinedAt: _date(map['joinedAt']),
        score: (map['score'] as num?)?.toInt() ?? 0,
        connected: map['connected'] != false,
      );
}

final class GameSessionV2 {
  const GameSessionV2({
    required this.id,
    required this.groupId,
    required this.type,
    required this.status,
    required this.creatorId,
    required this.version,
    required this.players,
    this.createdAt,
    this.deadlineAt,
    this.state = const <String, dynamic>{},
  });
  final String id;
  final String groupId;
  final GameTypeV2 type;
  final GameLifecycleStatusV2 status;
  final String creatorId;
  final int version;
  final List<GamePlayerV2> players;
  final DateTime? createdAt;
  final DateTime? deadlineAt;
  final Map<String, dynamic> state;

  factory GameSessionV2.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    final rawPlayers = map['players'];
    return GameSessionV2(
      id: id,
      groupId: map['groupId'] as String? ?? '',
      type: parseGameTypeV2(map['type']),
      status: GameLifecycleStatusV2.values.firstWhere(
        (item) =>
            item.name == map['status'] ||
            item.name == _statusName(map['status']),
        orElse: () =>
            throw FormatException('Unsupported game status: ${map['status']}'),
      ),
      creatorId: map['creatorId'] as String? ?? '',
      version: (map['version'] as num?)?.toInt() ?? 0,
      players: rawPlayers is List
          ? rawPlayers
                .whereType<Map>()
                .map((item) {
                  final data = Map<String, dynamic>.from(item);
                  return GamePlayerV2.fromMap(
                    data,
                    data['userId'] as String? ?? '',
                  );
                })
                .toList(growable: false)
          : const <GamePlayerV2>[],
      createdAt: _date(map['createdAt']),
      deadlineAt: _date(map['deadlineAt']),
      state: map['state'] is Map
          ? Map<String, dynamic>.from(map['state'] as Map)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toMap() => {
    'schemaVersion': gamesSchemaVersion,
    'groupId': groupId,
    'type': type.name,
    'status': status.name,
    'creatorId': creatorId,
    'version': version,
    'players': players
        .map(
          (player) => {
            'userId': player.userId,
            'displayName': player.displayName,
            'joinedAt': player.joinedAt?.toUtc().toIso8601String(),
            'score': player.score,
            'connected': player.connected,
          },
        )
        .toList(growable: false),
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'deadlineAt': deadlineAt?.toUtc().toIso8601String(),
    'state': state,
  };

  bool get isTerminal =>
      status == GameLifecycleStatusV2.completed ||
      status == GameLifecycleStatusV2.cancelled;
}

String _statusName(Object? value) => switch (value) {
  'in_progress' => 'inProgress',
  _ => value?.toString() ?? '',
};

final class GuessCharacterState {
  const GuessCharacterState({
    required this.currentPlayerId,
    this.selectedCharacterIds = const <String, String>{},
    this.question,
    this.questionCount = 0,
    this.guess,
  });
  final String currentPlayerId;
  final Map<String, String> selectedCharacterIds;
  final String? question;
  final int questionCount;
  final String? guess;
}

final class AnimeChainState {
  const AnimeChainState({
    required this.currentPlayerId,
    this.chain = const <String>[],
    this.usedAnimeIds = const <String>{},
    this.scores = const <String, int>{},
    this.turnDeadline,
  });
  final String currentPlayerId;
  final List<String> chain;
  final Set<String> usedAnimeIds;
  final Map<String, int> scores;
  final DateTime? turnDeadline;
}

final class EmojiAnimeGuessState {
  const EmojiAnimeGuessState({
    required this.turnOwnerId,
    this.emojis = const <String>[],
    this.round = 1,
    this.scores = const <String, int>{},
    this.roundDeadline,
  });
  final String turnOwnerId;
  final List<String> emojis;
  final int round;
  final Map<String, int> scores;
  final DateTime? roundDeadline;
}
