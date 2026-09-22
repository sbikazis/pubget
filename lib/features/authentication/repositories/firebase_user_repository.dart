import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/pubget_user.dart';
import '../models/username_status.dart';
import 'user_repository.dart';

final class FirebaseUserRepository implements UserRepository {
  FirebaseUserRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<Result<PubgetUser>> createUserProfile(PubgetUser user) async {
    try {
      final data = user.toMap()..remove('id');
      await _users.doc(user.id).set(data);
      return Success<PubgetUser>(user);
    } on Object catch (error) {
      return FailureResult<PubgetUser>(_mapFailure(error));
    }
  }

  @override
  Future<Result<PubgetUser?>> getUserProfile(String userId) async {
    try {
      final snapshot = await _users.doc(userId).get();
      if (!snapshot.exists || snapshot.data() == null) {
        return const Success<PubgetUser?>(null);
      }
      final data = Map<String, dynamic>.from(snapshot.data()!);
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) data['createdAt'] = createdAt.toDate();
      return Success<PubgetUser?>(PubgetUser.fromMap(data, id: snapshot.id));
    } on Object catch (error) {
      return FailureResult<PubgetUser?>(_mapFailure(error));
    }
  }

  @override
  Future<Result<PubgetUser>> updateUserProfile(PubgetUser user) async {
    try {
      final data = user.toMap()
        ..remove('id')
        ..remove('createdAt');
      await _users.doc(user.id).set(data, SetOptions(merge: true));
      return Success<PubgetUser>(user);
    } on Object catch (error) {
      return FailureResult<PubgetUser>(_mapFailure(error));
    }
  }

  @override
  Future<Result<String>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final reference = _storage.ref('users/$userId/avatar.jpg');
      final snapshot = await reference.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      return Success<String>(await snapshot.ref.getDownloadURL());
    } on Object catch (error) {
      return FailureResult<String>(_mapFailure(error));
    }
  }

  @override
  Future<Result<UsernameStatus>> checkUsernameAvailable(String username) async {
    try {
      final response = await _functions
          .httpsCallable('checkUsernameAvailable')
          .call<Map<String, dynamic>>({'username': username});
      final data = response.data;
      final available = data['available'] as bool? ?? false;
      final normalized = data['normalized'] as String? ?? '';
      final reason = data['reason'] as String?;
      if (available) return Success<UsernameStatus>(UsernameStatus.available(normalized));
      final cause = switch (reason) {
        'empty' => UsernameStatusCause.empty,
        'invalid' || 'too-short' || 'too-long' ||
        'invalid-characters' || 'invalid-start' => UsernameStatusCause.invalid,
        'taken' => UsernameStatusCause.taken,
        _ => UsernameStatusCause.serverError,
      };
      return Success<UsernameStatus>(UsernameStatus.unavailable(cause));
    } on Object catch (error) {
      return FailureResult<UsernameStatus>(_mapFailure(error));
    }
  }

  @override
  Future<Result<String>> reserveUsername(String username) async {
    try {
      final response = await _functions
          .httpsCallable('reserveUsername')
          .call<Map<String, dynamic>>({'username': username});
      final normalized = response.data['normalized'] as String? ?? '';
      if (normalized.isEmpty) {
        return const FailureResult<String>(
          UnknownError('The username could not be reserved.'),
        );
      }
      return Success<String>(normalized);
    } on Object catch (error) {
      return FailureResult<String>(_mapFailure(error));
    }
  }

  @override
  Future<Result<void>> updateLanguage(String language) async {
    try {
      await _functions
          .httpsCallable('updateSocialProfile')
          .call<void>({'language': language});
      return const Success<void>(null);
    } on Object catch (error) {
      return FailureResult<void>(_mapFailure(error));
    }
  }

  static Failure _mapFailure(Object error) {
    if (error is FirebaseFunctionsException) {
      return switch (error.code) {
        'permission-denied' || 'unauthorized' => const PermissionError(
          'You do not have permission to update this profile.',
        ),
        'not-found' => const NotFoundError('Profile not found.'),
        'already-exists' => const ValidationError(
          'This username is already taken.',
        ),
        'unavailable' || 'deadline-exceeded' => const NetworkError(
          'Check your connection and try again.',
        ),
        _ => UnknownError(error.message ?? 'Profile update failed.'),
      };
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' || 'unauthorized' => const PermissionError(
          'You do not have permission to update this profile.',
        ),
        'not-found' => const NotFoundError('Profile not found.'),
        'unavailable' || 'deadline-exceeded' => const NetworkError(
          'Check your connection and try again.',
        ),
        _ => UnknownError(error.message ?? 'Profile update failed.'),
      };
    }
    return const UnknownError('We could not save this profile.');
  }
}
