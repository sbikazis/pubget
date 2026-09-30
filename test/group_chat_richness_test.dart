
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/groups/data/sticker_catalog.dart';
import 'package:pubget/features/groups/data/sticker_store.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/groups/providers/chat_provider.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/screens/group_chat_page.dart';
import 'package:pubget/features/groups/services/chat_audio_player.dart';
import 'package:pubget/features/groups/services/voice_capture.dart';
import 'package:pubget/features/groups/widgets/sticker_picker_sheet.dart';
import 'package:pubget/features/groups/widgets/wa_composer/wa_emoji_panel.dart';
import 'package:pubget/features/groups/widgets/voice_recorder_sheet.dart';
import 'package:pubget/features/private_chat/providers/private_chat_list_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'authentication_test_support.dart';
import 'chat_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('game system cards parse join affordance from server activity', () {
    final message = ChatMessage.fromMap(<String, dynamic>{
      'senderId': 'system',
      'senderName': 'Pubget',
      'senderRole': 'system',
      'type': 'game',
      'text': 'A Mafia lobby is waiting. Tap to join.',
      'mediaId': 'm1',
      'gameActivity': <String, dynamic>{'kind': 'created', 'gameType': 'mafia'},
    }, id: 'card-1');
    expect(message.gameActivity?.isCreated, isTrue);
    expect(message.gameActivity?.isMafia, isTrue);
    expect(message.gameActivity?.actionLabel, 'Join');
  });

  test('chatMediaTypeFor classifies gif, audio, video, and images', () {
    expect(
      chatMediaTypeFor(contentType: 'image/gif', fileName: 'x.bin'),
      ChatMessageType.gif,
    );
    expect(
      chatMediaTypeFor(contentType: 'image/jpeg', fileName: 'loop.gif'),
      ChatMessageType.gif,
    );
    expect(
      chatMediaTypeFor(contentType: 'audio/mp4', fileName: 'voice.m4a'),
      ChatMessageType.audio,
    );
    expect(
      chatMediaTypeFor(contentType: 'video/mp4', fileName: 'clip.mp4'),
      ChatMessageType.video,
    );
    expect(
      chatMediaTypeFor(contentType: 'image/png', fileName: 'art.png'),
      ChatMessageType.image,
    );
  });

  testWidgets('sticker picker selects a catalog key', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = StickerStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => StickerPickerSheet.show(context, store: store),
              child: const Text('Open stickers'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open stickers'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sticker-category-Reactions')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sticker-reactions/heart')));
    await tester.pumpAndSettle();
    expect(find.byType(StickerPickerSheet), findsNothing);
    expect(await store.recent(), <String>['reactions/heart']);
  });

  testWidgets('voice sheet records, previews, and returns a clip', (
    tester,
  ) async {
    final capture = MemoryVoiceCapture();
    VoiceClip? sent;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                sent = await VoiceRecorderSheet.show(context, capture: capture);
              },
              child: const Text('Open voice'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open voice'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voice-toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('voice-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voice-send')), findsOneWidget);
    await tester.tap(find.byKey(const Key('voice-send')));
    await tester.pumpAndSettle();
    expect(sent?.fileName, 'voice.m4a');
    expect(sent?.exceedsLimits, isFalse);
  });

  testWidgets('composer sticker send and reply/report/forward actions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final chatRepo = FakeChatRepository();
    final groupRepo = FakeGroupRepository();
    final privateRepo = FakePrivateRepository();
    final authRepository = FakeAuthRepository(
      user: const AuthUser(id: 'alice', email: 'alice@example.com'),
    );
    final auth = AuthProvider(repository: authRepository);
    await auth.initialize();
    final chat = ChatProvider(repository: chatRepo);
    final groups = GroupProvider(repository: groupRepo);
    final privates = PrivateChatListProvider(repository: privateRepo);
    final audio = MemoryChatAudioPlayer();
    addTearDown(auth.dispose);
    addTearDown(chat.dispose);
    addTearDown(groups.dispose);
    addTearDown(privates.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ChatProvider>.value(value: chat),
          ChangeNotifierProvider<GroupProvider>.value(value: groups),
          ChangeNotifierProvider<PrivateChatListProvider>.value(
            value: privates,
          ),
        ],
        child: MaterialApp(
          home: GroupChatPage(
            groupId: 'g1',
            voiceCapture: MemoryVoiceCapture(),
            audioPlayer: audio,
            stickerStore: StickerStore(),
          ),
        ),
      ),
    );
    await groups.loadJoined('alice');
    await tester.pump();
    chatRepo.stream.add(Success(<ChatMessage>[fakeBobText()]));
    await tester.pumpAndSettle();

    expect(find.text('hello from bob'), findsOneWidget);
    expect(find.byKey(const Key('group-chat-menu')), findsOneWidget);

    await tester.tap(find.byKey(const Key('composer-emoji')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('catalog-sticker-reactions/heart')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('composer-create-sticker')), findsOneWidget);
    expect(find.text('GIF'), findsNothing);
    await tester.tap(find.byKey(const Key('catalog-sticker-reactions/heart')));
    await tester.pumpAndSettle();
    expect(chatRepo.sent.last['stickerKey'], 'reactions/heart');
    // The sent sticker surfaces in the recently-used strip with the favorites
    // toggle; the strip stays reachable when toggling favorites mode.
    expect(find.byKey(const Key('recent-sticker-reactions/heart')), findsOneWidget);
    expect(find.byKey(const Key('sticker-favorites-toggle')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sticker-favorites-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Favorites'), findsOneWidget);
    // Close panel so message actions remain reachable.
    await tester.tap(find.byKey(const Key('composer-emoji')));
    await tester.pumpAndSettle();
    expect(find.byType(WaEmojiPanel), findsNothing);

    await tester.longPress(find.byKey(const ValueKey<String>('message-m-bob')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-action-reply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reply-composer-bar')), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Quoted reply');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byIcon(Icons.send_rounded), findsWidgets);
    await tester.tap(find.byIcon(Icons.send_rounded).last);
    await tester.pumpAndSettle();
    expect(chatRepo.sent.last['text'], 'Quoted reply');
    expect(chatRepo.sent.last['replyToMessageId'], 'm-bob');

    await tester.longPress(find.byKey(const ValueKey<String>('message-m-bob')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('chat-action-forward')));
    await tester.tap(find.byKey(const Key('chat-action-forward')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forward-group-g2')));
    await tester.pumpAndSettle();
    expect(chatRepo.forwards.single.destinationGroupId, 'g2');
    expect(find.text('Message forwarded'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 500));
  });

  test('sticker catalog stays aligned with the original 12-key set', () {
    expect(stickerCatalog, hasLength(12));
    expect(
      stickerCatalog.map((item) => item.key),
      containsAll(<String>['reactions/heart', 'gestures/wave', 'pubget/torii']),
    );
  });
}
