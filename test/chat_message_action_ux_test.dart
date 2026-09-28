import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/groups/providers/chat_provider.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/screens/group_chat_page.dart';
import 'package:pubget/features/groups/widgets/chat_message_actions_overlay.dart';
import 'package:pubget/features/groups/services/chat_audio_player.dart';
import 'package:pubget/features/private_chat/providers/private_chat_list_provider.dart';
import 'package:pubget/features/private_chat/providers/private_chat_provider.dart';
import 'package:pubget/features/private_chat/repositories/unavailable_private_chat_repository.dart';
import 'package:pubget/features/private_chat/screens/private_chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'authentication_test_support.dart';
import 'chat_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('newestPinnedMessage', () {
    test('returns the most recently pinned live message', () {
      final messages = <ChatMessage>[
        textMessage('a', 'older', pinnedAt: DateTime(2026, 1, 1, 10)),
        textMessage('b', 'newer', pinnedAt: DateTime(2026, 1, 1, 12)),
      ];
      expect(newestPinnedMessage(messages)?.id, 'b');
    });

    test('ignores tombstoned pins and unpinned messages', () {
      final messages = <ChatMessage>[
        textMessage(
          'a',
          'gone',
          pinnedAt: DateTime(2026, 1, 1, 12),
          deletedAt: DateTime(2026, 1, 1, 13),
        ),
        textMessage('b', 'plain'),
      ];
      expect(newestPinnedMessage(messages), isNull);
    });

    test('falls back to a live pin when a newer pin was deleted', () {
      final messages = <ChatMessage>[
        textMessage('a', 'kept', pinnedAt: DateTime(2026, 1, 1, 10)),
        textMessage(
          'b',
          'gone',
          pinnedAt: DateTime(2026, 1, 1, 12),
          deletedAt: DateTime(2026, 1, 1, 13),
        ),
      ];
      expect(newestPinnedMessage(messages)?.id, 'a');
    });

    test('copyWith(clearPinnedAt) does not resurrect or leak other fields', () {
      final pinned = textMessage(
        'a',
        'pinned',
        pinnedAt: DateTime(2026, 1, 1, 10),
        reactions: const <String, int>{'❤️': 2},
      );
      final cleared = pinned.copyWith(clearPinnedAt: true);
      expect(cleared.pinnedAt, isNull);
      // An unrelated copyWith must not wipe reactions.
      expect(cleared.reactions, <String, int>{'❤️': 2});
    });
  });

  testWidgets('group pinned banner shows the newest pin and unpinning works', (
    tester,
  ) async {
    final harness = await _GroupHarness.pump(tester, <ChatMessage>[
      textMessage('m-old', 'older pin', pinnedAt: DateTime(2026, 1, 1, 10)),
      textMessage('m-new', 'newest pin', pinnedAt: DateTime(2026, 1, 1, 12)),
    ]);

    expect(find.byKey(const Key('pinned-message-bar')), findsOneWidget);
    expect(find.text('newest pin'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pinned-message-unpin')));
    await tester.pumpAndSettle();
    expect(harness.chatRepo.pinCalls.last, ('m-new', false));
  });

  testWidgets('the banner disappears when the server reports the pin gone', (
    tester,
  ) async {
    final harness = await _GroupHarness.pump(tester, <ChatMessage>[
      textMessage('m-new', 'newest pin', pinnedAt: DateTime(2026, 1, 1, 12)),
    ]);
    expect(find.byKey(const Key('pinned-message-bar')), findsOneWidget);

    // The stream is the source of truth: with no other state change, the bar
    // must still go away.
    harness.chatRepo.stream.add(
      Success<List<ChatMessage>>(<ChatMessage>[
        textMessage('m-new', 'newest pin'),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pinned-message-bar')), findsNothing);
  });

  testWidgets('a new pin on an older message moves the banner to it', (
    tester,
  ) async {
    final harness = await _GroupHarness.pump(tester, <ChatMessage>[
      textMessage('m-a', 'first'),
      textMessage('m-b', 'second'),
    ]);
    expect(find.byKey(const Key('pinned-message-bar')), findsNothing);

    harness.chatRepo.stream.add(
      Success<List<ChatMessage>>(<ChatMessage>[
        textMessage('m-a', 'first', pinnedAt: DateTime(2026, 1, 1, 12)),
        textMessage('m-b', 'second'),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pinned-message-bar')), findsOneWidget);
    expect(find.text('first'), findsWidgets);
  });

  testWidgets('tapping a reply quote jumps to the quoted message', (
    tester,
  ) async {
    await _GroupHarness.pump(tester, <ChatMessage>[
      textMessage('m-a', 'the original'),
      textMessage(
        'm-b',
        'a reply',
        replyToMessageId: 'm-a',
        replyPreview: 'the original',
      ),
    ]);

    expect(find.byKey(const Key('reply-quote-jump')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reply-quote-jump')));
    await tester.pumpAndSettle();
    // The target is still rendered (bubble plus its quoted preview), and the
    // jump did not throw or blank the list.
    expect(find.text('the original'), findsWidgets);
    expect(find.text('a reply'), findsOneWidget);
  });

  testWidgets('group actions hide what the server would refuse', (tester) async {
    final harness = await _GroupHarness.pump(tester, <ChatMessage>[
      textMessage('m-bob', 'from bob'),
    ]);

    await _openActions(tester, 'm-bob');
    // Bob's message: reply/react/forward available, but not edit or delete.
    expect(find.byKey(const Key('chat-action-reply')), findsOneWidget);
    expect(find.byKey(const Key('chat-action-forward')), findsOneWidget);
    expect(find.byKey(const Key('chat-reaction-bar')), findsOneWidget);
    expect(find.byKey(const Key('chat-action-edit')), findsNothing);
    expect(find.byKey(const Key('chat-action-delete')), findsNothing);

    await tester.tap(find.byKey(const Key('chat-action-more')));
    await tester.pumpAndSettle();
    // A regular member cannot pin someone else's message.
    expect(find.byKey(const Key('chat-action-pin')), findsNothing);
    expect(harness.chatRepo.edits, isEmpty);
    expect(harness.chatRepo.deletes, isEmpty);
  });

  testWidgets('group reaction pill records the picked emoji', (tester) async {
    final harness = await _GroupHarness.pump(tester, <ChatMessage>[
      textMessage('m-bob', 'from bob'),
    ]);

    await _openActions(tester, 'm-bob');
    await tester.tap(find.byKey(const Key('chat-react-👍')));
    await tester.pumpAndSettle();
    expect(harness.chatRepo.reactions.single.$1, 'm-bob');
    expect(harness.chatRepo.reactions.single.$2, '👍');
  });

  testWidgets('group edit saves the trimmed text through the repository', (
    tester,
  ) async {
    final harness = await _GroupHarness.pump(tester, <ChatMessage>[
      textMessage('m-alice', 'mine', mine: true, createdAt: DateTime.now()),
    ]);

    await _openActions(tester, 'm-alice');
    await tester.tap(find.byKey(const Key('chat-action-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-action-edit')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('chat-edit-field')),
      '  corrected  ',
    );
    await tester.tap(find.byKey(const Key('chat-edit-save')));
    await tester.pumpAndSettle();
    expect(harness.chatRepo.edits.last, ('m-alice', 'corrected'));
  });

  testWidgets('an empty edit is rejected without calling the server', (
    tester,
  ) async {
    final harness = await _GroupHarness.pump(tester, <ChatMessage>[
      textMessage('m-alice', 'mine', mine: true, createdAt: DateTime.now()),
    ]);

    await _openActions(tester, 'm-alice');
    await tester.tap(find.byKey(const Key('chat-action-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-action-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chat-edit-field')), '   ');
    await tester.tap(find.byKey(const Key('chat-edit-save')));
    await tester.pumpAndSettle();
    expect(harness.chatRepo.edits, isEmpty);
  });

  testWidgets('group delete confirms before removing', (tester) async {
    final harness = await _GroupHarness.pump(tester, <ChatMessage>[
      textMessage('m-alice', 'mine', mine: true, createdAt: DateTime.now()),
    ]);

    await _openActions(tester, 'm-alice');
    await tester.tap(find.byKey(const Key('chat-action-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-action-delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delete-message-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete-message-confirm-accept')));
    await tester.pumpAndSettle();
    expect(harness.chatRepo.deletes, <String>['m-alice']);
  });

  testWidgets('private chat offers the actions a 1:1 actually supports', (
    tester,
  ) async {
    final harness = await _PrivateHarness.pump(tester, <ChatMessage>[
      textMessage('m-bob', 'from bob'),
    ]);

    await _openActions(tester, 'm-bob');
    // The other person's message: reportable, forwardable, reactable.
    expect(find.byKey(const Key('chat-action-forward')), findsOneWidget);
    expect(find.byKey(const Key('chat-reaction-bar')), findsOneWidget);
    // Not ours, so not editable, not deletable, and a 1:1 has no moderator
    // to pin it for us.
    expect(find.byKey(const Key('chat-action-edit')), findsNothing);
    expect(find.byKey(const Key('chat-action-delete')), findsNothing);

    await tester.tap(find.byKey(const Key('chat-action-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-action-pin')), findsNothing);
    expect(find.byKey(const Key('chat-action-report')), findsOneWidget);
    expect(harness.repo.pinCalls, isEmpty);
  });

  testWidgets('private chat offers edit on a fresh own message', (
    tester,
  ) async {
    await _PrivateHarness.pump(tester, <ChatMessage>[
      textMessage('m-alice', 'mine', mine: true, createdAt: DateTime.now()),
    ]);

    await _openActions(tester, 'm-alice');
    await tester.tap(find.byKey(const Key('chat-action-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-action-edit')), findsOneWidget);
    expect(find.byKey(const Key('chat-action-delete')), findsOneWidget);
    expect(find.byKey(const Key('chat-action-pin')), findsOneWidget);
  });

  testWidgets('private chat does not offer edit outside the edit window', (
    tester,
  ) async {
    // The server refuses an edit after 15 minutes, so the client must not
    // offer one either.
    final harness = await _PrivateHarness.pump(tester, <ChatMessage>[
      textMessage('m-alice', 'old', mine: true),
    ]);

    await _openActions(tester, 'm-alice');
    await tester.tap(find.byKey(const Key('chat-action-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-action-edit')), findsNothing);
    expect(harness.repo.editCalls, isEmpty);
  });

  testWidgets('private chat pinned banner appears and unpins', (tester) async {
    final harness = await _PrivateHarness.pump(tester, <ChatMessage>[
      textMessage('m-alice', 'mine', mine: true),
    ]);
    expect(find.byKey(const Key('pinned-message-bar')), findsNothing);

    // The server stream is the source of truth for a pin.
    harness.repo.stream.add(
      Success<List<ChatMessage>>(<ChatMessage>[
        textMessage(
          'm-alice',
          'mine',
          mine: true,
          pinnedAt: DateTime(2026, 1, 1, 12),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pinned-message-bar')), findsOneWidget);
    expect(find.text('mine'), findsWidgets);

    await tester.tap(find.byKey(const Key('pinned-message-unpin')));
    await tester.pumpAndSettle();
    expect(harness.repo.pinCalls.single, ('m-alice', false));
  });

  testWidgets('private chat reports with a structured reason', (tester) async {
    final harness = await _PrivateHarness.pump(tester, <ChatMessage>[
      textMessage('m-bob', 'from bob'),
    ]);

    await _openActions(tester, 'm-bob');
    await tester.tap(find.byKey(const Key('chat-action-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-action-report')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-report-spam')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-report-confirm-accept')));
    await tester.pumpAndSettle();
    expect(harness.repo.reports.single.$2, 'spam');
  });

  testWidgets('private chat forwards to a group destination', (tester) async {
    final harness = await _PrivateHarness.pump(
      tester,
      <ChatMessage>[textMessage('m-bob', 'from bob')],
      groupDestinations: const <String>['club'],
    );

    await _openActions(tester, 'm-bob');
    await tester.tap(find.byKey(const Key('chat-action-forward')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forward-group-club')));
    await tester.pumpAndSettle();
    expect(harness.repo.forwards.single.$2, 'club');
  });

  testWidgets('private chat star persists and reflects back into the bubble', (
    tester,
  ) async {
    await _PrivateHarness.pump(tester, <ChatMessage>[
      textMessage('m-bob', 'from bob'),
    ]);

    await _openActions(tester, 'm-bob');
    expect(find.byKey(const Key('chat-action-star')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-action-star')));
    await tester.pumpAndSettle();

    // The star is stored on device, so a rebuild of the list shows it filled.
    final store = ChatStarStore();
    await store.ensureLoaded();
    expect(store.isStarred('m-bob'), isTrue);
  });
}

/// Opens the action overlay for [id] and waits for it to settle.
Future<void> _openActions(WidgetTester tester, String id) async {
  await tester.longPress(find.byKey(ValueKey<String>('message-$id')));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

class _GroupHarness {
  _GroupHarness(this.chatRepo);

  final FakeChatRepository chatRepo;

  static Future<_GroupHarness> pump(
    WidgetTester tester,
    List<ChatMessage> messages,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final chatRepo = FakeChatRepository();
    final auth = AuthProvider(
      repository: FakeAuthRepository(
        user: const AuthUser(id: 'alice', email: 'alice@example.com'),
      ),
    );
    await auth.initialize();
    final chat = ChatProvider(repository: chatRepo);
    final groups = GroupProvider(repository: FakeGroupRepository());
    final privates = PrivateChatListProvider(
      repository: UnavailablePrivateChatRepository('no offline cache'),
    );
    for (final provider in <ChangeNotifier>[auth, chat, groups, privates]) {
      addTearDown(provider.dispose);
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ChatProvider>.value(value: chat),
          ChangeNotifierProvider<GroupProvider>.value(value: groups),
          ChangeNotifierProvider<PrivateChatListProvider>.value(value: privates),
        ],
        child: MaterialApp(
          home: GroupChatPage(
            groupId: 'g1',
            audioPlayer: MemoryChatAudioPlayer(),
          ),
        ),
      ),
    );
    chatRepo.stream.add(Success<List<ChatMessage>>(messages));
    await tester.pumpAndSettle();
    return _GroupHarness(chatRepo);
  }
}

class _PrivateHarness {
  _PrivateHarness(this.repo);

  final FakeRecordingPrivateRepository repo;

  static Future<_PrivateHarness> pump(
    WidgetTester tester,
    List<ChatMessage> messages, {
    List<String> groupDestinations = const <String>[],
  }) async {
    // The action overlay is anchored to the bubble, and an own (right-hand)
    // bubble puts the overflow menu against the right edge of the surface.
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repo = FakeRecordingPrivateRepository(
      groupDestinations: groupDestinations,
    );
    final auth = AuthProvider(
      repository: FakeAuthRepository(
        user: const AuthUser(id: 'alice', email: 'alice@example.com'),
      ),
    );
    await auth.initialize();
    final chat = PrivateChatProvider(repository: repo);
    final list = PrivateChatListProvider(
      repository: UnavailablePrivateChatRepository('no offline cache'),
    );
    final groups = GroupProvider(
      repository: FakeGroupRepositoryWithDestinations(groupDestinations),
    );
    for (final provider in <ChangeNotifier>[auth, chat, list, groups]) {
      addTearDown(provider.dispose);
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<PrivateChatProvider>.value(value: chat),
          ChangeNotifierProvider<PrivateChatListProvider>.value(value: list),
          ChangeNotifierProvider<GroupProvider>.value(value: groups),
        ],
        child: MaterialApp(home: PrivateChatScreen(chatId: 'chat-1')),
      ),
    );
    repo.stream.add(Success<List<ChatMessage>>(messages));
    await tester.pumpAndSettle();
    return _PrivateHarness(repo);
  }
}
