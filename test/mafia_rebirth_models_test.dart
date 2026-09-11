import 'package:flutter_test/flutter_test.dart';

import 'package:pubget/features/mafia/models/mafia_models.dart';

void main() {
  test('Mafia model normalizes server lifecycle states', () {
    final game = MafiaGame.fromMap(
      <String, dynamic>{
        'status': 'GAME_OVER',
        'currentPhase': 'VOTE_RESULT',
        'stateVersion': 8,
        'revoteCount': 1,
        'revotePending': true,
      },
      id: 'm1',
    );

    expect(game.isFinished, isTrue);
    expect(game.phase, 'VOTE_RESULT');
    expect(game.stateVersion, 8);
    expect(game.revotePending, isTrue);
  });

  test('private state keeps Mafia teammates and private results', () {
    final state = MafiaPrivateState.fromMap(<String, dynamic>{
      'role': 'detective',
      'team': 'citizens',
      'mafiaTeammates': <String>[],
      'lastInvestigationResult': <String, dynamic>{
        'result': 'Mafia',
      },
    });

    expect(state.assigned, isTrue);
    expect(state.role, 'detective');
    expect(state.lastInvestigationResult?['result'], 'Mafia');
  });
}