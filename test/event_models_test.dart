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

  test('templates map onto real event types', () {
    expect(EventTypeRegistry.templates['animeBattle'], EventType.versus);
    expect(EventTypeRegistry.templates['guessCharacter'], EventType.quiz);
    expect(EventTypeRegistry.of(EventType.ranking).usesRanking, isTrue);
  });

  test('draft validation requires a group and a title', () {
    expect(EventValidation.draft(const EventDraft()), isNotNull);
    expect(
      EventValidation.draft(
        EventDraft(groupId: 'g1', title: 'Vote', startAt: DateTime.now()),
      ),
      isNull,
    );
  });
}
