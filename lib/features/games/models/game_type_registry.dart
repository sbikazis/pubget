import 'package:flutter/material.dart';

import '../engine/scoring.dart';
import 'game_models.dart';

final class GameCapabilities {
  const GameCapabilities({
    this.usesRounds = false,
    this.usesScoring = false,
    this.groupRequired = true,
    this.minPlayers = 1,
    this.maxPlayers = 16,
  });

  final bool usesRounds;
  final bool usesScoring;
  final bool groupRequired;
  final int minPlayers;
  final int maxPlayers;
}

/// Metadata + capability flags for a registered game type.
///
/// Registering a new game means adding a [GameType] value and a spec here.
/// Do not put game-specific rules in the generic engine.
final class GameTypeSpec {
  const GameTypeSpec({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.version,
    required this.implemented,
    required this.capabilities,
    this.scoringId = ScoringStrategyId.noop,
  });

  final GameType type;
  final String name;
  final String description;
  final IconData icon;
  final int version;
  final bool implemented;
  final GameCapabilities capabilities;
  final ScoringStrategyId scoringId;
}

abstract final class GameTypeRegistry {
  static const specs = <GameType, GameTypeSpec>{
    GameType.guessCharacter: GameTypeSpec(
      type: GameType.guessCharacter,
      name: 'Guess the Character',
      description: 'Identify the character from clues.',
      icon: Icons.person_search_outlined,
      version: 1,
      implemented: true,
      capabilities: GameCapabilities(usesScoring: true, usesRounds: true),
    ),
    GameType.animeChain: GameTypeSpec(
      type: GameType.animeChain,
      name: 'Anime Chain',
      description: 'Keep a chain of related anime titles going.',
      icon: Icons.link_outlined,
      version: 1,
      implemented: true,
      capabilities: GameCapabilities(usesRounds: true),
    ),
    GameType.emojiAnimeGuess: GameTypeSpec(
      type: GameType.emojiAnimeGuess,
      name: 'Emoji Anime Guess',
      description: 'Guess the anime from emoji clues.',
      icon: Icons.emoji_emotions_outlined,
      version: 1,
      implemented: true,
      capabilities: GameCapabilities(usesScoring: true),
    ),
    // Registered for routing/capability lookup. Implementation is PROMPT 13.
    GameType.mafia: GameTypeSpec(
      type: GameType.mafia,
      name: 'Mafia',
      description: 'Coming soon.',
      icon: Icons.nightlight_outlined,
      version: 1,
      implemented: false,
      capabilities: GameCapabilities(
        usesRounds: true,
        minPlayers: 4,
        maxPlayers: 16,
      ),
    ),
  };

  static GameTypeSpec of(GameType type) {
    final spec = specs[type];
    if (spec == null) {
      throw StateError('Unknown game type: $type');
    }
    return spec;
  }

  static GameTypeSpec? tryOf(GameType type) => specs[type];

  static GameTypeSpec? byName(String raw) {
    for (final spec in specs.values) {
      if (spec.type.name == raw) return spec;
    }
    return null;
  }

  static List<GameTypeSpec> get implemented =>
      specs.values.where((spec) => spec.implemented).toList(growable: false);

  static bool isRegistered(GameType type) => specs.containsKey(type);
}

abstract final class GameStrings {
  static const noGamesTitle = 'No games yet';
  static const noGamesMessage = 'Start a game from a group.';
  static const missing = 'This game no longer exists.';
  static const permission = "You don't have permission to manage games.";
  static const notJoinable = 'This game is not open to join.';
  static const alreadyStarted = 'This game has already started.';
  static const alreadyCompleted = 'This game is already finished.';
  static const notParticipant = 'You are not a participant in this game.';
  static const create = 'Create game';
  static const join = 'Join game';
  static const leave = 'Leave game';
  static const start = 'Start game';
  static const pause = 'Pause';
  static const resume = 'Resume';
  static const end = 'End game';
  static const cancel = 'Cancel game';
  static const submit = 'Submit action';
  static const retry = 'Try again';
  static const seeAll = 'See all games';
  static const groupGames = 'Group games';
  static const resultTitle = 'Result';
  static const comingSoon = 'This game is not available yet.';
  static const copied = 'Game link copied';
  static const copyLink = 'Copy link';
  static const share = 'Share';
}
