import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/events/models/event_models.dart';
import 'package:pubget/features/events/providers/event_providers.dart';
import 'package:pubget/features/events/repositories/event_repository.dart';

void main() {
  test('duplicate submit is ignored while a request is in flight', () async {
    final repository = _FakeEventRepository();
    final provider = EventProvider(repository: repository);
    addTearDown(provider.dispose);

    final first = provider.submit(
      eventId: 'e1',
      responseData: const <String, dynamic>{'optionId': 'opt-1'},
    );
    final second = await provider.submit(
      eventId: 'e1',
      responseData: const <String, dynamic>{'optionId': 'opt-2'},
    );
    expect(second, isA<FailureResult<void>>());
    repository.submitCompleter.complete(const Success<void>(null));
    final completed = await first;
    expect(completed.isSuccess, isTrue);
    expect(provider.hasSubmitted, isTrue);
    expect(repository.submitCalls, 1);
  });

  test(
    'failed submit surfaces a retryable failure and is not treated as success',
    () async {
      final repository = _FakeEventRepository();
      final provider = EventProvider(repository: repository);
      addTearDown(provider.dispose);

      final operation = provider.submit(
        eventId: 'e1',
        responseData: const <String, dynamic>{'optionId': 'opt-1'},
      );
      repository.submitCompleter.complete(
        const FailureResult(NetworkError('offline')),
      );
      final result = await operation;
      expect(result, isA<FailureResult<void>>());
      expect(provider.hasSubmitted, isFalse);
      expect(provider.failure, isA<NetworkError>());
      expect(provider.submitting, isFalse);
    },
  );

  test('join is not marked successful until the repository succeeds', () async {
    final repository = _FakeEventRepository();
    final provider = EventProvider(repository: repository);
    addTearDown(provider.dispose);
    repository.joinResult = const FailureResult(PermissionError());
    final result = await provider.join('e1');
    expect(result, isA<FailureResult<void>>());
    expect(repository.joinCalls, 1);
  });

  test('builder publish is blocked when a quiz has no questions', () async {
    final repository = _FakeEventRepository();
    final provider = EventBuilderProvider(repository: repository);
    addTearDown(provider.dispose);
    provider.start(groupId: 'g1');
    provider.update(
      provider.draft.copyWith(
        type: EventType.quiz,
        title: 'Guess',
        configuration: const EventConfiguration(),
      ),
    );
    final result = await provider.publish();
    expect(result, isA<FailureResult<PubgetEvent>>());
    expect(repository.publishCalls, 0);
  });

  test('builder publish is blocked when the duration exceeds 7 days', () async {
    final repository = _FakeEventRepository();
    final provider = EventBuilderProvider(repository: repository);
    addTearDown(provider.dispose);
    provider.start(groupId: 'g1');
    final start = DateTime.now();
    provider.update(
      provider.draft.copyWith(
        title: 'Long',
        startAt: start,
        endAt: start.add(const Duration(days: 8)),
        configuration: const EventConfiguration(
          question: 'Q',
          options: <EventOption>[
            EventOption(id: 'opt-1', label: 'A'),
            EventOption(id: 'opt-2', label: 'B'),
          ],
        ),
      ),
    );
    final result = await provider.publish();
    expect(result, isA<FailureResult<PubgetEvent>>());
    expect(repository.publishCalls, 0);
  });

  test('list loadHome stays loaded when every bucket is empty', () async {
    final repository = _FakeEventRepository();
    final provider = EventListProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.loadHome();
    expect(provider.state, LoadingState.loaded);
    expect(provider.active, isEmpty);
  });
}

final class _FakeEventRepository implements EventRepository {
  final submitCompleter = Completer<Result<void>>();
  Result<void> joinResult = const Success<void>(null);
  int submitCalls = 0;
  int joinCalls = 0;
  int publishCalls = 0;

  @override
  Future<Result<void>> archive(String eventId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> cancel(String eventId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> deleteDraft(String eventId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> end(String eventId) async => const Success<void>(null);

  @override
  Future<Result<List<PubgetEvent>>> getActiveEvents({int limit = 20}) async =>
      const Success(<PubgetEvent>[]);

  @override
  Future<Result<List<PubgetEvent>>> getGroupEvents({
    required String groupId,
    int limit = 20,
  }) async => const Success(<PubgetEvent>[]);

  @override
  Future<Result<List<PubgetEvent>>> getMyDrafts({
    required String userId,
  }) async => const Success(<PubgetEvent>[]);

  @override
  Future<Result<List<PubgetEvent>>> getMyEvents({
    required String userId,
    int limit = 20,
  }) async => const Success(<PubgetEvent>[]);

  @override
  Future<Result<EventResponse?>> getMyResponse({
    required String eventId,
    required String userId,
  }) async => const Success<EventResponse?>(null);

  @override
  Future<Result<List<PubgetEvent>>> getRecentEvents({int limit = 20}) async =>
      const Success(<PubgetEvent>[]);

  @override
  Future<Result<List<PubgetEvent>>> getUpcomingEvents({int limit = 20}) async =>
      const Success(<PubgetEvent>[]);

  @override
  Future<Result<void>> join(String eventId) async {
    joinCalls += 1;
    return joinResult;
  }

  @override
  Future<Result<void>> leave(String eventId) async => const Success<void>(null);

  @override
  Future<Result<PubgetEvent>> publish({
    required String eventId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    publishCalls += 1;
    return FailureResult(ValidationError('not used'));
  }

  @override
  Future<Result<String>> saveDraft(EventDraft draft) async =>
      const Success('draft-1');

  @override
  Future<Result<List<PubgetEvent>>> search(String query) async =>
      const Success(<PubgetEvent>[]);

  @override
  Future<Result<void>> submit({
    required String eventId,
    required Map<String, dynamic> responseData,
  }) {
    submitCalls += 1;
    return submitCompleter.future;
  }

  @override
  Stream<Result<PubgetEvent>> watchEvent(String eventId) =>
      const Stream<Result<PubgetEvent>>.empty();
}
