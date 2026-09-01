import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/widgets/pubget_design_system.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/private_chat/models/private_chat_models.dart';
import 'package:pubget/features/private_chat/providers/private_chat_list_provider.dart';
import 'package:pubget/features/private_chat/repositories/private_chat_repository.dart';
import 'package:pubget/features/private_chat/screens/private_chats_list_screen.dart';

import 'authentication_test_support.dart';

void main() {
  testWidgets('private chat list shows the empty state', (tester) async {
    final authRepository = FakeAuthRepository(
      user: const AuthUser(id: 'user-1', email: 'fan@example.com'),
    );
    final auth = AuthProvider(repository: authRepository);
    await auth.initialize();
    addTearDown(authRepository.close);
    addTearDown(auth.dispose);
    final repository = _FakeListRepository();
    final list = PrivateChatListProvider(repository: repository);
    addTearDown(list.dispose);
    addTearDown(repository.chats.close);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<PrivateChatListProvider>.value(value: list),
        ],
        child: const MaterialApp(home: PrivateChatsListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No private chats yet'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is PubgetEmptyState,
      ),
      findsOneWidget,
    );
  });
}

final class _FakeListRepository implements PrivateChatRepository {
  final chats = StreamController<Result<List<PrivateChatSummary>>>.broadcast();

  @override
  Future<Result<String>> startChat(String otherUserId) async =>
      const Success('c1');

  @override
  Stream<Result<List<PrivateChatSummary>>> watchChats({int limit = 20}) {
    scheduleMicrotask(() {
      chats.add(const Success<List<PrivateChatSummary>>(<PrivateChatSummary>[]));
    });
    return chats.stream;
  }

  @override
  Future<Result<List<PrivateChatSummary>>> getOlderChats({
    required PrivateChatSummary before,
    int limit = 20,
  }) async => const Success(<PrivateChatSummary>[]);

  @override
  Stream<Result<List<ChatMessage>>> watchMessages(
    String chatId, {
    int limit = 40,
  }) => const Stream.empty();

  @override
  Future<Result<List<ChatMessage>>> getOlderMessages({
    required String chatId,
    required ChatMessage before,
    int limit = 40,
  }) async => const Success(<ChatMessage>[]);

  @override
  Future<Result<ChatMessage>> sendMessage({
    required String chatId,
    required String messageId,
    required ChatMessageType type,
    String? text,
    String? mediaUrl,
    String? thumbnailUrl,
    String? mediaId,
    String? replyToMessageId,
  }) async => const FailureResult(UnknownError());

  @override
  Future<Result<void>> deleteMessage({
    required String chatId,
    required String messageId,
  }) async => const Success(null);

  @override
  Future<Result<void>> markAsRead({
    required String chatId,
    required List<String> messageIds,
  }) async => const Success(null);

  @override
  Future<Result<void>> markAsDelivered({
    required String chatId,
    required List<String> messageIds,
  }) async => const Success(null);

  @override
  Future<Result<void>> deleteChat(String chatId) async => const Success(null);

  @override
  Future<Result<ChatMediaUpload>> uploadMedia({
    required String chatId,
    required String mediaId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required void Function(double progress) onProgress,
  }) async => const FailureResult(UnknownError());
}
