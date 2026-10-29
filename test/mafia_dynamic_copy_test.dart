import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/l10n/app_strings.dart';
import 'package:pubget/features/games/models/game_lifecycle.dart';
import 'package:pubget/features/games/models/game_models.dart';
import 'package:pubget/features/mafia/models/mafia_dynamic_copy.dart';

void main() {
  final ar = AppStrings.forLocale(const Locale('ar'));
  final en = AppStrings.forLocale(const Locale('en'));

  String nameOf(String id) => id == 'u1' ? 'سالم' : id;

  Map<String, dynamic> event(
    String type, [
    Map<String, dynamic> payload = const <String, dynamic>{},
  ]) => <String, dynamic>{
    'type': type,
    'payload': payload,
    // The English message the server also writes. It must never be shown.
    'message': 'EN $type',
  };

  test('every known Mafia log event resolves to localized copy, not the '
      'English message or the raw type token', () {
    final events = <Map<String, dynamic>>[
      event('GameCreated', {'minPlayers': 7}),
      event('GameStarting'),
      event('RolesAssigned', {'playersCount': 7, 'version': 'classic'}),
      event('MafiaStarted'),
      event('PhaseChanged', {'from': 'DAY', 'to': 'NIGHT'}),
      event('PlayerKilled', {'playerId': 'u1', 'role': 'mafia'}),
      event('NightResolved', {'nightNumber': 2, 'deathOccurred': true}),
      event('NightResolved', {'nightNumber': 3, 'deathOccurred': false}),
      event('PlayerEliminated', {'playerId': 'u1', 'role': 'citizen'}),
      event('VoteResolved', {'dayNumber': 1, 'voteRound': 1}),
      event('VoteTie', {'dayNumber': 1, 'voteRound': 1, 'tiedIds': <String>[]}),
      event('VoteTie', {
        'dayNumber': 1,
        'voteRound': 1,
        'tiedIds': <String>['u1', 'u2'],
      }),
      event('PlayerExecuted', {'playerId': 'u1', 'role': 'doctor'}),
      event('GameFinished', {'winner': 'mafias'}),
      event('Rewards', {'winner': 'mafias'}),
    ];
    for (final event in events) {
      final arabic = mafiaLogLine(ar, event, nameOf);
      final english = mafiaLogLine(en, event, nameOf);
      expect(arabic, isNotEmpty, reason: '${event['type']} produced no copy');
      expect(english, isNotEmpty, reason: '${event['type']} produced no copy');
      expect(
        arabic,
        isNot(equals('EN ${event['type']}')),
        reason: '${event['type']} leaked the English message',
      );
      expect(
        arabic,
        isNot(equals(event['type'])),
        reason: '${event['type']} leaked the raw type token',
      );
      expect(
        arabic,
        isNot(equals(english)),
        reason: '${event['type']} stayed English under Arabic',
      );
    }
  });

  test('event copy carries resolved names and localized roles', () {
    expect(
      mafiaLogLine(
        ar,
        event('PlayerExecuted', {'playerId': 'u1', 'role': 'doctor'}),
        nameOf,
      ),
      ar.mafiaLogExecuted('سالم', 'الطبيب'),
    );
    final tie = mafiaLogLine(
      ar,
      event('VoteTie', {
        'tiedIds': <String>['u1', 'u2'],
      }),
      nameOf,
    );
    expect(tie, contains('سالم'));
    expect(tie, contains('، '), reason: 'Arabic tie list must use "، "');
  });

  test('an unrecognized event type is dropped instead of shown raw', () {
    expect(mafiaLogLine(ar, event('SomethingNew'), nameOf), isEmpty);
    expect(mafiaLogLine(ar, const <String, dynamic>{'message': 'EN'}, nameOf), isEmpty);
  });

  test('a Mafia Failure maps to localized copy, never its English message', () {
    final cases = <Failure>[
      const NetworkError(),
      const PermissionError(),
      const NotFoundError(),
      const RateLimitedError(),
      const ValidationError(),
      const UnknownError(),
    ];
    for (final failure in cases) {
      final arabic = mafiaFailureMessage(ar, failure);
      expect(arabic, isNotEmpty);
      expect(
        arabic,
        isNot(equals(failure.message)),
        reason: '${failure.runtimeType} leaked the English Failure.message',
      );
      expect(
        arabic,
        isNot(equals(mafiaFailureMessage(en, failure))),
        reason: '${failure.runtimeType} stayed English under Arabic',
      );
    }
  });

  test('unknown phase/role tokens fall back to localized "Unknown"', () {
    expect(ar.mafiaPhaseLabel('NEW_PHASE'), ar.mafiaPhaseUnknown);
    expect(ar.mafiaRoleLabel('wizard'), ar.mafiaRoleUnknown);
    expect(ar.mafiaPhaseLabel(''), ar.mafiaPhaseUnknown);
    expect(ar.mafiaRoleLabel(''), ar.mafiaRoleUnknown);
    // Known values still translate.
    expect(ar.mafiaPhaseLabel('NIGHT'), 'الليل');
    expect(ar.mafiaRoleLabel('detective'), 'المحقق');
  });

  test('Detective/Don verdicts are localized in both directions', () {
    expect(ar.mafiaVerdict('Mafia'), 'مافيا');
    expect(ar.mafiaVerdict('Not Mafia'), 'ليس مافيا');
    expect(ar.mafiaVerdict('Detective'), 'المحقق');
    expect(ar.mafiaVerdict('Not Detective'), 'ليس المحقق');
    expect(en.mafiaVerdict('Mafia'), 'Mafia');
  });

  test('client Mafia draft validation matches the spec 7-player floor', () {
    // Regression: this mirrored 4, giving a start path the server rejects.
    final four = GameDraft(
      type: GameType.mafia,
      title: 'Mafia',
      groupId: 'g1',
      configuration: const GameConfiguration(minPlayers: 4),
    );
    final seven = four.copyWith(
      configuration: const GameConfiguration(minPlayers: 7),
    );
    expect(GameValidation.draft(four), isNotNull);
    expect(GameValidation.draft(seven), isNull);
  });
}
