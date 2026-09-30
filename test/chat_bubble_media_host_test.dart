import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/groups/widgets/chat_contrast_theme.dart';
import 'package:pubget/features/groups/widgets/chat_message_bubble.dart';
import 'package:pubget/features/private_chat/providers/private_chat_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_test_support.dart';

/// The shared bubble must render media progress for whichever conversation owns
/// it. Before the host was injected, a 1:1 bubble reached for `ChatProvider`
/// directly, so a private upload either threw (no provider in scope) or, worse,
/// picked up an unrelated group's progress.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('a 1:1 bubble renders upload progress with no group provider', (
    tester,
  ) async {
    final repository = FakePrivateRepository()
      ..uploadGate = Completer<Result<ChatMediaUpload>>();
    final provider = PrivateChatProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.open(chatId: 'c1', currentUserId: 'alice');

    final send = provider.sendMedia(
      chatId: 'c1',
      senderId: 'alice',
      senderName: 'Alice',
      senderAvatar: '',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'clip.mp4',
      contentType: 'video/mp4',
    );
    await tester.pump();
    final pending = provider.messages.single;

    // Deliberately no Provider ancestor at all: reading ChatProvider here used
    // to throw ProviderNotFoundException for every private media message.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(
            message: pending,
            isMine: true,
            contrast: ChatContrastTheme.fromBackground(null),
            onLongPress: (_) {},
            onMediaTap: () {},
            mediaHost: provider,
            onRetryMedia: provider.retry,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.emitProgress(0.6);
    await tester.pump();
    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, closeTo(0.6, 0.001));

    // Bytes are on the server: the stage flips to the indeterminate
    // "processing" spinner rather than a frozen 100% bar.
    repository.emitBytesUploaded();
    await tester.pump();
    expect(
      tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      ).value,
      isNull,
    );

    repository.uploadGate!.complete(
      const Success(
        ChatMediaUpload(
          mediaUrl: 'https://cdn.example/clip.mp4',
          thumbnailUrl: null,
          mediaId: 'media-1',
          type: ChatMessageType.video,
        ),
      ),
    );
    await send;
  });

  testWidgets('the bubble keeps the sender local bytes as a placeholder', (
    tester,
  ) async {
    final repository = FakePrivateRepository()
      ..uploadGate = Completer<Result<ChatMediaUpload>>();
    final provider = PrivateChatProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.open(chatId: 'c1', currentUserId: 'alice');

    // A real decodable raster: the bubble hands these bytes to Image.memory as
    // the placeholder, so random bytes would fail the codec rather than prove
    // anything about the preview path.
    final bytes = base64Decode(_onePixelPng);
    final send = provider.sendMedia(
      chatId: 'c1',
      senderId: 'alice',
      senderName: 'Alice',
      senderAvatar: '',
      bytes: bytes,
      fileName: 'photo.png',
      contentType: 'image/png',
    );
    await tester.pump();
    final pending = provider.messages.single;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(
            message: pending,
            isMine: true,
            contrast: ChatContrastTheme.fromBackground(null),
            onLongPress: (_) {},
            onMediaTap: () {},
            mediaHost: provider,
            onRetryMedia: provider.retry,
          ),
        ),
      ),
    );

    expect(provider.localPreviewBytes(pending.id), bytes);

    repository.uploadGate!.complete(
      const Success(
        ChatMediaUpload(
          mediaUrl: 'https://cdn.example/photo.jpg',
          thumbnailUrl: null,
          mediaId: 'media-1',
          type: ChatMessageType.image,
        ),
      ),
    );
    await send;
  });
}

/// 1x1 transparent PNG, enough for the loader to measure and paint.
const String _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
