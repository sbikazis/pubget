import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../groups/repositories/group_worker_client.dart';
import '../models/social_models.dart';
import 'social_repository.dart';

final class FirebaseSocialRepository implements SocialRepository {
  FirebaseSocialRepository({
    FirebaseFirestore? firestore,
    // Retained for wiring compatibility; writes now use the free Worker path.
    FirebaseFunctions? functions,
    GroupWorkerClient? workerClient,
  }) : _firestoreOverride = firestore,
       _workerClient = workerClient ?? HttpGroupWorkerClient.forFirebase();

  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;
  final GroupWorkerClient _workerClient;

  @override
  Future<Result<SocialSnapshot>> getSnapshot(String userId) async {
    try {
      final results =
          await Future.wait(<Future<QuerySnapshot<Map<String, dynamic>>>>[
            _firestore
                .collection('respects')
                .where('fromUserId', isEqualTo: userId)
                .get(),
            _firestore
                .collection('respects')
                .where('toUserId', isEqualTo: userId)
                .get(),
            _firestore
                .collection('friendships')
                .where('userIds', arrayContains: userId)
                .get(),
          ]);
      return Success<SocialSnapshot>(
        SocialSnapshot(
          givenRespect: results[0].docs
              .map((doc) => RespectRelation.fromMap(doc.data()))
              .toList(growable: false),
          receivedRespect: results[1].docs
              .map((doc) => RespectRelation.fromMap(doc.data()))
              .toList(growable: false),
          friendships: results[2].docs
              .map((doc) => Friendship.fromMap(doc.data()))
              .toList(growable: false),
        ),
      );
    } on Object catch (error) {
      return FailureResult<SocialSnapshot>(_mapFailure(error));
    }
  }

  @override
  Future<Result<void>> giveRespect({
    required String toUserId,
    required int value,
  }) => _call('giveRespect', <String, dynamic>{
    'toUserId': toUserId,
    'value': value,
  });

  @override
  Future<Result<void>> sendFriendRequest({required String toUserId}) =>
      _call('sendFriendRequest', <String, dynamic>{'toUserId': toUserId});

  @override
  Future<Result<void>> respondToFriendRequest({
    required String otherUserId,
    required String response,
  }) => _call('respondToFriendRequest', <String, dynamic>{
    'otherUserId': otherUserId,
    'response': response,
  });

  @override
  Future<Result<void>> removeFriend({required String otherUserId}) =>
      _call('removeFriend', <String, dynamic>{'otherUserId': otherUserId});

  @override
  Future<Result<void>> blockUser({required String otherUserId}) =>
      _call('blockUser', <String, dynamic>{'otherUserId': otherUserId});

  @override
  Future<Result<void>> unblockUser({required String otherUserId}) =>
      _call('unblockUser', <String, dynamic>{'otherUserId': otherUserId});

  Future<Result<void>> _call(String name, Map<String, dynamic> data) async {
    try {
      await _workerClient.post('/callables/$name', data);
      return const Success<void>(null);
    } on Object catch (error) {
      return FailureResult<void>(_mapFailure(error));
    }
  }

  static Failure _mapFailure(Object error) {
    if (error is GroupWorkerException) {
      return switch (error.statusCode) {
        401 || 403 => PermissionError(error.message),
        404 => NotFoundError(error.message),
        429 => NetworkError(error.message),
        400 || 409 => ValidationError(error.message),
        >= 500 => UnavailableError(error.message),
        _ => UnknownError(error.message),
      };
    }
    if (error is FirebaseFunctionsException) {
      return switch (error.code) {
        'unauthenticated' || 'permission-denied' => const PermissionError(
          'You do not have permission to perform this action.',
        ),
        'invalid-argument' || 'failed-precondition' => ValidationError(
          error.message ?? 'This social action is not available.',
        ),
        'resource-exhausted' || 'unavailable' => const NetworkError(
          'Please wait a moment and try again.',
        ),
        _ => UnknownError(error.message ?? 'Social action failed.'),
      };
    }
    return const UnknownError('We could not complete that social action.');
  }
}
