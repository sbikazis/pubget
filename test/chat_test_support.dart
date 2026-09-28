import 'dart:async';
import 'dart:typed_data';

import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/repositories/chat_repository.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';
import 'package:pubget/features/private_chat/models/private_chat_models.dart';
import 'package:pubget/features/private_chat/repositories/private_chat_repository.dart';

/// In-memory chat/group/private-chat repositories shared by the chat widget
/// tests. They record what the UI asked the server to do, so tests can assert
/// on the real repository call instead of a mocked-away no-op.

ChatMessage fakeBobText() => ChatMessage.fromMap(<String, dynamic>{
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

final class FakeChatRepository implements ChatRepository {
  final stream = StreamController<Result<List<ChatMessage>>>.broadcast();
  final sent = <Map<String, Object?>>[];
  final reports = <({String messageId, String reason})>[];
  final forwards =
      <({String? destinationGroupId, String? destinationChatId})>[];
  final pinCalls = <(String, bool)>[];
  final deletes = <String>[];
  final edits = <(String, String)>[];
  final reactions = <(String, String)>[];

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
    return Success(fakeBobText());
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
  }) async {
    reactions.add((messageId, reaction));
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteMessage({
    required String groupId,
    required String messageId,
  }) async {
    deletes.add(messageId);
    return const Success(null);
  }

  @override
  Future<Result<ChatMessage>> editMessage({
    required String groupId,
    required String messageId,
    required String text,
  }) async {
    edits.add((messageId, text));
    return Success(fakeBobText());
  }

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
  }) async {
    pinCalls.add((messageId, pinned));
    return const Success(null);
  }

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
    void Function()? onBytesUploaded,
  }) async {
    onProgress(1);
    onBytesUploaded?.call();
    return Success(
      ChatMediaUpload(
        mediaUrl: 'groups/$groupId/media/${mediaId}_original.m4a',
        thumbnailUrl: null,
        mediaId: mediaId,
        type: chatMediaTypeFor(contentType: contentType, fileName: fileName),
      ),
    );
  }

  @override
  Future<Result<ChatMediaUpload?>> findReadyMedia({
    required String groupId,
    required String mediaId,
  }) async => const Success(null);
}

final class FakeGroupRepository implements GroupRepository {
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
  Future<Result<void>> requestToJoin({
    required String groupId,
    GroupJoinPayload? join,
  }) async => const Success<void>(null);

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
  Future<Result<List<RoleplayCharacter>>> reservedCharacters(
    String groupId,
  ) async => const Success(<RoleplayCharacter>[]);

  @override
  Future<Result<void>> promoteGroup(String groupId) async =>
      const Success<void>(null);
}

final class FakePrivateRepository implements PrivateChatRepository {
  /// What the UI asked the server to do, for assertions.
  final pinCalls = <(String, bool)>[];
  final reports = <(String, String)>[];
  final forwards = <(String, String?)>[];
  final editCalls = <(String, String)>[];

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

  @override
  Future<Result<ChatMediaUpload?>> findReadyMedia({
    required String chatId,
    required String mediaId,
  }) async => const Success<ChatMediaUpload?>(null);

  @override
  Future<Result<void>> pinMessage({
    required String chatId,
    required String messageId,
    required bool pinned,
  }) async {
    pinCalls.add((messageId, pinned));
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> addReaction({
    required String chatId,
    required String messageId,
    required String reaction,
  }) async => const Success<void>(null);

  @override
  Future<Result<ChatMessage>> editMessage({
    required String chatId,
    required String messageId,
    required String text,
  }) async {
    editCalls.add((messageId, text));
    return Success<ChatMessage>(textMessage(messageId, text));
  }

  @override
  Future<Result<void>> reportMessage({
    required String chatId,
    required String messageId,
    required String reason,
    String details = '',
  }) async {
    reports.add((messageId, reason));
    return const Success<void>(null);
  }

  @override
  Future<Result<ChatMessage>> forwardMessage({
    required String sourceChatId,
    required String messageId,
    String? destinationGroupId,
    String? destinationChatId,
  }) async {
    forwards.add((messageId, destinationGroupId ?? destinationChatId));
    return Success<ChatMessage>(textMessage('fwd', 'forwarded'));
  }
}

/// A text message with the fields the action/pin tests care about.
ChatMessage textMessage(
  String id,
  String body, {
  bool mine = false,
  DateTime? pinnedAt,
  DateTime? deletedAt,
  String? replyToMessageId,
  String? replyPreview,
  Map<String, int> reactions = const <String, int>{},
  DateTime? createdAt,
}) => ChatMessage(
  id: id,
  senderId: mine ? 'alice' : 'bob',
  senderName: mine ? 'Alice' : 'Bob',
  senderAvatar: '',
  senderRole: 'ronin',
  type: ChatMessageType.text,
  text: body,
  mediaUrl: null,
  thumbnailUrl: null,
  mediaId: null,
  replyToMessageId: replyToMessageId,
  replyPreview: replyPreview,
  createdAt: createdAt ?? DateTime(2026, 1, 1, 11),
  editedAt: null,
  deletedAt: deletedAt,
  pinnedAt: pinnedAt,
  reactions: reactions,
  recipientCount: 0,
  deliveredCount: 0,
  readCount: 0,
  isOptimistic: false,
  sendState: ChatSendState.sent,
);

/// [FakePrivateRepository] with a message stream and configurable group
/// forward destinations.
final class FakeRecordingPrivateRepository extends FakePrivateRepository {
  FakeRecordingPrivateRepository({this.groupDestinations = const <String>[]});

  /// Group ids offered as forward destinations.
  final List<String> groupDestinations;
  final stream = StreamController<Result<List<ChatMessage>>>.broadcast();

  @override
  Stream<Result<List<ChatMessage>>> watchMessages(
    String chatId, {
    int limit = 40,
  }) => stream.stream;
}

/// Group repository whose joined list is driven by the test, so the forward
/// sheet can be pointed at a known destination.
final class FakeGroupRepositoryWithDestinations implements GroupRepository {
  FakeGroupRepositoryWithDestinations(this.ids);

  final List<String> ids;

  static Group _group(String id) => Group(
    id: id,
    name: 'Group $id',
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
  Future<Result<List<Group>>> listJoinedGroups(String userId) async =>
      Success<List<Group>>(ids.map(_group).toList());

  @override
  Stream<Result<List<Group>>> watchJoinedGroups(String userId) =>
      Stream.fromFuture(listJoinedGroups(userId));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not used here');
}
