import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

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
      return Success<PublicProfile>(
        PublicProfile.fromMap(snapshot.data()!, uid: snapshot.id),
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
      await _firestore.collection('users').doc(userId).update(update.toMap());
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
    try {
      final ref = _storage.ref('users/$userId/avatar.jpg');
      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final url = await snapshot.ref.getDownloadURL();
      await _firestore.collection('users').doc(userId).update({
        'avatarUrl': url,
      });
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
