import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/l10n/app_strings.dart';
import 'package:pubget/core/widgets/message_delivery_indicator.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/groups/widgets/chat_contrast_theme.dart';
import 'package:pubget/features/groups/widgets/chat_message_bubble.dart';
import 'package:pubget/features/groups/widgets/event_center_sheet.dart';
import 'package:pubget/features/games/models/game_type_registry.dart';

ChatMessage _msg({
  required String id,
  required String text,
  String senderId = 'other',
  String senderName = 'أحمد',
  String senderRole = 'founder',
  DateTime? deletedAt,
  Map<String, int> reactions = const <String, int>{},
  ChatSendState sendState = ChatSendState.sent,
  int recipientCount = 2,
  int deliveredCount = 1,
  int readCount = 0,
}) {
  return ChatMessage(
    id: id,
    senderId: senderId,
    senderName: senderName,
    senderAvatar: '',
    senderRole: senderRole,
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
    recipientCount: recipientCount,
    deliveredCount: deliveredCount,
    readCount: readCount,
    isOptimistic: false,
    sendState: sendState,
  );
}

Widget _wrap(Widget child, {Locale locale = const Locale('ar')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('chat contrast + default wallpaper', () {
    test('null background uses the official asset wallpaper', () {
      final theme = ChatContrastTheme.fromBackground(null);
      expect(theme.isImageBackground, isTrue);
      expect(theme.bubblesAreReadable, isTrue);
      final image = theme.background.image?.image;
      expect(image, isA<AssetImage>());
      expect(
        (image! as AssetImage).assetName,
        kPubgetDefaultChatWallpaperAsset,
      );
    });

    test('named presets stay readable on dark and light walls', () {
      for (final id in <String?>[
        null,
        'pubget://midnight',
        'pubget://dawn',
        'pubget://forest',
        'pubget://royal',
      ]) {
        final theme = ChatContrastTheme.fromBackground(id);
        expect(
          theme.bubblesAreReadable,
          isTrue,
          reason: 'failed for $id',
        );
      }
    });

    test('remote wallpaper falls back to a dark readable theme', () {
      final theme = ChatContrastTheme.fromBackground(
        'https://example.test/wall.jpg',
      );
      expect(theme.isImageBackground, isTrue);
      expect(theme.bubblesAreReadable, isTrue);
    });

    test('picker catalog starts with the official wallpaper', () {
      expect(pubgetChatBackgrounds.first.$1, isNull);
      expect(pubgetChatBackgrounds.first.$2, 'Pubget Classic');
    });
  });

  testWidgets('Event Center lists the four registered games', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EventCenterSheet(groupId: 'g1'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Event Center'), findsOneWidget);
    for (final spec in GameTypeRegistry.implemented) {
      expect(find.text(spec.name), findsWidgets);
    }
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('All group games'), findsOneWidget);
    expect(find.textContaining('isolated room'), findsWidgets);
  });

  group('WhatsApp-style MessageBubble rebuild', () {
    test('Arabic chat strings cover deleted + delivery labels', () {
      final ar = AppStrings.arabic;
      expect(ar.messageDeleted, 'تم حذف هذه الرسالة');
      expect(ar.loadOlderMessages, 'تحميل رسائل أقدم');
      expect(ar.delivered, 'وصلت');
      expect(ar.notDelivered, 'لم تصل');
      expect(ar.read, 'قُرئت');
    });

    testWidgets('short text shrink-wraps under 80% screen width', (
      tester,
    ) async {
      const screenW = 390.0;
      await tester.binding.setSurfaceSize(const Size(screenW, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final contrast = ChatContrastTheme.fromBackground(null);
      await tester.pumpWidget(
        _wrap(
          ChatMessageBubble(
            message: _msg(id: '1', text: 'مرحبا'),
            isMine: false,
            contrast: contrast,
            onLongPress: () {},
            onMediaTap: null,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('مرحبا'), findsOneWidget);
      expect(find.text('أحمد'), findsOneWidget);
      expect(find.text('المؤسس'), findsOneWidget);

      final bubbleText = tester.getRect(find.text('مرحبا'));
      expect(bubbleText.width, lessThan(screenW * 0.45));
      // Name+role row is compact — not a full-bleed notification card.
      final nameRow = tester.getRect(find.text('أحمد'));
      expect(nameRow.width, lessThan(screenW * 0.55));

      final shell = tester.getSize(find.byKey(const ValueKey<String>('message-1')));
      expect(shell.width, lessThan(screenW * 0.55),
          reason: 'short bubble must shrink-wrap, not fill ~78% always');
    });

    testWidgets('mine vs other align to opposite sides in RTL', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final contrast = ChatContrastTheme.fromBackground(null);

      await tester.pumpWidget(
        _wrap(
          Column(
            children: <Widget>[
              ChatMessageBubble(
                key: const Key('other'),
                message: _msg(id: 'o', text: 'منهم'),
                isMine: false,
                contrast: contrast,
                onLongPress: () {},
                onMediaTap: null,
              ),
              ChatMessageBubble(
                key: const Key('mine'),
                message: _msg(
                  id: 'm',
                  text: 'مني',
                  senderId: 'me',
                  senderName: 'أنا',
                ),
                isMine: true,
                contrast: contrast,
                onLongPress: () {},
                onMediaTap: null,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      final other = tester.getRect(find.text('منهم'));
      final mine = tester.getRect(find.text('مني'));
      // RTL WhatsApp: mine on the left (smaller x), others on the right.
      expect(mine.center.dx, lessThan(other.center.dx));
    });

    testWidgets('deleted message uses compact Arabic copy', (tester) async {
      final contrast = ChatContrastTheme.fromBackground(null);
      await tester.pumpWidget(
        _wrap(
          ChatMessageBubble(
            message: _msg(
              id: 'd',
              text: 'gone',
              deletedAt: DateTime(2026, 3, 1),
            ),
            isMine: false,
            contrast: contrast,
            onLongPress: () {},
            onMediaTap: null,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('تم حذف هذه الرسالة'), findsOneWidget);
      expect(find.text('Message deleted'), findsNothing);
      expect(find.text('gone'), findsNothing);
    });

    testWidgets('reactions render as overlapping pills not inline body text', (
      tester,
    ) async {
      final contrast = ChatContrastTheme.fromBackground(null);
      await tester.pumpWidget(
        _wrap(
          ChatMessageBubble(
            message: _msg(
              id: 'r',
              text: 'تفاعل',
              reactions: const <String, int>{'❤️': 1},
            ),
            isMine: false,
            contrast: contrast,
            onLongPress: () {},
            onMediaTap: null,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('1 ❤️'), findsNothing);
      expect(find.textContaining('1 ❤️'), findsNothing);
    });

    testWidgets('mine messages show delivery indicator next to time', (
      tester,
    ) async {
      final contrast = ChatContrastTheme.fromBackground(null);
      await tester.pumpWidget(
        _wrap(
          ChatMessageBubble(
            message: _msg(
              id: 'm',
              text: 'وصلت',
              senderId: 'me',
              deliveredCount: 1,
              readCount: 0,
            ),
            isMine: true,
            contrast: contrast,
            onLongPress: () {},
            onMediaTap: null,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('14:05'), findsOneWidget);
      expect(find.byType(MessageDeliveryIndicator), findsOneWidget);
    });
  });
}
