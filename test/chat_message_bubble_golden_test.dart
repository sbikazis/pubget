import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/groups/widgets/chat_contrast_theme.dart';
import 'package:pubget/features/groups/widgets/chat_message_bubble.dart';

ChatMessage msg({
  required String id,
  required String text,
  required String senderId,
  required String name,
  String role = 'founder',
  DateTime? deletedAt,
  Map<String, int> reactions = const {},
}) {
  return ChatMessage(
    id: id,
    senderId: senderId,
    senderName: name,
    senderAvatar: '',
    senderRole: role,
    type: ChatMessageType.text,
    text: text,
    mediaUrl: null,
    thumbnailUrl: null,
    mediaId: null,
    replyToMessageId: null,
    createdAt: DateTime(2026, 3, 1, 14, 5),
    editedAt: null,
    deletedAt: deletedAt,
    pinnedAt: null,
    reactions: reactions,
    recipientCount: 2,
    deliveredCount: 1,
    readCount: senderId == 'me' ? 1 : 0,
    isOptimistic: false,
    sendState: ChatSendState.sent,
  );
}

void main() {
  testWidgets('golden whatsapp bubbles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final contrast = ChatContrastTheme.fromBackground(null);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: DecoratedBox(
              decoration: contrast.background,
              child: ColoredBox(
                color: contrast.scrim,
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    ChatMessageBubble(
                      message: msg(
                        id: '1',
                        text: 'مرحبا بالجميع',
                        senderId: 'other',
                        name: 'أحمد',
                        reactions: const {'❤️': 1},
                      ),
                      isMine: false,
                      contrast: contrast,
                      onLongPress: (_) {},
                      onMediaTap: null,
                    ),
                    ChatMessageBubble(
                      message: msg(
                        id: '2',
                        text: 'أهلاً!',
                        senderId: 'me',
                        name: 'أنا',
                        role: 'member',
                      ),
                      isMine: true,
                      contrast: contrast,
                      onLongPress: (_) {},
                      onMediaTap: null,
                    ),
                    ChatMessageBubble(
                      message: msg(
                        id: '3',
                        text: 'deleted',
                        senderId: 'other',
                        name: 'سارة',
                        role: 'captain',
                        deletedAt: DateTime(2026, 3, 1),
                      ),
                      isMine: false,
                      contrast: contrast,
                      onLongPress: (_) {},
                      onMediaTap: null,
                    ),
                    ChatMessageBubble(
                      message: msg(
                        id: '4',
                        text: 'هذه رسالة أطول قليلاً للتأكد من أن الفقاعة لا تتمدد بعرض الشاشة بالكامل مثل بطاقة الإشعار.',
                        senderId: 'other',
                        name: 'ليث',
                        role: 'shogun',
                      ),
                      isMine: false,
                      contrast: contrast,
                      onLongPress: (_) {},
                      onMediaTap: null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/chat_message_bubble_whatsapp.png'),
    );
  });
}
