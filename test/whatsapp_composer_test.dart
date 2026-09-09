import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/groups/services/voice_capture.dart';
import 'package:pubget/features/groups/widgets/wa_composer/whatsapp_chat_composer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('WhatsApp composer shows pill, mic, emoji, attach, camera', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WhatsAppChatComposer(
            controller: controller,
            focusNode: focus,
            groupId: 'g1',
            voiceCapture: MemoryVoiceCapture(),
            onSendText: () {},
            onSendMedia:
                ({
                  required bytes,
                  required fileName,
                  required contentType,
                }) async {},
            onSendSticker: (_) async {},
            onSendVoice: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('composer-emoji')), findsOneWidget);
    expect(find.byKey(const Key('composer-attach')), findsOneWidget);
    expect(find.byKey(const Key('composer-camera')), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.text('مراسلة'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hi');
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  testWidgets('emoji button opens sticker panel', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WhatsAppChatComposer(
            controller: controller,
            focusNode: focus,
            groupId: 'g1',
            voiceCapture: MemoryVoiceCapture(),
            onSendText: () {},
            onSendMedia:
                ({
                  required bytes,
                  required fileName,
                  required contentType,
                }) async {},
            onSendSticker: (_) async {},
            onSendVoice: (_) async {},
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('composer-emoji')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sticker-reactions/heart')), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);
  });
}
