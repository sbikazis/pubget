import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/features/groups/models/chat_models.dart';
import 'package:pubget/features/groups/repositories/firebase_chat_repository.dart';
import 'package:pubget/features/groups/repositories/group_worker_client.dart';
import 'package:pubget/features/groups/services/chat_send_reliability.dart';
import 'package:pubget/features/private_chat/repositories/firebase_private_chat_repository.dart';
import 'package:pubget/features/social/repositories/firebase_social_repository.dart';

final class _FakeWorkerClient implements GroupWorkerClient {
  const _FakeWorkerClient({this.response = const <String, dynamic>{}, this.error});

  final Map<String, dynamic> response;
  final Object? error;
  final calls = <({String path, Map<String, dynamic> payload})>[];

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    calls.add((path: path, payload: payload));
    if (error != null) throw error!;
    return response;
  }
}

Map<String, dynamic> _messageMap() => <String, dynamic>{
  'senderId': 'alice',
  'senderName': 'Alice',
  'senderAvatar': '',
  'senderRole': 'member',
  'type': 'text',
  'text': 'hello',
  'createdAt': DateTime(2026, 11, 25),
  'recipientCount': 1,
  'deliveredCount': 0,
  'readCount': 0,
  'reactions': <String, int>{},
};

void main() {
  test('group chat sends through the free Worker callable route', () async {
    final worker = _FakeWorkerClient(response: <String, dynamic>{
      'message': _messageMap(),
      'messageId': 'm-1',
    });
    final repository = FirebaseChatRepository(workerClient: worker);

    final result = await repository.sendMessage(
      groupId: 'g-1',
      messageId: 'm-1',
      type: ChatMessageType.text,
      text: 'hello',
    );

    expect(result, isA<Success<ChatMessage>>());
    expect(worker.calls.single.path, '/callables/sendGroupMessage');
    expect(worker.calls.single.payload['groupId'], 'g-1');
  });

  test('a Worker 503 is a chat backend outage, never a lost connection', () async {
    final repository = FirebaseChatRepository(
      workerClient: const _FakeWorkerClient(
        error: GroupWorkerException(503, 'Callable request failed.'),
      ),
    );

    final result = await repository.sendMessage(
      groupId: 'g-1',
      messageId: 'm-2',
      type: ChatMessageType.text,
      text: 'hello',
    );

    final failure = (result as FailureResult<ChatMessage>).failure;
    expect(failure, isA<UnavailableError>());
    expect(chatFailureCode(failure), ChatFailureCodes.serviceUnavailable);
  });

  test('private chat routes through the Worker callable bridge', () async {
    final worker = _FakeWorkerClient(response: <String, dynamic>{'chatId': 'c-1'});
    final repository = FirebasePrivateChatRepository(workerClient: worker);

    final result = await repository.startChat('bob');

    expect(result, isA<Success<String>>());
    expect(worker.calls.single.path, '/callables/startPrivateChat');
    expect(worker.calls.single.payload['otherUserId'], 'bob');
  });

  test('social actions route through the Worker and keep honest failures', () async {
    final worker = _FakeWorkerClient(
      error: const GroupWorkerException(503, 'Callable request failed.'),
    );
    final repository = FirebaseSocialRepository(workerClient: worker);

    final result = await repository.giveRespect(toUserId: 'bob', value: 3);

    expect(worker.calls.single.path, '/callables/giveRespect');
    expect((result as FailureResult<void>).failure, isA<UnavailableError>());
  });
}
