import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import '../../../core/media/media_repository_factory.dart';
import '../../../core/media/media_url_uploader.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/firebase_failure_mapper.dart';
import '../../../core/errors/result.dart';
import '../../authentication/models/pubget_user.dart';
import '../models/public_profile.dart';
import 'profile_repository.dart';

/// Firebase-backed profile data adapter.
///
/// Profile fields remain in Firestore. Avatar and cover bytes are stored
/// in Cloudflare R2 through the shared media repository; the public profile
/// projection stores stable object keys, never expiring signed URLs.
final class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    MediaUrlUploader? mediaUploader,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _mediaUploader = mediaUploader ?? RepositoryMediaUrlUploader(
         repository: createMediaRepository(),
       );

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final MediaUrlUploader _mediaUploader;

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
    if (userId.trim().isEmpty || bytes.isEmpty) {
      return const FailureResult<String>(
        ValidationError('Choose a valid profile photo.'),
      );
    }
    return _mediaUploader.uploadImage(
      ownerUid: userId,
      bytes: bytes,
      claimedContentType: contentType,
      fileName: 'avatar.jpg',
    );
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
    final uploaded = await _mediaUploader.uploadImage(
      ownerUid: userId,
      bytes: bytes,
      claimedContentType: contentType,
      fileName: 'cover.jpg',
    );
    final key = uploaded.valueOrNull;
    if (key == null) return uploaded;
    try {
      await _functions.httpsCallable('updateSocialProfile').call<void>(
        <String, dynamic>{'coverUrl': key},
      );
      return Success<String>(key);
    } on Object catch (error) {
      return FailureResult<String>(
        mapFirebaseFailure(error, message: 'Could not save your cover photo.'),
      );
    }
  }
}
