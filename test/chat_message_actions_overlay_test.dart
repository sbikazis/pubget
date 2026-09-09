import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/groups/widgets/chat_contrast_theme.dart';
import 'package:pubget/features/groups/widgets/chat_message_actions_overlay.dart';
import 'package:pubget/features/groups/widgets/chat_message_bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';

ChatMessage _msg({
  required String id,
  required String text,
  String senderId = 'other',
}) {
  return ChatMessage(
    id: id,
    senderId: senderId,
    senderName: 'أحمد',
    senderAvatar: '',
    senderRole: 'founder',
    type: ChatMessageType.text,
    text: text,
    mediaUrl: null,
    thumbnailUrl: null,
    mediaId: null,
    replyToMessageId: null,
    createdAt: DateTime(2026, 3, 1, 14, 5),
    editedAt: null,
    deletedAt: null,
    pinnedAt: null,
    reactions: const <String, int>{},
    recipientCount: 2,
    deliveredCount: 1,
    readCount: 0,
    isOptimistic: false,
    sendState: ChatSendState.sent,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reaction overlay: emoji bar is above selection actions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final contrast = ChatContrastTheme.fromBackground(null);
    final message = _msg(id: '1', text: 'مرحبا');

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showChatMessageActions(
                      context,
                      message: message,
                      isMine: false,
                      contrast: contrast,
                      bubbleRect: const Rect.fromLTWH(40, 280, 180, 70),
                      canEdit: false,
                      canCopy: true,
                      isStarred: false,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Reaction bar present with WhatsApp emojis + plus.
    expect(find.byKey(const Key('chat-reaction-bar')), findsOneWidget);
    expect(find.byKey(const Key('chat-react-👍')), findsOneWidget);
    expect(find.byKey(const Key('chat-react-❤️')), findsOneWidget);
    expect(find.byKey(const Key('chat-react-😂')), findsOneWidget);
    expect(find.byKey(const Key('chat-react-😮')), findsOneWidget);
    expect(find.byKey(const Key('chat-react-😥')), findsOneWidget);
    expect(find.byKey(const Key('chat-react-🙏')), findsOneWidget);
    expect(find.byKey(const Key('chat-react-✌️')), findsOneWidget);
    expect(find.byKey(const Key('chat-react-more')), findsOneWidget);

    // Selection AppBar primary actions.
    expect(find.byKey(const Key('chat-action-reply')), findsOneWidget);
    expect(find.byKey(const Key('chat-action-star')), findsOneWidget);
    expect(find.byKey(const Key('chat-action-delete')), findsOneWidget);
    expect(find.byKey(const Key('chat-action-forward')), findsOneWidget);

    // Secondary actions live in overflow — not covering the reaction bar.
    expect(find.byKey(const Key('chat-action-copy')), findsNothing);
    await tester.tap(find.byKey(const Key('chat-action-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-action-copy')), findsOneWidget);
    expect(find.byKey(const Key('chat-action-pin')), findsOneWidget);
    expect(find.byKey(const Key('chat-action-info')), findsOneWidget);

    // Emoji bar still visible while overflow is open (higher z-index).
    expect(find.byKey(const Key('chat-reaction-bar')), findsOneWidget);

    // Reaction bar is painted after (above) the overflow in the Stack.
    final bar = tester.getRect(find.byKey(const Key('chat-reaction-bar')));
    final copy = tester.getRect(find.byKey(const Key('chat-action-copy')));
    // Overflow is under the AppBar; reaction bar is near the bubble — no overlap.
    expect(bar.overlaps(copy), isFalse);

    await tester.tap(find.byKey(const Key('chat-action-reply')));
    await tester.pumpAndSettle();
  });

  testWidgets('bubble long-press opens overlay via group chat callback rect', (
    tester,
  ) async {
    Rect? captured;
    final contrast = ChatContrastTheme.fromBackground(null);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ChatMessageBubble(
              message: _msg(id: 'x', text: 'اضغط'),
              isMine: false,
              contrast: contrast,
              onLongPress: (rect) => captured = rect,
              onMediaTap: null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.longPress(find.text('اضغط'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(captured, isNotNull);
  });
}
