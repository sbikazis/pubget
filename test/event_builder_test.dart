import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/events/models/event_models.dart';
import 'package:pubget/features/events/providers/event_providers.dart';
import 'package:pubget/features/events/repositories/event_repository.dart';
import 'package:pubget/features/events/screens/event_builder_page.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/repositories/unavailable_group_repositories.dart';

import 'authentication_test_support.dart';

void main() {
  testWidgets('poll builder can add and remove options', (tester) async {
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
          // Group events resolve the target group from this provider; the
          // builder is exercised with a group already in context.
          ChangeNotifierProvider<GroupProvider>(
            create: (_) => GroupProvider(
              repository: UnavailableGroupRepository('no group backend'),
            ),
          ),
        ],
        child: const MaterialApp(
          home: EventBuilderPage(groupId: 'g1', templateId: 'guessCharacter'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scope and type are locked by the template, so two Continues land on the
    // content step, where the poll options are edited.
    await tester.tap(find.byKey(const Key('create-continue')).hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-continue')).hitTestable());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-poll-question')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('create-poll-question')),
      'Which arc?',
    );
    await tester.enterText(
      find.byKey(const Key('create-title')),
      'Arc poll',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-option-0')), findsOneWidget);
    expect(find.byKey(const Key('create-option-1')), findsOneWidget);

    // The Stepper lays its controls over the step body on the test surface, so
    // the option buttons are driven through their callbacks.
    tester
        .widget<PubgetTextButton>(find.byKey(const Key('create-add-option')))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-option-2')), findsOneWidget);

    tester
        .widget<IconButton>(find.byKey(const Key('create-remove-option-2')))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-option-2')), findsNothing);
    expect(find.byKey(const Key('create-option-1')), findsOneWidget);
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
  Future<Result<List<PubgetEvent>>> getActiveEvents({PubgetEvent? after, int limit = 20}) async =>
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
  Future<Result<List<PubgetEvent>>> getRecentEvents({PubgetEvent? after, int limit = 20}) async =>
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
  Future<Result<EventCreationQuota>> getCreationQuota() async =>
      const Success(EventCreationQuota(count: 0, limit: 2, remaining: 2));

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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
