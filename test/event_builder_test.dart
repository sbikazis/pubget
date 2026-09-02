import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/events/models/event_models.dart';
import 'package:pubget/features/events/models/event_type_registry.dart';
import 'package:pubget/features/events/providers/event_providers.dart';
import 'package:pubget/features/events/repositories/event_repository.dart';
import 'package:pubget/features/events/screens/event_builder_page.dart';

import 'authentication_test_support.dart';

void main() {
  testWidgets('quiz builder can add, edit, and remove questions', (
    tester,
  ) async {
    final repository = _FakeEventRepository();
    final auth = AuthProvider(
      repository: FakeAuthRepository(
        user: const AuthUser(id: 'alice', email: 'alice@example.com'),
      ),
    );
    await auth.initialize();
    final builder = EventBuilderProvider(repository: repository);
    addTearDown(auth.dispose);
    addTearDown(builder.dispose);

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<EventBuilderProvider>.value(value: builder),
        ],
        child: const MaterialApp(
          home: EventBuilderPage(groupId: 'g1', templateId: 'guessCharacter'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Configure'));
    await tester.pumpAndSettle();

    expect(find.text('Question 1'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Who?');
    await tester.ensureVisible(find.text(EventStrings.addQuestion));
    await tester.tap(find.text(EventStrings.addQuestion));
    await tester.pumpAndSettle();
    expect(find.text('Question 2'), findsOneWidget);

    await tester.tap(find.byTooltip(EventStrings.removeQuestion).last);
    await tester.pumpAndSettle();
    expect(find.text('Question 2'), findsNothing);
    expect(find.text('Question 1'), findsOneWidget);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text(EventStrings.saveDraft), findsOneWidget);
  });
}

final class _FakeEventRepository implements EventRepository {
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
  Future<Result<void>> join(String eventId) async => const Success<void>(null);

  @override
  Future<Result<void>> leave(String eventId) async => const Success<void>(null);

  @override
  Future<Result<PubgetEvent>> publish({
    required String eventId,
    required DateTime startAt,
    required DateTime endAt,
  }) async => FailureResult(UnknownError('unused'));

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
  }) async => const Success<void>(null);

  @override
  Stream<Result<PubgetEvent>> watchEvent(String eventId) =>
      const Stream<Result<PubgetEvent>>.empty();
}
