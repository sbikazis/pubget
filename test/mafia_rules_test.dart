import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/games/mafia/mafia_phase.dart';
import 'package:pubget/features/games/mafia/mafia_roles.dart';
import 'package:pubget/features/games/mafia/mafia_rules.dart';

void main() {
  group('role assignment', () {
    test('assigns the correct number of roles with no duplicates', () {
      final ids = ['dana', 'alice', 'bob', 'eve'];
      final counts = MafiaRules.resolveRoleCounts(playerCount: 4)!;
      expect(counts.mafiaCount, 1);
      expect(counts.civilianCount, 3);
      expect(counts.detectiveCount, 0);
      expect(counts.doctorCount, 0);
      final roles = MafiaRules.assignRoles(
        userIds: ids,
        counts: counts,
        shuffle: (deck) => deck,
      );
      expect(roles.keys.toSet(), {'alice', 'bob', 'dana', 'eve'});
      expect(roles.values.where((role) => role == MafiaRole.mafia).length, 1);
      expect(roles.values.where((role) => role == MafiaRole.civilian).length, 3);
    });

    test('adds doctor and detective at the documented thresholds', () {
      expect(MafiaRules.defaultRoleCounts(5).doctorCount, 1);
      expect(MafiaRules.defaultRoleCounts(5).detectiveCount, 0);
      expect(MafiaRules.defaultRoleCounts(6).detectiveCount, 1);
      expect(
        MafiaRules.resolveRoleCounts(playerCount: 3),
        isNull,
      );
    });
  });

  group('phase machine', () {
    test('allows the documented transitions', () {
      expect(canTransitionMafiaPhase(MafiaPhase.setup, MafiaPhase.night), isTrue);
      expect(canTransitionMafiaPhase(MafiaPhase.night, MafiaPhase.day), isTrue);
      expect(canTransitionMafiaPhase(MafiaPhase.day, MafiaPhase.discussion), isTrue);
      expect(
        canTransitionMafiaPhase(MafiaPhase.discussion, MafiaPhase.voting),
        isTrue,
      );
      expect(
        canTransitionMafiaPhase(MafiaPhase.voting, MafiaPhase.night),
        isTrue,
      );
      expect(
        canTransitionMafiaPhase(MafiaPhase.resolution, MafiaPhase.finished),
        isTrue,
      );
    });

    test('rejects invalid jumps and treats finished as terminal', () {
      expect(
        canTransitionMafiaPhase(MafiaPhase.night, MafiaPhase.voting),
        isFalse,
      );
      expect(
        canTransitionMafiaPhase(MafiaPhase.finished, MafiaPhase.night),
        isFalse,
      );
      expect(MafiaPhase.finished.isTerminal, isTrue);
    });
  });

  group('night resolution', () {
    const roles = {
      'alice': MafiaRole.mafia,
      'bob': MafiaRole.civilian,
      'dana': MafiaRole.doctor,
      'eve': MafiaRole.detective,
    };
    const alive = {
      'alice': true,
      'bob': true,
      'dana': true,
      'eve': true,
    };

    test('mafia kill eliminates the target', () {
      final result = MafiaRules.resolveNight(
        roles: roles,
        alive: alive,
        kills: {'alice': 'bob'},
      );
      expect(result.eliminatedUserId, 'bob');
      expect(result.saved, isFalse);
    });

    test('doctor save prevents elimination', () {
      final result = MafiaRules.resolveNight(
        roles: roles,
        alive: alive,
        kills: {'alice': 'bob'},
        protect: 'bob',
      );
      expect(result.eliminatedUserId, isNull);
      expect(result.saved, isTrue);
    });

    test('tied mafia votes mean no kill', () {
      final six = {
        ...roles,
        'frank': MafiaRole.mafia,
        'gina': MafiaRole.civilian,
      };
      final living = {for (final id in six.keys) id: true};
      final result = MafiaRules.resolveNight(
        roles: six,
        alive: living,
        kills: {'alice': 'bob', 'frank': 'gina'},
      );
      expect(result.eliminatedUserId, isNull);
    });

    test('multiple doctor protects pick the lexicographically first target', () {
      expect(MafiaRules.resolveProtectTarget(['eve', 'bob']), 'bob');
    });
  });

  group('actions', () {
    test('civilians cannot submit night actions', () {
      expect(
        MafiaRules.canAct(
          role: MafiaRole.civilian,
          phase: MafiaPhase.night,
          isAlive: true,
          actionType: 'mafia_kill',
        ),
        isFalse,
      );
    });

    test('dead players cannot vote or act', () {
      expect(
        MafiaRules.canAct(
          role: MafiaRole.mafia,
          phase: MafiaPhase.night,
          isAlive: false,
          actionType: 'mafia_kill',
        ),
        isFalse,
      );
      expect(
        MafiaRules.canAct(
          role: MafiaRole.civilian,
          phase: MafiaPhase.voting,
          isAlive: false,
          actionType: 'mafia_vote',
        ),
        isFalse,
      );
    });

    test('night actions are rejected during voting', () {
      expect(
        MafiaRules.canAct(
          role: MafiaRole.detective,
          phase: MafiaPhase.voting,
          isAlive: true,
          actionType: 'mafia_investigate',
        ),
        isFalse,
      );
    });
  });

  group('voting', () {
    const roles = {
      'alice': MafiaRole.mafia,
      'bob': MafiaRole.civilian,
      'dana': MafiaRole.civilian,
      'eve': MafiaRole.civilian,
    };

    test('plurality eliminates the target', () {
      final result = MafiaRules.resolveVotes(
        roles: roles,
        alive: {for (final id in roles.keys) id: true},
        votes: {'bob': 'alice', 'dana': 'alice', 'eve': 'bob'},
      );
      expect(result.winnerId, 'alice');
      expect(result.tied, isFalse);
    });

    test('ties do not eliminate and ignore dead voters', () {
      final result = MafiaRules.resolveVotes(
        roles: roles,
        alive: {'alice': true, 'bob': true, 'dana': false, 'eve': true},
        votes: {'bob': 'alice', 'eve': 'bob', 'dana': 'alice'},
      );
      expect(result.winnerId, isNull);
      expect(result.tied, isTrue);
    });
  });

  group('win conditions', () {
    test('town wins when all mafia are dead', () {
      expect(
        MafiaRules.checkWinner(
          roles: {
            'alice': MafiaRole.mafia,
            'bob': MafiaRole.civilian,
            'dana': MafiaRole.civilian,
          },
          alive: {'alice': false, 'bob': true, 'dana': true},
        ),
        'town',
      );
    });

    test('mafia wins when they are no longer outnumbered', () {
      expect(
        MafiaRules.checkWinner(
          roles: {
            'alice': MafiaRole.mafia,
            'bob': MafiaRole.civilian,
            'dana': MafiaRole.civilian,
          },
          alive: {'alice': true, 'bob': true, 'dana': false},
        ),
        'mafia',
      );
    });

    test('does not declare a winner while town still outnumbers mafia', () {
      expect(
        MafiaRules.checkWinner(
          roles: {
            'alice': MafiaRole.mafia,
            'bob': MafiaRole.civilian,
            'dana': MafiaRole.civilian,
            'eve': MafiaRole.civilian,
          },
          alive: {for (final id in ['alice', 'bob', 'dana', 'eve']) id: true},
        ),
        isNull,
      );
    });
  });
}
