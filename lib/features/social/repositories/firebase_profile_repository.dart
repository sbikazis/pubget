import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../authentication/models/pubget_user.dart';
import '../models/public_profile.dart';
import 'profile_repository.dart';

final class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository({
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

  @override
  Future<Result<PublicProfile>> getPublicProfile(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('public_profiles')
          .doc(userId)
          .get();
      if (!snapshot.exists || snapshot.data() == null) {
        return const FailureResult<PublicProfile>(
          NotFoundError('This profile is not available.'),
        );
      }
      final data = Map<String, dynamic>.from(snapshot.data()!);
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) data['createdAt'] = createdAt.toDate();
      return Success<PublicProfile>(
        PublicProfile.fromMap(data, uid: snapshot.id),
      );
    } on Object catch (error) {
      return FailureResult<PublicProfile>(_mapFailure(error));
    }
  }

  @override
  Future<Result<PubgetUser>> getOwnProfile(String userId) async {
    try {
      final snapshot = await _firestore.collection('users').doc(userId).get();
      if (!snapshot.exists || snapshot.data() == null) {
        return const FailureResult<PubgetUser>(
          NotFoundError('Your profile is not available yet.'),
        );
      }
      final data = Map<String, dynamic>.from(snapshot.data()!);
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) data['createdAt'] = createdAt.toDate();
      return Success<PubgetUser>(PubgetUser.fromMap(data, id: snapshot.id));
    } on Object catch (error) {
      return FailureResult<PubgetUser>(_mapFailure(error));
    }
  }

  @override
  Future<Result<PubgetUser>> updateProfile(
    String userId,
    ProfileUpdate update,
  ) async {
    try {
      await _functions
          .httpsCallable('updateSocialProfile')
          .call<void>(update.toMap());
      final result = await getOwnProfile(userId);
      return result;
    } on Object catch (error) {
      return FailureResult<PubgetUser>(_mapFailure(error));
    }
  }

  @override
  Future<Result<String>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    return _uploadImage(
      userId: userId,
      bytes: bytes,
      contentType: contentType,
      path: 'users/$userId/avatar.jpg',
      field: 'avatarUrl',
    );
  }

  @override
  Future<Result<String>> uploadCover({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    return _uploadImage(
      userId: userId,
      bytes: bytes,
      contentType: contentType,
      path: 'users/$userId/cover.jpg',
      field: 'coverUrl',
    );
  }

  Future<Result<String>> _uploadImage({
    required String userId,
    required Uint8List bytes,
    required String contentType,
    required String path,
    required String field,
  }) async {
    try {
      final ref = _storage.ref(path);
      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final url = await snapshot.ref.getDownloadURL();
      await _firestore.collection('users').doc(userId).update({field: url});
      return Success<String>(url);
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
    return const UnknownError('We could not update this profile.');
  }
}
