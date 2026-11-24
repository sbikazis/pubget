import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import '../../../core/media/media_repository_factory.dart';
import '../../../core/media/media_url_uploader.dart';
import '../../../core/media/media_validation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/identity/identity_worker_client.dart';
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
    IdentityWorkerClient? identityClient,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _identityClient = identityClient ?? IdentityWorkerClient(),
       _mediaUploader = mediaUploader;

  final FirebaseFirestore _firestore;
  final IdentityWorkerClient _identityClient;
  MediaUrlUploader? _mediaUploader;

  MediaUrlUploader get _uploader => _mediaUploader ??=
      RepositoryMediaUrlUploader(repository: createMediaRepository());

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
      await _identityClient.post('/identity/profile/update', <String, dynamic>{
        ...update.toMap(),
      });
      return await getOwnProfile(userId);
    } on Object catch (error) {
      return FailureResult<PubgetUser>(
        mapIdentityWorkerFailure(error, 'Could not update your profile.'),
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
    final uploaded = await _uploader.uploadImage(
      ownerUid: userId,
      bytes: bytes,
      claimedContentType: contentType,
      fileName: imageFileNameForUpload(
        bytes: bytes,
        contentType: contentType,
        prefix: 'avatar',
      ),
    );
    final key = uploaded.valueOrNull;
    if (key == null) return uploaded;
    try {
      await _identityClient.post('/identity/profile/update', <String, dynamic>{
        'avatarUrl': key,
      });
      return Success<String>(key);
    } on Object catch (error) {
      return FailureResult<String>(
        mapIdentityWorkerFailure(error, 'Could not save your profile photo.'),
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
    final uploaded = await _uploader.uploadImage(
      ownerUid: userId,
      bytes: bytes,
      claimedContentType: contentType,
      fileName: imageFileNameForUpload(
        bytes: bytes,
        contentType: contentType,
        prefix: 'cover',
      ),
    );
    final key = uploaded.valueOrNull;
    if (key == null) return uploaded;
    try {
      await _identityClient.post('/identity/profile/update', <String, dynamic>{
        'coverUrl': key,
      });
      return Success<String>(key);
    } on Object catch (error) {
      return FailureResult<String>(
        mapIdentityWorkerFailure(error, 'Could not save your cover photo.'),
      );
    }
  }
}

/// Maps Worker status codes without claiming the device is offline.
///
/// Only a real transport failure (handled by [mapFirebaseFailure]) may become
/// [NetworkError]. Server pressure and 5xx responses mean the service is
/// unavailable, not that connectivity was lost.
Failure mapIdentityWorkerFailure(Object error, String message) {
  if (error is! IdentityWorkerException) {
    return mapFirebaseFailure(error, message: message);
  }
  return switch (error.statusCode) {
    400 || 412 => ValidationError(error.message),
    409 => const ValidationError('This username is already taken.'),
    401 || 403 => const PermissionError(
      'You do not have permission to update this profile.',
    ),
    404 => const NotFoundError('Profile not found.'),
    429 => const RateLimitedError(
      'Too many requests. Please wait a moment and try again.',
    ),
    >= 500 => UnavailableError(message),
    _ => UnknownError(message),
  };
}
