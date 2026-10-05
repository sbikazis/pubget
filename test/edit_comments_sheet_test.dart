import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/features/edits/models/edit_models.dart';
import 'package:pubget/features/edits/providers/edits_provider.dart';
import 'package:pubget/features/edits/repositories/edits_repository.dart';
import 'package:pubget/features/edits/widgets/edit_comments_sheet.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';

import 'authentication_test_support.dart';
import 'edits_test_support.dart';

/// Axis 15 §15 — comment reactions must be real controls.
///
/// The heart used to always render the outline icon, could only ever send
/// `like` (never `unlike`), and never moved the count, so tapping it looked
/// broken. These tests pin the toggle and the optimistic rollback.
void main() {
  Future<void> pumpSheet(
    WidgetTester tester,
    FakeEditsRepository repository,
  ) async {
    final authRepository = FakeAuthRepository(
      user: const AuthUser(id: 'user-1', email: 'fan@example.com'),
    );
    final auth = AuthProvider(repository: authRepository);
    await auth.initialize();
    addTearDown(authRepository.close);
    addTearDown(auth.dispose);
    final provider = EditsProvider(repository: repository);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<EditsProvider>.value(value: provider),
          Provider<EditsRepository>.value(value: repository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => EditCommentsSheet.show(context, testEdit()),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the heart starts unliked and shows the stored count', (tester) async {
    final repository = FakeEditsRepository(
      comments: <EditComment>[
        EditComment(
          id: 'c1',
          authorId: 'bob',
          text: 'Insane timing',
          likesCount: 3,
          createdAt: DateTime(2026, 8, 2),
        ),
      ],
    );
    await pumpSheet(tester, repository);

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.textContaining('3 likes'), findsOneWidget);
  });

  testWidgets('tapping the heart likes, then unlikes, and moves the count', (tester) async {
    final repository = FakeEditsRepository(
      comments: <EditComment>[
        EditComment(
          id: 'c1',
          authorId: 'bob',
          text: 'Insane timing',
          likesCount: 3,
          createdAt: DateTime(2026, 8, 2),
        ),
      ],
    );
    await pumpSheet(tester, repository);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.textContaining('4 likes'), findsOneWidget);
    expect(
      repository.commentActionCalls.map((c) => c['action']),
      <String>['like'],
      reason: 'the first tap must send like',
    );

    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.textContaining('3 likes'), findsOneWidget);
    expect(
      repository.commentActionCalls.map((c) => c['action']),
      <String>['like', 'unlike'],
      reason: 'the second tap must send unlike, not like again',
    );
  });

  testWidgets('a failed like rolls the heart and the count back', (tester) async {
    final repository = FakeEditsRepository(
      comments: <EditComment>[
        EditComment(
          id: 'c1',
          authorId: 'bob',
          text: 'Insane timing',
          likesCount: 3,
          createdAt: DateTime(2026, 8, 2),
        ),
      ],
    )..commentActionFailure = NetworkError(const SocketException('offline').toString());
    await pumpSheet(tester, repository);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    // Rolled back to the server truth, not left showing an optimistic lie.
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.textContaining('3 likes'), findsOneWidget);
  });
}