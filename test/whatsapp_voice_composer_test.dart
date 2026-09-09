import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/groups/services/voice_capture.dart';
import 'package:pubget/features/groups/widgets/wa_composer/whatsapp_chat_composer.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _TrackingCapture extends MemoryVoiceCapture {
  final calls = <String>[];

  @override
  Future<void> start() async {
    calls.add('start');
    await super.start();
  }

  @override
  Future<VoiceClip?> stop() async {
    calls.add('stop');
    return super.stop();
  }

  @override
  Future<void> cancel() async {
    calls.add('cancel');
    await super.cancel();
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    await super.pause();
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    await super.resume();
  }
}

Widget _wrap(WhatsAppChatComposer child) {
  return MaterialApp(home: Scaffold(body: child));
}

WhatsAppChatComposer _composer({
  required TextEditingController controller,
  required FocusNode focus,
  required VoiceCapture capture,
  required List<VoiceClip> sent,
}) {
  return WhatsAppChatComposer(
    controller: controller,
    focusNode: focus,
    groupId: 'g1',
    voiceCapture: capture,
    currentUserId: 'u1',
    currentUserName: 'Alice',
    onSendText: () {},
    onSendMedia: ({
      required bytes,
      required fileName,
      required contentType,
    }) async {},
    onSendSticker: (_) async {},
    onSendCustomSticker: ({
      required bytes,
      required fileName,
      required contentType,
      required stickerCreatorId,
      required stickerCreatorName,
    }) async {},
    onSendVoice: (clip) async => sent.add(clip),
  );
}

Future<void> _pressMic(WidgetTester tester) async {
  // unused helper removed
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hold mic starts recording UI with timer and cancel hint', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = TextEditingController();
    final focus = FocusNode();
    final sent = <VoiceClip>[];
    final capture = _TrackingCapture();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      _wrap(
        _composer(
          controller: controller,
          focus: focus,
          capture: capture,
          sent: sent,
        ),
      ),
    );

    final center = tester.getCenter(find.byKey(const Key('composer-mic')));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byKey(const Key('composer-voice-holding')), findsOneWidget);
    expect(find.byKey(const Key('composer-voice-timer')), findsOneWidget);
    expect(find.text('اسحب للإلغاء'), findsOneWidget);
    expect(capture.calls, contains('start'));

    await gesture.up();
    await tester.pump(); // schedule pointer-up handlers
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(); // flush stop()/onSendVoice microtasks
    expect(capture.calls, contains('stop'));
    expect(sent, hasLength(1));
    expect(find.byKey(const Key('composer-voice-holding')), findsNothing);
  });

  testWidgets('slide up locks recording with pause delete send', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = TextEditingController();
    final focus = FocusNode();
    final sent = <VoiceClip>[];
    final capture = _TrackingCapture();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      _wrap(
        _composer(
          controller: controller,
          focus: focus,
          capture: capture,
          sent: sent,
        ),
      ),
    );

    final center = tester.getCenter(find.byKey(const Key('composer-mic')));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 180));
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump();
    expect(find.byKey(const Key('composer-voice-locked')), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(find.byKey(const Key('composer-voice-locked')), findsOneWidget);

    await tester.tap(find.byKey(const Key('composer-voice-pause')));
    await tester.pump();
    expect(capture.calls, contains('pause'));
    expect(find.byKey(const Key('composer-voice-preview')), findsOneWidget);

    await tester.tap(find.byKey(const Key('composer-voice-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(capture.calls, contains('stop'));
    expect(sent, hasLength(1));
  });

  testWidgets('slide to cancel discards voice without sending', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = TextEditingController();
    final focus = FocusNode();
    final sent = <VoiceClip>[];
    final capture = _TrackingCapture();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      _wrap(
        _composer(
          controller: controller,
          focus: focus,
          capture: capture,
          sent: sent,
        ),
      ),
    );

    final center = tester.getCenter(find.byKey(const Key('composer-mic')));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 180));
    await gesture.moveBy(const Offset(140, 0));
    await tester.pump();
    expect(find.text('إلغاء'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(capture.calls, contains('cancel'));
    expect(sent, isEmpty);
    expect(capture.isRecording, isFalse);
  });

  test('MemoryVoiceCapture emits amplitude while recording', () async {
    final capture = MemoryVoiceCapture(
      amplitudePeriod: const Duration(milliseconds: 20),
    );
    final levels = <double>[];
    final sub = capture.amplitudeStream.listen(levels.add);
    await capture.start();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await capture.pause();
    expect(capture.isPaused, isTrue);
    final pausedCount = levels.length;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(levels.length, pausedCount);
    await capture.resume();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final clip = await capture.stop();
    await sub.cancel();
    expect(clip, isNotNull);
    expect(levels, isNotEmpty);
  });
}
