import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/anime/models/anime_list_models.dart';
import 'package:pubget/features/anime/providers/anime_library_provider.dart';
import 'package:pubget/features/anime/repositories/anime_library_repository.dart';
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
          ChangeNotifierProvider<AnimeLibraryProvider>(
            create: (_) => AnimeLibraryProvider(
              repository: _FakeAnimeLibraryRepository(),
            ),
          ),
        ],
        child: const MaterialApp(home: ProfilePage(userId: 'user-2')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('other_fan'), findsOneWidget);
    expect(find.byKey(const Key('profile-give-respect')), findsOneWidget);
    await _scrollProfileTo(tester, const Key('profile-add-friend'));
    expect(find.byKey(const Key('profile-add-friend')), findsOneWidget);
    await _scrollProfileTo(tester, const Key('profile-block-user'));
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

  testWidgets(
    'friend requests page lists outgoing requests with a cancel action',
    (tester) async {
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
              userB: 'user-3',
              status: FriendshipStatus.pending,
              requestedBy: 'user-1',
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

      expect(find.text('Outgoing requests'), findsOneWidget);
      expect(find.text('Request sent'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cancel-request')));
      await tester.pumpAndSettle();
      expect(socialRepository.cancelFriendRequestCalls, 1);
      expect(socialRepository.snapshot.outgoingFor('user-1'), isEmpty);
    },
  );

  testWidgets('start chat is offered only when Friend or mutual Fan exists', (
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
          ChangeNotifierProvider<AnimeLibraryProvider>(
            create: (_) => AnimeLibraryProvider(
              repository: _FakeAnimeLibraryRepository(),
            ),
          ),
        ],
        child: const MaterialApp(home: ProfilePage(userId: 'user-2')),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollProfileTo(tester, const Key('profile-start-chat'));
    expect(find.byKey(const Key('profile-start-chat')), findsOneWidget);
  });
}

Future<void> _scrollProfileTo(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  for (var i = 0; i < 10; i++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(find.byType(ListView).first, const Offset(0, -280));
    await tester.pumpAndSettle();
  }
}

/// Empty anime library: profile screens only need the provider present.
/// With no entries and no custom lists the anime section renders nothing,
/// so existing profile assertions are unaffected.
final class _FakeAnimeLibraryRepository implements AnimeLibraryRepository {
  @override
  Future<Result<AnimeListPage>> getList({
    AnimeListStatus? status,
    String? cursor,
    int limit = 20,
  }) async => const Success<AnimeListPage>(AnimeListPage());

  @override
  Future<Result<AnimeListEntry>> setEntry({
    required String animeId,
    required AnimeListStatus status,
    String title = '',
    int? rating,
    bool? favorite,
  }) async => Success<AnimeListEntry>(
    AnimeListEntry(
      animeId: animeId,
      status: status,
      title: title,
      rating: rating,
      favorite: favorite ?? false,
    ),
  );

  @override
  Future<Result<void>> removeEntry(String animeId) async =>
      const Success<void>(null);

  @override
  Future<Result<List<CharacterFavorite>>> getCharacterFavorites() async =>
      const Success<List<CharacterFavorite>>(<CharacterFavorite>[]);

  @override
  Future<Result<CharacterFavorite>> setCharacterFavorite({
    required String characterId,
    required bool favorite,
    String name = '',
    String? imageUrl,
    int? rating,
  }) async => Success<CharacterFavorite>(CharacterFavorite(characterId: characterId));

  @override
  Future<Result<List<AnimeCustomList>>> getCustomLists({String? userId}) async =>
      const Success<List<AnimeCustomList>>(<AnimeCustomList>[]);

  @override
  Future<Result<AnimeCustomListDetail>> getCustomList({
    required String listId,
    String? userId,
  }) async => Success<AnimeCustomListDetail>(
    AnimeCustomListDetail(list: AnimeCustomList(id: listId, name: '')),
  );

  @override
  Future<Result<AnimeCustomList>> createCustomList({
    required String name,
    String description = '',
    bool private = false,
    List<String> animeIds = const <String>[],
  }) async => Success<AnimeCustomList>(AnimeCustomList(id: 'list-1', name: name));

  @override
  Future<Result<void>> updateCustomList({
    required String listId,
    String? name,
    String? description,
    bool? private,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> deleteCustomList(String listId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> addToCustomList({
    required String listId,
    required String animeId,
    String title = '',
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> removeFromCustomList({
    required String listId,
    required String animeId,
  }) async => const Success<void>(null);

  @override
  Future<Result<List<CustomListMembership>>> getCustomListMembership(
    String animeId,
  ) async => const Success<List<CustomListMembership>>(
    <CustomListMembership>[],
  );
}
