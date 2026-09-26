import 'package:flutter/material.dart';

import '../../mafia/models/mafia_models.dart';
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
    required this.winCondition,
    required this.rules,
    this.genericCreate = true,
    this.scoringId = ScoringStrategyId.noop,
  });

  final GameType type;
  final String name;
  final String description;
  final IconData icon;
  final int version;
  final bool implemented;

  /// True when [createGame] can create this type. Mafia is playable
  /// (`implemented`) but only through `createMafiaGame`.
  final bool genericCreate;
  final GameCapabilities capabilities;
  final ScoringStrategyId scoringId;

  /// How a game is won, described from the implemented engine. This is
  /// presentation only: the server decides the outcome.
  final String winCondition;

  /// Short rules summary for the Game Center Rules section.
  final String rules;
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
      capabilities: GameCapabilities(
        usesScoring: true,
        usesRounds: true,
        minPlayers: 2,
        maxPlayers: 2,
      ),
      winCondition: 'Guess the other player\'s secret character.',
      rules:
          'Each player picks a secret character from the catalog, then takes '
          'turns asking yes or no questions or guessing outright.',
    ),
    GameType.animeChain: GameTypeSpec(
      type: GameType.animeChain,
      name: 'Anime Chain',
      description: 'Keep a chain of related anime titles going.',
      icon: Icons.link_outlined,
      version: 1,
      implemented: true,
      capabilities: GameCapabilities(
        usesRounds: true,
        usesScoring: true,
        minPlayers: 2,
        maxPlayers: 2,
      ),
      winCondition: 'Hold the highest score when the chain ends.',
      rules:
          'Take turns naming an Anime that links to the previous title. A '
          'broken link, a duplicate, or a timeout ends the game.',
    ),
    GameType.emojiAnimeGuess: GameTypeSpec(
      type: GameType.emojiAnimeGuess,
      name: 'Emoji Anime Guess',
      description: 'Guess the anime from emoji clues.',
      icon: Icons.emoji_emotions_outlined,
      version: 1,
      implemented: true,
      capabilities: GameCapabilities(
        usesScoring: true,
        usesRounds: true,
        minPlayers: 2,
        maxPlayers: 4,
      ),
      winCondition: 'Most correct guesses across the rounds.',
      rules:
          'One player owns the emoji clue and cannot guess. Everyone else '
          'guesses the Anime once per round; a correct guess scores a point.',
    ),
    GameType.mafia: GameTypeSpec(
      type: GameType.mafia,
      name: 'Mafia',
      description: 'A private-role social deduction game.',
      icon: Icons.nightlight_outlined,
      version: 1,
      implemented: true,
      genericCreate: false,
      capabilities: GameCapabilities(
        usesRounds: true,
        minPlayers: MafiaLimits.minPlayers,
        maxPlayers: MafiaLimits.maxPlayers,
      ),
      winCondition:
          'Mafia reaches parity with the town, or the town eliminates '
          'every Mafia member.',
      rules:
          'Roles are secret and assigned by the server. Nights resolve '
          'silently, days vote one player out, and Mafia chat stays private.',
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

  static List<GameTypeSpec> get implemented => specs.values
      .where((spec) => spec.implemented && spec.genericCreate)
      .toList(growable: false);

  /// Every playable game, including Mafia, which the Game Center must always
  /// show even though it is created through its own callable.
  static List<GameTypeSpec> get all =>
      specs.values.where((spec) => spec.implemented).toList(growable: false);

  static List<GameTypeSpec> get genericCreate => specs.values
      .where((spec) => spec.implemented && spec.genericCreate)
      .toList(growable: false);

  static bool isRegistered(GameType type) => specs.containsKey(type);

  /// Default configuration for a type. Only implemented options are filled.
  static GameConfiguration configurationFor(GameType type) {
    final spec = of(type);
    final quiz = spec.capabilities.usesRounds && spec.capabilities.usesScoring;
    return GameConfiguration(
      minPlayers: spec.capabilities.minPlayers,
      maxPlayers: spec.capabilities.maxPlayers,
      usesRounds: spec.capabilities.usesRounds,
      roundCount: quiz ? 5 : 1,
      timerSeconds: quiz ? 20 : 45,
      difficulty: 'normal',
    );
  }
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
  static const playAgain = 'Play again';
  static const viewHistory = 'View history';
  static const eliminated = 'Eliminated';
  static const waitingForPlayers = 'Waiting for players';
  static const cannotStart = 'Not enough players to start.';
  static const yourTurn = 'Your turn';
  static const waitingTurn = 'Waiting for the other players';
  static const submitting = 'Submitting…';
  static const timedOut = 'Time is up';
  static const reconnecting = 'Reconnecting to the live game…';
  static const offlineAction = 'Connect to the internet to take this action.';

  // Guess Character phase copy.
  static const guessCharacter = 'Guess the Character';
  static const chooseSecret = 'Choose your secret character';
  static const secretLocked = 'Secret locked in. Waiting for the other player.';
  static const searchSecretCharacter = 'Search the character catalog';
  static const noCatalogMatch = 'No matches in the catalog.';
  static const askAQuestion = 'Ask a yes or no question';
  static const guessInstead = 'Or guess the character directly';
  static const ask = 'Ask';
  static const yes = 'Yes';
  static const no = 'No';
  static const answered = 'Answer';
  static const wrongGuess = 'Wrong guess. The turn passed.';
  static const turnTimedOut = 'That turn timed out.';
  static const clueOwnerTurn = 'You own this clue. Wait for a guess.';
  static const alreadyGuessed = 'You already guessed this round.';
  static const nextTitle = 'Next title';
  static const animeTitle = 'Anime title';
  static const submitGuess = 'Submit guess';
  static const lastTitle = 'Last title';
  static const turn = 'Turn';
  static const you = 'You';
  static const guessTheAnime = 'Guess the Anime from the emoji clue';
}
