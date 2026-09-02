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
              EventOption(id: 'opt-1', label: 'A'),
              EventOption(id: 'opt-2', label: 'B'),
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
}
