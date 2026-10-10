import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/events/models/event_lifecycle.dart';
import 'package:pubget/features/events/models/event_models.dart';
import 'package:pubget/features/events/models/event_type_registry.dart';

void main() {
  test('PubgetEvent round-trips through toMap and fromMap', () {
    final original = PubgetEvent(
      id: 'e1',
      type: EventType.poll,
      creatorId: 'alice',
      groupId: 'g1',
      title: 'Best opening',
      description: 'Vote now',
      configuration: const EventConfiguration(
        question: 'Best opening?',
        options: <EventOption>[
          EventOption(id: 'opt-1', label: 'One'),
          EventOption(id: 'opt-2', label: 'Two'),
        ],
      ),
      status: EventStatus.active,
      startAt: DateTime.utc(2026, 9, 1, 12),
      endAt: DateTime.utc(2026, 9, 2, 12),
      participantsCount: 3,
      responsesCount: 2,
      tally: const EventTally(submissions: 2, votes: {'opt-1': 2}),
      result: null,
      createdAt: DateTime.utc(2026, 9, 1, 11),
      updatedAt: DateTime.utc(2026, 9, 1, 11),
      version: 1,
    );

    final restored = PubgetEvent.fromMap(original.toMap(), id: original.id);
    expect(restored.id, original.id);
    expect(restored.type, EventType.poll);
    expect(restored.title, 'Best opening');
    expect(restored.configuration.options, hasLength(2));
    expect(restored.status, EventStatus.active);
    expect(restored.tally.votes['opt-1'], 2);
  });

  test('ranking results preserve aggregate option order', () {
    final result = EventResult(
      kind: 'ranking',
      submissions: 3,
      scores: const <String, int>{'a': 9, 'b': 12, 'c': 4},
      orderedOptionIds: const <String>['b', 'a', 'c'],
    );

    final restored = EventResult.fromMap(<String, dynamic>{
      'kind': result.kind,
      'submissions': result.submissions,
      'scores': result.scores,
      'orderedOptionIds': result.orderedOptionIds,
    });

    expect(restored.orderedOptionIds, <String>['b', 'a', 'c']);
  });

  test('invalid maps fall back to safe defaults', () {
    final event = PubgetEvent.fromMap(const <String, dynamic>{}, id: 'missing');
    expect(event.type, EventType.poll);
    expect(event.status, EventStatus.draft);
    expect(event.title, isEmpty);
  });

  test('lifecycle allows the published path and rejects archive revival', () {
    expect(
      EventLifecycle.canTransition(EventStatus.draft, EventStatus.active),
      isTrue,
    );
    expect(
      EventLifecycle.canTransition(EventStatus.active, EventStatus.ended),
      isTrue,
    );
    expect(
      EventLifecycle.canTransition(EventStatus.ended, EventStatus.archived),
      isTrue,
    );
    expect(
      EventLifecycle.canTransition(EventStatus.archived, EventStatus.active),
      isFalse,
    );
    expect(
      EventLifecycle.canTransition(EventStatus.cancelled, EventStatus.active),
      isFalse,
    );
  });

  test('duration validation accepts 7 days and rejects longer windows', () {
    final start = DateTime.utc(2026, 9, 1);
    expect(
      EventLifecycle.validateWindow(
        start,
        start.add(EventLifecycle.maxDuration),
      ),
      isNull,
    );
    expect(
      EventLifecycle.validateWindow(
        start,
        start.add(EventLifecycle.maxDuration + const Duration(milliseconds: 1)),
      ),
      isNotNull,
    );
    expect(EventLifecycle.validateWindow(start, start), isNotNull);
  });

  test('expired active events are not interactable', () {
    final now = DateTime.utc(2026, 9, 2);
    final event = PubgetEvent(
      id: 'e1',
      type: EventType.poll,
      creatorId: 'alice',
      groupId: 'g1',
      title: 'Vote',
      description: '',
      configuration: const EventConfiguration(
        question: 'Best?',
        options: <EventOption>[
          EventOption(id: 'opt-1', label: 'One'),
          EventOption(id: 'opt-2', label: 'Two'),
        ],
      ),
      status: EventStatus.active,
      startAt: DateTime.utc(2026, 8, 1),
      endAt: DateTime.utc(2026, 8, 2),
      participantsCount: 1,
      responsesCount: 1,
      tally: const EventTally(),
      result: null,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    );
    expect(event.isExpired(now), isTrue);
    expect(event.isInteractable(now), isFalse);
    expect(event.isReadOnly, isFalse);
  });

  test('templates map onto real event types', () {
    expect(EventTypeRegistry.templates['animeBattle'], EventType.versus);
    expect(EventTypeRegistry.templates['guessCharacter'], EventType.quiz);
    expect(EventTypeRegistry.of(EventType.ranking).usesRanking, isTrue);
  });

  test('draft validation requires a group, title, and valid configuration', () {
    expect(EventValidation.draft(const EventDraft()), isNotNull);
    expect(
      EventValidation.draft(
        EventDraft(groupId: 'g1', title: 'Vote', startAt: DateTime.now()),
      ),
      isNotNull,
    );
    expect(
      EventValidation.draft(
        EventDraft(
          groupId: 'g1',
          title: 'Vote',
          startAt: DateTime.now(),
          configuration: const EventConfiguration(
            question: 'Q',
            options: <EventOption>[
              EventOption(
                id: 'opt-1',
                label: 'A',
                imageUrl: 'https://cdn.example.com/a.png',
              ),
              EventOption(
                id: 'opt-2',
                label: 'B',
                imageUrl: 'https://cdn.example.com/b.png',
              ),
            ],
          ),
        ),
      ),
      isNull,
    );
  });

  test('quiz validation requires prompts, answers, and a correct option', () {
    expect(
      EventValidation.configuration(EventType.quiz, const EventConfiguration()),
      isNotNull,
    );
    expect(
      EventValidation.configuration(
        EventType.quiz,
        const EventConfiguration(
          questions: <EventQuizQuestion>[
            EventQuizQuestion(
              id: 'q-1',
              prompt: 'Who?',
              options: <EventOption>[
                EventOption(id: 'opt-1', label: 'A'),
                EventOption(id: 'opt-2', label: 'B'),
              ],
              correctOptionId: 'opt-2',
            ),
            EventQuizQuestion(
              id: 'q-2',
              prompt: 'Where?',
              options: <EventOption>[
                EventOption(id: 'opt-1', label: 'X'),
                EventOption(id: 'opt-2', label: 'Y'),
                EventOption(id: 'opt-3', label: 'Z'),
              ],
              correctOptionId: 'opt-1',
            ),
          ],
        ),
      ),
      isNull,
    );
  });

  test('quiz questions round-trip per-question seconds timers', () {
    final question = EventQuizQuestion(
      id: 'q-1',
      prompt: 'Who?',
      options: const <EventOption>[
        EventOption(id: 'opt-1', label: 'A'),
        EventOption(id: 'opt-2', label: 'B'),
      ],
      correctOptionId: 'opt-2',
      seconds: 45,
    );
    final restored = EventQuizQuestion.fromMap(question.toMap(), index: 0);
    expect(restored.seconds, 45);
    expect(restored.prompt, 'Who?');

    final noTimer = EventQuizQuestion.fromMap(
      const EventQuizQuestion(
        id: 'q-2',
        prompt: 'Where?',
        options: <EventOption>[EventOption(id: 'opt-1', label: 'X')],
        correctOptionId: 'opt-1',
      ).toMap(),
      index: 0,
    );
    expect(noTimer.seconds, 0);
  });

  test('comparison events require canonical candidates', () {
    expect(
      EventValidation.configuration(
        EventType.characterComparison,
        const EventConfiguration(
          criterion: 'Who wins?',
          options: <EventOption>[
            EventOption(id: 'luffy', label: 'luffy', characterId: 'luffy'),
            EventOption(id: 'naruto', label: 'naruto', characterId: 'naruto'),
          ],
        ),
      ),
      isNull,
    );
    expect(
      EventValidation.configuration(
        EventType.characterComparison,
        const EventConfiguration(
          criterion: 'Who wins?',
          options: <EventOption>[
            EventOption(id: 'luffy', label: 'luffy', characterId: 'luffy'),
            EventOption(id: 'luffy-2', label: 'luffy', characterId: 'luffy'),
          ],
        ),
      ),
      isNotNull,
    );
  });

  test('theory stances and anime links round-trip through the event map', () {
    final original = PubgetEvent(
      id: 'e-theory',
      type: EventType.theory,
      creatorId: 'alice',
      groupId: null,
      title: 'The silk trade',
      description: 'It never collapsed.',
      configuration: const EventConfiguration(
        anime: EventAnimeLink(
          animeId: 'mal-123',
          title: 'Spice and Wolf',
          imageUrl: 'https://cdn.example.com/wolf.jpg',
        ),
      ),
      status: EventStatus.ended,
      startAt: DateTime.utc(2026, 9, 1),
      endAt: DateTime.utc(2026, 9, 2),
      participantsCount: 2,
      responsesCount: 2,
      tally: const EventTally(
        submissions: 2,
        stances: <String, int>{'agree': 1, 'disagree': 1},
      ),
      result: const EventResult(
        kind: 'theory',
        submissions: 2,
        stances: <String, int>{'agree': 1, 'disagree': 1},
      ),
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );

    final restored = PubgetEvent.fromMap(original.toMap(), id: original.id);
    expect(restored.configuration.anime?.animeId, 'mal-123');
    expect(restored.configuration.anime?.title, 'Spice and Wolf');
    expect(restored.configuration.anime?.imageUrl, isNotEmpty);
    expect(restored.tally.stances['agree'], 1);
    expect(restored.result?.stances['disagree'], 1);
  });

  test('a scheduled-but-live event is not interactable before its start', () {
    final now = DateTime.utc(2026, 9, 2, 12);
    final event = PubgetEvent(
      id: 'e1',
      type: EventType.poll,
      creatorId: 'alice',
      groupId: null,
      title: 'Vote',
      description: '',
      configuration: const EventConfiguration(),
      status: EventStatus.active,
      startAt: DateTime.utc(2026, 9, 3, 12),
      endAt: DateTime.utc(2026, 9, 4, 12),
      participantsCount: 0,
      responsesCount: 0,
      tally: const EventTally(),
      result: null,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );
    expect(event.isExpired(now), isFalse);
    expect(event.isInteractable(now), isFalse);

    final started = PubgetEvent(
      id: event.id,
      type: EventType.poll,
      creatorId: event.creatorId,
      groupId: event.groupId,
      title: event.title,
      description: event.description,
      configuration: event.configuration,
      status: EventStatus.active,
      startAt: DateTime.utc(2026, 9, 1),
      endAt: DateTime.utc(2026, 9, 4, 12),
      participantsCount: event.participantsCount,
      responsesCount: event.responsesCount,
      tally: event.tally,
      result: event.result,
      createdAt: event.createdAt,
      updatedAt: event.updatedAt,
    );
    expect(started.isInteractable(now), isTrue);
  });

  test('event creation quota maps remaining allowance and exhaustion', () {
    final quota = EventCreationQuota.fromMap(const <String, dynamic>{
      'count': 2,
      'limit': 2,
      'day': '2026-09-02',
      'remaining': 0,
    });
    expect(quota.limit, 2);
    expect(quota.remaining, 0);
    expect(quota.exhausted, isTrue);

    expect(
      EventCreationQuota.fromMap(const <String, dynamic>{}).exhausted,
      isTrue,
    );
    expect(
      EventCreationQuota.fromMap(const <String, dynamic>{'remaining': 2})
          .exhausted,
      isFalse,
    );
  });

  test('publish validation requires a theory body and a valid anime', () {
    expect(
      EventValidation.publish(
        EventDraft(
          scope: EventScope.global,
          type: EventType.theory,
          title: 'Theory',
        ),
      ),
      'ev.theoryBodyRequired',
    );
    expect(
      EventValidation.publish(
        EventDraft(
          scope: EventScope.global,
          type: EventType.theory,
          title: 'Theory',
          description: 'A body.',
          configuration: const EventConfiguration(
            anime: EventAnimeLink(
              animeId: 'mal-1',
              title: 'Title',
              imageUrl: 'javascript:alert(1)',
            ),
          ),
        ),
      ),
      'ev.animeInvalid',
    );
    expect(
      EventValidation.publish(
        EventDraft(
          scope: EventScope.global,
          type: EventType.theory,
          title: 'Theory',
          description: 'A body.',
        ),
      ),
      isNull,
    );
  });
}
