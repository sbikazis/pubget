import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/edits/models/edit_models.dart';
import 'package:pubget/features/social/providers/social_provider.dart';
import 'package:pubget/features/social/widgets/give_respect_sheet.dart';

import 'authentication_test_support.dart';
import 'social_test_support.dart';

void main() {
  test('edit models surface flagged rejection and respect eligibility', () {
    final flagged = Edit.fromMap(
      <String, dynamic>{
        'creatorId': 'alice',
        'caption': 'crypto giveaway',
        'status': 'rejected',
        'moderationStatus': 'flagged',
        'moderationReason': 'Caption or tag contains prohibited language.',
      },
      id: 'e1',
    );
    expect(flagged.status, 'rejected');
    expect(flagged.moderationStatus, 'flagged');
    expect(flagged.canReceiveRespectFrom('alice'), isFalse);
    expect(flagged.canReceiveRespectFrom('bob'), isTrue);
    expect(
      Edit.uploadTerminalFailure(
        status: 'rejected',
        moderationReason: flagged.moderationReason,
      )?.message,
      'Caption or tag contains prohibited language.',
    );
    expect(Edit.uploadTerminalFailure(status: 'published'), isNull);
  });

  test('social giveRespect from an edit still blocks self and out-of-range', () async {
    final repository = FakeSocialRepository();
    final provider = SocialProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.load('user-1');

    expect(
      (await provider.giveRespect(toUserId: 'user-1', value: 5)).failureOrNull,
      isA<ValidationError>(),
    );
    expect(repository.respectCalls, 0);
    expect(
      (await provider.giveRespect(toUserId: 'creator-2', value: 8)).failureOrNull,
      isA<ValidationError>(),
    );
    expect(repository.respectCalls, 0);
    expect(
      (await provider.giveRespect(toUserId: 'creator-2', value: 5)).isSuccess,
      isTrue,
    );
    expect(repository.respectCalls, 1);
  });

  testWidgets('edit respect sheet grants through the existing social path', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(
      user: const AuthUser(id: 'user-1', email: 'fan@example.com'),
    );
    final auth = AuthProvider(repository: authRepository);
    await auth.initialize();
    addTearDown(authRepository.close);
    addTearDown(auth.dispose);
    final socialRepository = FakeSocialRepository();
    final social = SocialProvider(repository: socialRepository);
    addTearDown(social.dispose);
    social.bindUser('user-1');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<SocialProvider>.value(value: social),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showGiveRespectSheet(
                context,
                toUserId: 'creator-2',
                initialValue: 5,
              ),
              child: const Text('Open respect'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open respect'));
    await tester.pumpAndSettle();
    expect(find.text('منح الاحترام'), findsOneWidget);
    await tester.tap(find.byKey(const Key('edit-give-respect')));
    await tester.pump();
    // Sheet closes optimistically; server call continues in background.
    await tester.pump(const Duration(milliseconds: 50));
    expect(socialRepository.respectCalls, 1);
  });
}
