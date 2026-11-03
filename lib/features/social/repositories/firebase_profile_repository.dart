import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/firebase_failure_mapper.dart';
import '../../../core/errors/result.dart';
import '../../authentication/models/pubget_user.dart';
import '../models/public_profile.dart';
import 'profile_repository.dart';

/// Firebase-backed profile data adapter.
///
/// Profile fields remain in Firestore. Media upload is isolated behind the
/// repository so the storage provider can be replaced without changing UI
/// callers; this implementation retains the currently deployed Storage paths
/// until the R2 profile-key resolver is wired into the app composition.
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
          NotFoundError('Profile not found.'),
        );
      }
      final data = Map<String, dynamic>.from(snapshot.data()!);
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) data['createdAt'] = createdAt.toDate();
      return Success<PublicProfile>(
        PublicProfile.fromMap(data, uid: snapshot.id),
      );
    } on Object catch (error) {
      return FailureResult<PublicProfile>(mapFirebaseFailure(error));
    }
  }

  @override
  Future<Result<PubgetUser>> getOwnProfile(String userId) async {
    try {
      final snapshot = await _firestore.collection('users').doc(userId).get();
      if (!snapshot.exists || snapshot.data() == null) {
        return const FailureResult<PubgetUser>(
          NotFoundError('Profile not found.'),
        );
      }
      final data = Map<String, dynamic>.from(snapshot.data()!);
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) data['createdAt'] = createdAt.toDate();
      return Success<PubgetUser>(PubgetUser.fromMap(data, id: snapshot.id));
    } on Object catch (error) {
      return FailureResult<PubgetUser>(mapFirebaseFailure(error));
    }
  }

  @override
  Future<Result<PubgetUser>> updateProfile(
    String userId,
    ProfileUpdate update,
  ) async {
    try {
      await _functions.httpsCallable('updateSocialProfile').call<void>(
        <String, dynamic>{...update.toMap()},
      );
      return getOwnProfile(userId);
    } on Object catch (error) {
      return FailureResult<PubgetUser>(
        mapFirebaseFailure(error, message: 'Could not update your profile.'),
      );
    }
  }

  @override
  Future<Result<String>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      if (userId.trim().isEmpty || bytes.isEmpty) {
        return const FailureResult<String>(
          ValidationError('Choose a valid profile photo.'),
        );
      }
      final ref = _storage.ref('users/$userId/avatar.jpg');
      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      return Success<String>(await snapshot.ref.getDownloadURL());
    } on Object catch (error) {
      return FailureResult<String>(
        mapFirebaseFailure(error, message: 'Could not upload your profile photo.'),
      );
    }
  }

  @override
  Future<Result<String>> uploadCover({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (userId.trim().isEmpty || bytes.isEmpty) {
      return const FailureResult<String>(
        ValidationError('Choose a valid cover photo.'),
      );
    }
    final ref = _storage.ref('users/$userId/cover.jpg');
    try {
      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final url = await snapshot.ref.getDownloadURL();
      try {
        await _functions.httpsCallable('updateSocialProfile').call<void>(
          <String, dynamic>{'coverUrl': url},
        );
      } on Object {
        // Avoid orphaning a newly uploaded cover when profile persistence fails.
        try {
          await snapshot.ref.delete();
        } on Object {
          // Best effort; surface the original profile-write failure below.
        }
        rethrow;
      }
      return Success<String>(url);
    } on Object catch (error) {
      return FailureResult<String>(
        mapFirebaseFailure(error, message: 'Could not upload your cover photo.'),
      );
    }
  }
}
