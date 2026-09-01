import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/pubget_user.dart';
import 'user_repository.dart';

final class FirebaseUserRepository implements UserRepository {
  FirebaseUserRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

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
      final reference = _storage.ref('users/$userId/avatar');
      final snapshot = await reference.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      return Success<String>(await snapshot.ref.getDownloadURL());
    } on Object catch (error) {
      return FailureResult<String>(_mapFailure(error));
    }
  }

  static Failure _mapFailure(Object error) {
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
