import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/groups/data/user_sticker_store.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/groups/widgets/sticker_detail_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sticker sheet shows original creator not sender', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final message = ChatMessage.fromMap(<String, dynamic>{
      'senderId': 'bob',
      'senderName': 'Bob Sender',
      'senderAvatar': '',
      'senderRole': 'member',
      'type': 'sticker',
      'mediaUrl': '',
      'stickerCreatorId': 'alice',
      'stickerCreatorName': 'Alice Creator',
      'createdAt': DateTime(2026, 3, 1),
      'recipientCount': 1,
      'deliveredCount': 0,
      'readCount': 0,
      'reactions': <String, int>{},
    }, id: 'sticker-1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => StickerDetailSheet.show(
                context,
                message: message,
                store: UserStickerStore(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Alice Creator'), findsOneWidget);
    expect(find.text('Bob Sender'), findsNothing);
    expect(find.byKey(const Key('sticker-detail-save')), findsOneWidget);
    expect(find.text('منشئ الملصق'), findsOneWidget);
  });

  testWidgets('catalog sticker sheet shows Pubget without save', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final message = ChatMessage.fromMap(<String, dynamic>{
      'senderId': 'bob',
      'senderName': 'Bob',
      'senderAvatar': '',
      'senderRole': 'member',
      'type': 'sticker',
      'stickerKey': 'reactions/heart',
      'stickerCreatorId': 'pubget',
      'stickerCreatorName': 'Pubget',
      'createdAt': DateTime(2026, 3, 1),
      'recipientCount': 1,
      'deliveredCount': 0,
      'readCount': 0,
      'reactions': <String, int>{},
    }, id: 'sticker-2');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => StickerDetailSheet.show(
                context,
                message: message,
                store: UserStickerStore(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Pubget'), findsOneWidget);
    expect(find.byKey(const Key('sticker-detail-save')), findsNothing);
  });
}
