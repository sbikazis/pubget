import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/groups/providers/chat_provider.dart';
import 'package:pubget/features/groups/repositories/chat_repository.dart';
import 'package:pubget/features/groups/widgets/chat_contrast_theme.dart';
import 'package:pubget/features/groups/widgets/chat_message_bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('failed media retry is actionable without progress rebuilds', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repository = _RetryRepository();
    final provider = ChatProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.open(groupId: 'g1', currentUserId: 'u1');

    final send = provider.sendMedia(
      groupId: 'g1',
      senderId: 'u1',
      senderName: 'Alice',
      senderAvatar: '',
      senderRole: 'member',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'clip.mp4',
      contentType: 'video/mp4',
    );
    await send.timeout(const Duration(seconds: 5));
    final failed = provider.messages.single;
    expect(failed.sendState, ChatSendState.failed);

    var providerNotifications = 0;
    provider.addListener(() => providerNotifications++);
    await tester.pumpWidget(
      ChangeNotifierProvider<ChatProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              message: failed,
              isMine: true,
              contrast: ChatContrastTheme.fromBackground(null),
              onLongPress: (_) {},
              onMediaTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('media-retry')), findsOneWidget);

    final retry = tester.widget<TextButton>(
      find.byKey(const Key('media-retry')),
    );
    retry.onPressed!.call();
    await tester.pump();
    final notificationsBeforeProgress = providerNotifications;
    repository.emitProgress(0.5);
    expect(providerNotifications, notificationsBeforeProgress);

    repository.failUpload();
    await tester.pump();
    expect(repository.uploadCalls, 2);
  });
}

final class _RetryRepository implements ChatRepository {
  final _stream = StreamController<Result<List<ChatMessage>>>.broadcast();
  Completer<Result<ChatMediaUpload>>? _upload;
  void Function(double progress)? _onProgress;
  var uploadCalls = 0;

  void emitProgress(double value) => _onProgress?.call(value);

  void failUpload() {
    final upload = _upload;
    if (upload != null && !upload.isCompleted) {
      upload.complete(const FailureResult(ValidationError('upload-failed')));
    }
  }

  @override
  Stream<Result<List<ChatMessage>>> watchMessages(
    String groupId, {
    int limit = 40,
  }) => _stream.stream;

  @override
  Future<Result<List<ChatMessage>>> getOlderMessages({
    required String groupId,
    required ChatMessage before,
    int limit = 40,
  }) async => const Success(<ChatMessage>[]);

  @override
  Future<Result<ChatMessage>> sendMessage({
    required String groupId,
    required String messageId,
    required ChatMessageType type,
    String? text,
    String? mediaUrl,
    String? thumbnailUrl,
    String? mediaId,
    String? replyToMessageId,
    String? stickerKey,
    String? stickerCreatorId,
    String? stickerCreatorName,
  }) async => throw UnimplementedError();

  @override
  Future<Result<ChatMessage>> forwardMessage({
    required String sourceGroupId,
    required String messageId,
    String? destinationGroupId,
    String? destinationChatId,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> reportMessage({
    required String groupId,
    required String messageId,
    required String reason,
    String details = '',
  }) async => throw UnimplementedError();

  @override
  Future<Result<ChatMessage>> editMessage({
    required String groupId,
    required String messageId,
    required String text,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> deleteMessage({
    required String groupId,
    required String messageId,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> pinMessage({
    required String groupId,
    required String messageId,
    required bool pinned,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> addReaction({
    required String groupId,
    required String messageId,
    required String reaction,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> markAsRead({
    required String groupId,
    required List<String> messageIds,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> markAsDelivered({
    required String groupId,
    required List<String> messageIds,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> updateChatBackground({
    required String groupId,
    required String? backgroundUrl,
  }) async => throw UnimplementedError();

  @override
  Future<Result<ChatMediaUpload>> uploadMedia({
    required String groupId,
    required String mediaId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required void Function(double progress) onProgress,
    void Function()? onBytesUploaded,
  }) {
    uploadCalls++;
    _onProgress = onProgress;
    _upload = Completer<Result<ChatMediaUpload>>();
    onProgress(0);
    if (uploadCalls == 1) {
      _upload!.complete(const FailureResult(ValidationError('upload-failed')));
    }
    return _upload!.future;
  }
}
