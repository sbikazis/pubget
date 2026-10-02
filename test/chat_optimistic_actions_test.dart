import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/groups/providers/chat_provider.dart';
import 'package:pubget/features/groups/repositories/chat_repository.dart';
import 'package:pubget/features/private_chat/providers/private_chat_provider.dart';
import 'package:pubget/features/private_chat/repositories/private_chat_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A reaction toggle and a delete are answered by the server only after a round
/// trip. These pin that the screen shows the result the moment the user acts,
/// that the watch stream is still what finally decides, and that neither one
/// blinks backwards while the answer is on its way.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('group chat', () {
    test('a reaction shows on the bubble before the server answers', () async {
      final repository = _GatedChatRepository();
      final provider = ChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(groupId: 'g1', currentUserId: 'alice');
      await repository.emit(<ChatMessage>[_bob()]);

      final operation = provider.addReaction('m-bob', '🔥');
      // Nothing has been awaited yet: the pill is already there.
      expect(provider.messages.single.reactions, <String, int>{'🔥': 1});
      expect(provider.messages.single.hasReacted('🔥', 'alice'), isTrue);
      expect(repository.reactions, <(String, String)>[('m-bob', '🔥')]);

      repository.completeReaction(const Success(null));
      await operation;
    });

    test('tapping a reaction this account already owns takes it back', () async {
      final repository = _GatedChatRepository();
      final provider = ChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(groupId: 'g1', currentUserId: 'alice');
      await repository.emit(<ChatMessage>[_bob(reactions: <String, int>{'🔥': 1})]);

      final operation = provider.addReaction('m-bob', '🔥');
      // The server toggles, so the direction has to come from the last answer
      // it gave in reactionUsers — otherwise the pill would flicker up first.
      expect(provider.messages.single.reactions, isEmpty);
      expect(provider.messages.single.hasReacted('🔥', 'alice'), isFalse);

      repository.completeReaction(const Success(null));
      await operation;
    });

    test('a snapshot from before the commit does not blink the emoji back', () async {
      final repository = _GatedChatRepository();
      final provider = ChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(groupId: 'g1', currentUserId: 'alice');
      await repository.emit(<ChatMessage>[_bob()]);

      final operation = provider.addReaction('m-bob', '🔥');
      // An unrelated write in the same query re-emits the page with the
      // pre-commit reactions. The device's answer stays on top.
      await repository.emit(<ChatMessage>[_bob(), _bob(id: 'm-next', text: 'hi')]);
      expect(provider.messages.first.reactions, <String, int>{'🔥': 1});

      // The server's own copy, once it lands, is what the message carries.
      repository.completeReaction(const Success(null));
      await operation;
      await repository.emit(<ChatMessage>[
        _bob(reactions: <String, int>{'🔥': 1}),
        _bob(id: 'm-next', text: 'hi'),
      ]);
      expect(provider.messages.first.reactions, <String, int>{'🔥': 1});
    });

    test('a failed reaction goes back without a second copy', () async {
      final repository = _GatedChatRepository();
      final provider = ChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(groupId: 'g1', currentUserId: 'alice');
      await repository.emit(<ChatMessage>[_bob()]);

      final operation = provider.addReaction('m-bob', '🔥');
      repository.completeReaction(const FailureResult(NetworkError()));
      await operation;

      expect(provider.messages.single.reactions, isEmpty);
      expect(provider.messages.single.hasReacted('🔥', 'alice'), isFalse);
      expect(provider.messages, hasLength(1));
    });

    test('a second tap while the first is on the wire cannot double-toggle', () async {
      final repository = _GatedChatRepository();
      final provider = ChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(groupId: 'g1', currentUserId: 'alice');
      await repository.emit(<ChatMessage>[_bob()]);

      final first = provider.addReaction('m-bob', '🔥');
      final second = provider.addReaction('m-bob', '🔥');
      // One server call, not two: two would toggle into the state the user
      // never asked for.
      expect(repository.reactions, hasLength(1));
      expect(provider.messages.single.reactions, <String, int>{'🔥': 1});

      repository.completeReaction(const Success(null));
      await Future.wait<void>(<Future<void>>[first, second]);
      expect(provider.messages.single.reactions, <String, int>{'🔥': 1});
    });

    test('a delete hides the bubble before the server answers', () async {
      final repository = _GatedChatRepository();
      final provider = ChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(groupId: 'g1', currentUserId: 'alice');
      await repository.emit(<ChatMessage>[_bob()]);

      final operation = provider.deleteMessage('m-bob');
      expect(provider.messages.single.isDeleted, isTrue);
      expect(repository.deletes, <String>['m-bob']);

      repository.completeDelete(const Success(null));
      await operation;
    });

    test('a snapshot from before the delete commit does not resurrect the '
        'bubble, and the server tombstone is the one that stays', () async {
      final repository = _GatedChatRepository();
      final provider = ChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(groupId: 'g1', currentUserId: 'alice');
      await repository.emit(<ChatMessage>[_bob()]);

      final operation = provider.deleteMessage('m-bob');
      await repository.emit(<ChatMessage>[_bob(), _bob(id: 'm-next', text: 'hi')]);
      expect(provider.messages.first.isDeleted, isTrue);

      repository.completeDelete(const Success(null));
      await operation;
      final serverStamp = DateTime(2026, 5, 5);
      await repository.emit(<ChatMessage>[
        _bob(deletedAt: serverStamp),
        _bob(id: 'm-next', text: 'hi'),
      ]);
      // The device's clock is not what the conversation keeps.
      expect(provider.messages.first.deletedAt, serverStamp);
    });

    test('a failed delete puts the message back', () async {
      final repository = _GatedChatRepository();
      final provider = ChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(groupId: 'g1', currentUserId: 'alice');
      await repository.emit(<ChatMessage>[_bob()]);

      final operation = provider.deleteMessage('m-bob');
      repository.completeDelete(const FailureResult(PermissionError()));
      await operation;

      expect(provider.messages.single.isDeleted, isFalse);
      expect(provider.messages.single.text, 'hello from bob');
      expect(provider.messages, hasLength(1));
    });

    test('a delete answered by the server first is not undone by the device', () async {
      final repository = _GatedChatRepository();
      final provider = ChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(groupId: 'g1', currentUserId: 'alice');
      await repository.emit(<ChatMessage>[_bob()]);

      final operation = provider.deleteMessage('m-bob');
      final serverStamp = DateTime(2026, 5, 5);
      await repository.emit(<ChatMessage>[_bob(deletedAt: serverStamp)]);
      await pumpEventQueue();
      repository.completeDelete(const FailureResult(NetworkError()));
      await operation;

      // The stream already said what happened, so a late transport error must
      // not bring the message back.
      expect(provider.messages.single.deletedAt, serverStamp);
    });

    test('the row token moves with a local patch, or the bubble never repaints',
        () async {
      final repository = _GatedChatRepository();
      final provider = ChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(groupId: 'g1', currentUserId: 'alice');
      await repository.emit(<ChatMessage>[_bob()]);

      final before = provider.contentRevision;
      final operation = provider.deleteMessage('m-bob');
      expect(provider.contentRevision, greaterThan(before));

      repository.completeDelete(const Success(null));
      await operation;
    });
  });

  group('private chat', () {
    test('a reaction and a delete both land on the screen immediately', () async {
      final repository = _GatedPrivateRepository();
      final provider = PrivateChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(chatId: 'c1', currentUserId: 'alice');
      await repository.emit(<ChatMessage>[_mine()]);

      final react = provider.addReaction('m-mine', '🔥');
      expect(provider.messages.single.reactions, <String, int>{'🔥': 1});
      repository.completeReaction(const Success(null));
      await react;

      final remove = provider.deleteMessage('m-mine');
      expect(provider.messages.single.isDeleted, isTrue);
      repository.completeDelete(const Success(null));
      await remove;
    });

    test('a failed private reaction and a failed private delete roll back',
        () async {
      final repository = _GatedPrivateRepository();
      final provider = PrivateChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(chatId: 'c1', currentUserId: 'alice');
      await repository.emit(<ChatMessage>[_mine()]);

      final react = provider.addReaction('m-mine', '🔥');
      repository.completeReaction(const FailureResult(NetworkError()));
      await react;
      expect(provider.messages.single.reactions, isEmpty);

      final remove = provider.deleteMessage('m-mine');
      repository.completeDelete(const FailureResult(NetworkError()));
      await remove;
      expect(provider.messages.single.isDeleted, isFalse);
      expect(provider.messages, hasLength(1));
    });

    test('a private snapshot from before the commit does not undo the '
        'device answer', () async {
      final repository = _GatedPrivateRepository();
      final provider = PrivateChatProvider(repository: repository);
      addTearDown(provider.dispose);
      await provider.open(chatId: 'c1', currentUserId: 'alice');
      await repository.emit(<ChatMessage>[_mine()]);

      ChatMessage mine() => provider.messages.singleWhere(
        (message) => message.id == 'm-mine',
      );

      final react = provider.addReaction('m-mine', '🔥');
      await repository.emit(<ChatMessage>[_mine(), _bob(id: 'm-bob-2')]);
      expect(mine().reactions, <String, int>{'🔥': 1});

      final remove = provider.deleteMessage('m-mine');
      await repository.emit(<ChatMessage>[_mine(), _bob(id: 'm-bob-2')]);
      expect(mine().isDeleted, isTrue);

      repository.completeReaction(const Success(null));
      repository.completeDelete(const Success(null));
      await Future.wait<void>(<Future<void>>[react, remove]);
    });
  });
}

ChatMessage _bob({
  String id = 'm-bob',
  String text = 'hello from bob',
  Map<String, int> reactions = const <String, int>{},
  DateTime? deletedAt,
}) => ChatMessage.fromMap(<String, dynamic>{
  'senderId': 'bob',
  'senderName': 'Bob',
  'senderAvatar': '',
  'senderRole': 'member',
  'type': 'text',
  'text': text,
  'createdAt': DateTime(2026, 3, 1),
  'recipientCount': 1,
  'reactions': reactions,
  'reactionUsers': reactions.keys.isEmpty
      ? const <String, Object?>{}
      : <String, Object?>{
          for (final entry in reactions.entries)
            entry.key: <String, Object?>{'alice': true},
        },
  'deletedAt': deletedAt,
}, id: id);

ChatMessage _mine() => ChatMessage.fromMap(<String, dynamic>{
  'senderId': 'alice',
  'senderName': 'Alice',
  'senderAvatar': '',
  'senderRole': 'member',
  'type': 'text',
  'text': 'mine',
  'createdAt': DateTime(2026, 3, 2),
  'recipientCount': 1,
  'reactions': <String, int>{},
}, id: 'm-mine');

final class _GatedChatRepository implements ChatRepository {
  final stream = StreamController<Result<List<ChatMessage>>>.broadcast();
  final reactions = <(String, String)>[];
  final deletes = <String>[];
  final reactionGates = <Completer<Result<void>>>[];
  final deleteGates = <Completer<Result<void>>>[];

  Future<void> emit(List<ChatMessage> messages) async {
    stream.add(Success(messages));
    await pumpEventQueue();
  }

  void completeReaction(Result<void> result) =>
      reactionGates.removeAt(0).complete(result);

  void completeDelete(Result<void> result) =>
      deleteGates.removeAt(0).complete(result);

  @override
  Stream<Result<List<ChatMessage>>> watchMessages(
    String groupId, {
    int limit = 40,
  }) => stream.stream;

  @override
  Future<Result<void>> addReaction({
    required String groupId,
    required String messageId,
    required String reaction,
  }) {
    reactions.add((messageId, reaction));
    final gate = Completer<Result<void>>();
    reactionGates.add(gate);
    return gate.future;
  }

  @override
  Future<Result<void>> deleteMessage({
    required String groupId,
    required String messageId,
  }) {
    deletes.add(messageId);
    final gate = Completer<Result<void>>();
    deleteGates.add(gate);
    return gate.future;
  }

  @override
  Future<Result<void>> markAsDelivered({
    required String groupId,
    required List<String> messageIds,
  }) async => const Success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not used here');
}

final class _GatedPrivateRepository implements PrivateChatRepository {
  final stream = StreamController<Result<List<ChatMessage>>>.broadcast();
  final reactionGates = <Completer<Result<void>>>[];
  final deleteGates = <Completer<Result<void>>>[];

  Future<void> emit(List<ChatMessage> messages) async {
    stream.add(Success(messages));
    await pumpEventQueue();
  }

  void completeReaction(Result<void> result) =>
      reactionGates.removeAt(0).complete(result);

  void completeDelete(Result<void> result) =>
      deleteGates.removeAt(0).complete(result);

  @override
  Stream<Result<List<ChatMessage>>> watchMessages(
    String chatId, {
    int limit = 40,
  }) => stream.stream;

  @override
  Future<Result<void>> addReaction({
    required String chatId,
    required String messageId,
    required String reaction,
  }) {
    final gate = Completer<Result<void>>();
    reactionGates.add(gate);
    return gate.future;
  }

  @override
  Future<Result<void>> deleteMessage({
    required String chatId,
    required String messageId,
  }) {
    final gate = Completer<Result<void>>();
    deleteGates.add(gate);
    return gate.future;
  }

  @override
  Future<Result<void>> markAsDelivered({
    required String chatId,
    required List<String> messageIds,
  }) async => const Success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not used here');
}