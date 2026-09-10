import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/authentication/models/auth_user.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/groups/data/sticker_catalog.dart';
import 'package:pubget/features/groups/data/sticker_store.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/providers/chat_provider.dart';
import 'package:pubget/features/groups/providers/group_provider.dart';
import 'package:pubget/features/groups/repositories/chat_repository.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';
import 'package:pubget/features/groups/screens/group_chat_page.dart';
import 'package:pubget/features/groups/services/chat_audio_player.dart';
import 'package:pubget/features/groups/services/voice_capture.dart';
import 'package:pubget/features/groups/widgets/sticker_picker_sheet.dart';
import 'package:pubget/features/groups/widgets/voice_recorder_sheet.dart';
import 'package:pubget/features/private_chat/models/private_chat_models.dart';
import 'package:pubget/features/private_chat/providers/private_chat_list_provider.dart';
import 'package:pubget/features/private_chat/repositories/private_chat_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'authentication_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('game system cards parse join affordance from server activity', () {
    final message = ChatMessage.fromMap(
      <String, dynamic>{
        'senderId': 'system',
        'senderName': 'Pubget',
        'senderRole': 'system',
        'type': 'game',
        'text': 'A Mafia lobby is waiting. Tap to join.',
        'mediaId': 'm1',
        'gameActivity': <String, dynamic>{
          'kind': 'created',
          'gameType': 'mafia',
        },
      },
      id: 'card-1',
    );
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
    final chatRepo = _FakeChatRepository();
    final groupRepo = _FakeGroupRepository();
    final privateRepo = _FakePrivateRepository();
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
    chatRepo.stream.add(Success(<ChatMessage>[_bobText()]));
    await tester.pumpAndSettle();

    expect(find.text('hello from bob'), findsOneWidget);
    expect(find.byKey(const Key('group-chat-menu')), findsOneWidget);

    await tester.tap(find.byKey(const Key('composer-emoji')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stickers-empty-message')), findsOneWidget);
    expect(find.byKey(const Key('composer-create-sticker')), findsOneWidget);
    expect(find.text('GIF'), findsNothing);
    // Close panel so message actions remain reachable.
    await tester.tap(find.byKey(const Key('composer-emoji')));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const ValueKey<String>('message-m-bob')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-action-reply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reply-composer-bar')), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Quoted reply');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
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
  });

  test('sticker catalog stays aligned with the original 12-key set', () {
    expect(stickerCatalog, hasLength(12));
    expect(
      stickerCatalog.map((item) => item.key),
      containsAll(<String>['reactions/heart', 'gestures/wave', 'pubget/torii']),
    );
  });
}

ChatMessage _bobText() => ChatMessage.fromMap(<String, dynamic>{
  'senderId': 'bob',
  'senderName': 'Bob',
  'senderAvatar': '',
  'senderRole': 'member',
  'type': 'text',
  'text': 'hello from bob',
  'createdAt': DateTime(2026, 3, 1),
  'recipientCount': 1,
  'deliveredCount': 0,
  'readCount': 0,
  'reactions': <String, int>{},
}, id: 'm-bob');

final class _FakeChatRepository implements ChatRepository {
  final stream = StreamController<Result<List<ChatMessage>>>.broadcast();
  final sent = <Map<String, Object?>>[];
  final reports = <({String messageId, String reason})>[];
  final forwards =
      <({String? destinationGroupId, String? destinationChatId})>[];

  @override
  Stream<Result<List<ChatMessage>>> watchMessages(
    String groupId, {
    int limit = 40,
  }) => stream.stream;

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
  }) async {
    sent.add(<String, Object?>{
      'type': type,
      'text': text,
      'stickerKey': stickerKey,
      'replyToMessageId': replyToMessageId,
      'mediaId': mediaId,
    });
    return Success(
      ChatMessage.fromMap(<String, dynamic>{
        'senderId': 'alice',
        'senderName': 'Alice',
        'senderAvatar': '',
        'senderRole': 'member',
        'type': type.name,
        'text': text,
        'stickerKey': stickerKey,
        'replyToMessageId': replyToMessageId,
        'createdAt': DateTime(2026, 3, 2),
        'recipientCount': 1,
        'deliveredCount': 0,
        'readCount': 0,
        'reactions': <String, int>{},
      }, id: messageId),
    );
  }

  @override
  Future<Result<ChatMessage>> forwardMessage({
    required String sourceGroupId,
    required String messageId,
    String? destinationGroupId,
    String? destinationChatId,
  }) async {
    forwards.add((
      destinationGroupId: destinationGroupId,
      destinationChatId: destinationChatId,
    ));
    return Success(_bobText());
  }

  @override
  Future<Result<void>> reportMessage({
    required String groupId,
    required String messageId,
    required String reason,
    String details = '',
  }) async {
    reports.add((messageId: messageId, reason: reason));
    return const Success(null);
  }

  @override
  Future<Result<List<ChatMessage>>> getOlderMessages({
    required String groupId,
    required ChatMessage before,
    int limit = 40,
  }) async => const Success(<ChatMessage>[]);

  @override
  Future<Result<void>> addReaction({
    required String groupId,
    required String messageId,
    required String reaction,
  }) async => const Success(null);

  @override
  Future<Result<void>> deleteMessage({
    required String groupId,
    required String messageId,
  }) async => const Success(null);

  @override
  Future<Result<ChatMessage>> editMessage({
    required String groupId,
    required String messageId,
    required String text,
  }) async => Success(_bobText());

  @override
  Future<Result<void>> markAsRead({
    required String groupId,
    required List<String> messageIds,
  }) async => const Success(null);

  @override
  Future<Result<void>> markAsDelivered({
    required String groupId,
    required List<String> messageIds,
  }) async => const Success(null);

  @override
  Future<Result<void>> pinMessage({
    required String groupId,
    required String messageId,
    required bool pinned,
  }) async => const Success(null);

  @override
  Future<Result<void>> updateChatBackground({
    required String groupId,
    required String? backgroundUrl,
  }) async => const Success(null);

  @override
  Future<Result<ChatMediaUpload>> uploadMedia({
    required String groupId,
    required String mediaId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required void Function(double progress) onProgress,
  }) async => Success(
    ChatMediaUpload(
      mediaUrl: 'groups/$groupId/media/${mediaId}_original.m4a',
      thumbnailUrl: null,
      mediaId: mediaId,
      type: chatMediaTypeFor(contentType: contentType, fileName: fileName),
    ),
  );
}

final class _FakeGroupRepository implements GroupRepository {
  static final current = Group(
    id: 'g1',
    name: 'Anime',
    description: '',
    type: GroupType.public,
    animeId: null,
    founderId: 'alice',
    membersCount: 2,
    maxMembers: 100,
    joinPolicy: JoinPolicy.open,
    isSearchable: true,
    createdAt: DateTime(2026),
    chatBackgroundUrl: null,
    rules: '',
    activityScore: 0,
  );

  static final other = Group(
    id: 'g2',
    name: 'Other group',
    description: '',
    type: GroupType.public,
    animeId: null,
    founderId: 'alice',
    membersCount: 2,
    maxMembers: 100,
    joinPolicy: JoinPolicy.open,
    isSearchable: true,
    createdAt: DateTime(2026),
    chatBackgroundUrl: null,
    rules: '',
    activityScore: 0,
  );

  @override
  Future<Result<Group>> createGroup(GroupDraft draft) async => Success(current);

  @override
  Future<Result<void>> disbandGroup(String groupId) async =>
      const Success<void>(null);

  @override
  Future<Result<Group>> getGroup(String groupId) async => Success(current);

  @override
  Future<Result<GroupMember?>> getMembership(
    String groupId,
    String userId,
  ) async => Success(GroupMember(uid: userId, role: PubgetRank.ronin));

  @override
  Future<Result<void>> joinGroup({
    required String groupId,
    String? inviteId,
    GroupJoinPayload? join,
  }) async => const Success<void>(null);

  @override
  Future<Result<void>> leaveGroup(String groupId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> requestToJoin({required String groupId, GroupJoinPayload? join}) async =>
      const Success<void>(null);

  @override
  Future<Result<List<Group>>> searchGroups(String query) async =>
      Success(<Group>[current]);

  @override
  Future<Result<List<Group>>> listJoinedGroups(String userId) async =>
      Success(<Group>[current, other]);

  @override
  Stream<Result<List<Group>>> watchJoinedGroups(String userId) =>
      Stream.fromFuture(listJoinedGroups(userId));

  @override
  Future<Result<void>> updateGroupSettings({
    required String groupId,
    required GroupSettingsUpdate settings,
  }) async => const Success<void>(null);

  @override
  Future<Result<bool>> isBanned({
    required String groupId,
    required String userId,
  }) async => const Success(false);

  @override
  Future<Result<bool>> hasPendingRequest({
    required String groupId,
    required String userId,
  }) async => const Success(false);

  @override
  Future<Result<List<RoleplayCharacter>>> reservedCharacters(String groupId) async =>
      const Success(<RoleplayCharacter>[]);

  @override
  Future<Result<void>> promoteGroup(String groupId) async =>
      const Success<void>(null);
}


final class _FakePrivateRepository implements PrivateChatRepository {
  @override
  Future<Result<String>> startChat(String otherUserId) async =>
      const Success('c1');

  @override
  Stream<Result<List<PrivateChatSummary>>> watchChats({int limit = 20}) {
    return Stream<Result<List<PrivateChatSummary>>>.value(
      Success(<PrivateChatSummary>[
        PrivateChatSummary(
          id: 'c1',
          participantIds: const <String>['alice', 'dana'],
          userA: 'alice',
          userB: 'dana',
          lastMessageAt: DateTime(2026),
          lastMessageText: 'hi',
          lastMessageSenderId: 'dana',
          createdAt: DateTime(2026),
          participants: const <String, PrivateChatParticipant>{
            'dana': PrivateChatParticipant(displayName: 'Dana', avatarUrl: ''),
          },
        ),
      ]),
    );
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
