import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/features/groups/models/group_models.dart';
import 'package:pubget/features/groups/repositories/firebase_group_repositories.dart';
import 'package:pubget/features/groups/repositories/group_repository.dart';
import 'package:pubget/features/groups/repositories/group_worker_client.dart';

class FakeGroupWorkerClient implements GroupWorkerClient {
  FakeGroupWorkerClient({
    this.response = const <String, dynamic>{},
    this.error,
  });

  final Map<String, dynamic> response;
  final Object? error;
  final paths = <String>[];
  final payloads = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    paths.add(path);
    payloads.add(payload);
    if (error != null) throw error!;
    return response;
  }
}

GroupDraft draft() => GroupDraft(
  name: 'Anime Club',
  description: 'A friendly group',
  type: GroupType.public,
  animeId: null,
  joinPolicy: JoinPolicy.open,
  isSearchable: true,
  rules: 'Be kind',
  maxMembers: 40,
  idempotencyKey: 'wizard-1',
);

Map<String, dynamic> createdGroup() => <String, dynamic>{
  'groupId': 'group-1',
  'group': <String, dynamic>{
    'name': 'Anime Club',
    'description': 'A friendly group',
    'type': 'public',
    'founderId': 'founder-1',
    'membersCount': 1,
    'maxMembers': 40,
    'joinPolicy': 'open',
    'isSearchable': true,
    'rules': 'Be kind',
    'createdAt': '2026-11-19T20:00:00.000Z',
  },
};

void main() {
  group('group creation through the Worker', () {
    test('posts the draft to /groups/create and returns the group', () async {
      final worker = FakeGroupWorkerClient(response: createdGroup());
      final repository = FirebaseGroupRepository(workerClient: worker);

      final result = await repository.createGroup(draft());

      expect(result.isSuccess, isTrue, reason: result.failureOrNull?.message);
      expect(worker.paths, <String>['/groups/create']);
      expect(worker.payloads.single['idempotencyKey'], 'wizard-1');
      expect(worker.payloads.single['type'], 'public');
      final group = result.valueOrNull!;
      expect(group.id, 'group-1');
      expect(group.createdAt, DateTime.utc(2026, 11, 19, 20));
    });

    test(
      'a backend 503 is unavailable, never a false offline diagnosis',
      () async {
        final worker = FakeGroupWorkerClient(
          error: const GroupWorkerException(503, 'Group creation failed.'),
        );
        final repository = FirebaseGroupRepository(workerClient: worker);

        final result = await repository.createGroup(draft());

        expect(result.failureOrNull, isA<UnavailableError>());
        expect(result.failureOrNull, isNot(isA<NetworkError>()));
      },
    );

    test(
      'validation and permission statuses keep their own failure types',
      () async {
        final invalid = FirebaseGroupRepository(
          workerClient: FakeGroupWorkerClient(
            error: const GroupWorkerException(
              400,
              'Group details are invalid.',
            ),
          ),
        );
        final forbidden = FirebaseGroupRepository(
          workerClient: FakeGroupWorkerClient(
            error: const GroupWorkerException(401, 'Please sign in again.'),
          ),
        );

        expect(
          (await invalid.createGroup(draft())).failureOrNull,
          isA<ValidationError>(),
        );
        expect(
          (await forbidden.createGroup(draft())).failureOrNull,
          isA<PermissionError>(),
        );
      },
    );

    test('entitlements are read from the Worker with the same model', () async {
      final worker = FakeGroupWorkerClient(
        response: <String, dynamic>{'maxMembers': 250, 'canCreateGroups': true},
      );
      final repository = FirebaseGroupRepository(workerClient: worker);

      final result = await repository.createGroupEntitlements();

      expect(worker.paths, <String>['/groups/entitlements']);
      expect(result.valueOrNull?.maxMembers, 250);
      expect(result.valueOrNull?.canCreateGroups, isTrue);
    });
  });

  group('HTTP Worker client', () {
    test('sends the Firebase ID token and decodes success bodies', () async {
      final httpClient = MockClient((request) async {
        expect(Uri.parse(request.url.toString()).path, '/groups/create');
        expect(request.headers['Authorization'], 'Bearer id-token');
        return http.Response(jsonEncode(<String, dynamic>{'ok': true}), 200);
      });
      final client = HttpGroupWorkerClient(
        tokenProvider: () async => 'id-token',
        httpClient: httpClient,
        workerUrl: 'https://worker.example',
      );

      final body = await client.post('/groups/create', <String, dynamic>{});

      expect(body['ok'], isTrue);
    });

    test('rejects a missing token before making a request', () async {
      var called = false;
      final client = HttpGroupWorkerClient(
        tokenProvider: () async => null,
        httpClient: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
        workerUrl: 'https://worker.example',
      );

      await expectLater(
        client.post('/groups/create', const <String, dynamic>{}),
        throwsA(
          isA<GroupWorkerException>().having(
            (error) => error.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
      expect(called, isFalse);
    });
  });
}
