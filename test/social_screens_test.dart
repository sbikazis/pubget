import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/social/models/social_models.dart';
import 'package:pubget/features/social/providers/profile_provider.dart';
import 'package:pubget/features/social/providers/social_provider.dart';
import 'package:pubget/features/social/screens/friend_requests_page.dart';
import 'package:pubget/features/social/screens/profile_page.dart';

import 'authentication_test_support.dart';
import 'social_test_support.dart';

void main() {
  testWidgets('viewer profile offers respect and friend actions', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(
      user: const AuthUser(id: 'user-1', email: 'fan@example.com'),
    );
    final auth = AuthProvider(repository: authRepository);
    await auth.initialize();
    addTearDown(authRepository.close);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ProfileProvider>(
            create: (_) => ProfileProvider(repository: FakeProfileRepository()),
          ),
          ChangeNotifierProvider<SocialProvider>(
            create: (_) => SocialProvider(repository: FakeSocialRepository()),
          ),
        ],
        child: const MaterialApp(home: ProfilePage(userId: 'user-2')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('other_fan'), findsOneWidget);
    expect(find.byKey(const Key('profile-give-respect')), findsOneWidget);
    expect(find.byKey(const Key('profile-add-friend')), findsOneWidget);
    expect(find.byKey(const Key('profile-block-user')), findsOneWidget);
    expect(find.byKey(const Key('profile-start-chat')), findsNothing);

    await tester.tap(find.byKey(const Key('profile-block-user')));
    await tester.pumpAndSettle();
    expect(find.text('Block this user?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Block'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(PubgetSecondaryButton, 'Unblock user'),
      findsOneWidget,
    );
  });

  testWidgets('friend requests renders an actionable incoming request', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(
      user: const AuthUser(id: 'user-1', email: 'fan@example.com'),
    );
    final auth = AuthProvider(repository: authRepository);
    await auth.initialize();
    addTearDown(authRepository.close);
    addTearDown(auth.dispose);
    final socialRepository = FakeSocialRepository(
      snapshot: const SocialSnapshot(
        friendships: <Friendship>[
          Friendship(
            userA: 'user-1',
            userB: 'user-2',
            status: FriendshipStatus.pending,
            requestedBy: 'user-2',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<SocialProvider>(
            create: (_) => SocialProvider(repository: socialRepository),
          ),
        ],
        child: const MaterialApp(home: FriendRequestsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Friend request'), findsOneWidget);
    expect(find.byTooltip('Accept request'), findsOneWidget);
    expect(find.byTooltip('Reject request'), findsOneWidget);
  });

  testWidgets('start chat is offered only when Fan or Friend exists', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(
      user: const AuthUser(id: 'user-1', email: 'fan@example.com'),
    );
    final auth = AuthProvider(repository: authRepository);
    await auth.initialize();
    addTearDown(authRepository.close);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ProfileProvider>(
            create: (_) => ProfileProvider(repository: FakeProfileRepository()),
          ),
          ChangeNotifierProvider<SocialProvider>(
            create: (_) => SocialProvider(
              repository: FakeSocialRepository(
                snapshot: const SocialSnapshot(
                  friendships: <Friendship>[
                    Friendship(
                      userA: 'user-1',
                      userB: 'user-2',
                      status: FriendshipStatus.accepted,
                      requestedBy: 'user-1',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: ProfilePage(userId: 'user-2')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-start-chat')), findsOneWidget);
  });
}
