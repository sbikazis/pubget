import 'dart:io';

import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../models/respect_model.dart';
import '../models/fan_model.dart';

import '../services/firebase/firestore_service.dart';
import '../services/firebase/storage_service.dart';

import '../core/constants/firestore_paths.dart';
import '../core/logic/respect_logic.dart';

class ProfileProvider extends ChangeNotifier {
  final FirestoreService _firestore;
  final StorageService _storage;
  final RespectLogic _respectLogic;

  ProfileProvider(
    this._firestore,
    this._storage,
  ) : _respectLogic = RespectLogic(_firestore);

  // =========================================================
  // LOADING STATE
  // =========================================================

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  // داخل class ProfileProvider
/// Marks the user's profile as completed
  Future<void> markProfileCompleted({
    required String userId,
  }) async {
    await _firestore.updateDocument(
      path: FirestorePaths.users,
      docId: userId,
      data: {
        'isProfileCompleted': true,
        'updatedAt': DateTime.now(),
      },
    );
  }

  // =========================================================
  // STREAM USER PROFILE
  // =========================================================

  Stream<UserModel> streamUserProfile(String userId) {
    return _firestore
        .streamDocument(
          path: FirestorePaths.users,
          docId: userId,
        )
        .map((snapshot) {
      final data = snapshot.data();

      if (data == null) {
        throw Exception('User not found');
      }

      return UserModel.fromMap(
        data,
        snapshot.id,
      );
    });
  }

  // =========================================================
  // GET USER PROFILE ONCE
  // =========================================================

  Future<UserModel?> getUserProfile(String userId) async {
    final data = await _firestore.getDocument(
      path: FirestorePaths.users,
      docId: userId,
    );

    if (data == null) return null;

    return UserModel.fromMap(data, userId);
  }

  // =========================================================
  // UPDATE BASIC PROFILE
  // =========================================================

  Future<void> updateProfile({
    required String userId,
    String? username,
    String? nickname,
    String? bio,
    List<String>? favoriteAnimes,
    int? age,
    String? country,
  }) async {
    final updateData = <String, dynamic>{};

    if (username != null) {
      updateData['username'] = username;
    }

    if (nickname != null) {
      updateData['nickname'] = nickname;
    }

    if (bio != null) {
      updateData['bio'] = bio;
    }

    if (favoriteAnimes != null) {
      updateData['favoriteAnimes'] = favoriteAnimes;
    }

    if (age != null) {
      updateData['age'] = age;
    }

    if (country != null) {
      updateData['country'] = country;
    }

    updateData['updatedAt'] = DateTime.now();

    await _firestore.updateDocument(
      path: FirestorePaths.users,
      docId: userId,
      data: updateData,
    );
  }

  // =========================================================
  // UPDATE AVATAR
  // =========================================================

  Future<void> updateAvatar({
    required String userId,
    required File imageFile,
  }) async {
    _setLoading(true);

    try {
      final avatarUrl = await _storage.uploadUserAvatar(
        userId: userId,
        file: imageFile,
      );

      await _firestore.updateDocument(
        path: FirestorePaths.users,
        docId: userId,
        data: {
          'avatarUrl': avatarUrl,
          'updatedAt': DateTime.now(),
        },
      );
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // UPDATE BIO
  // =========================================================

  Future<void> updateBio({
    required String userId,
    required String bio,
  }) async {
    await _firestore.updateDocument(
      path: FirestorePaths.users,
      docId: userId,
      data: {
        'bio': bio,
        'updatedAt': DateTime.now(),
      },
    );
  }

  // =========================================================
  // UPDATE FAVORITE ANIME LIST
  // =========================================================

  Future<void> updateFavoriteAnimes({
    required String userId,
    required List<String> animes,
  }) async {
    await _firestore.updateDocument(
      path: FirestorePaths.users,
      docId: userId,
      data: {
        'favoriteAnimes': animes,
        'updatedAt': DateTime.now(),
      },
    );
  }

  // =========================================================
  // GIVE RESPECT
  // =========================================================

  Future<bool> giveRespect({
    required String fromUserId,
    required String toUserId,
    required int value,
  }) async {
    return _respectLogic.rateUser(
      fromUserId: fromUserId,
      toUserId: toUserId,
      respectValue: value,
    );
  }

  // =========================================================
  // STREAM USER RESPECTS
  // =========================================================

  Stream<List<RespectModel>> streamUserRespects(
    String userId,
  ) {
    final query = _firestore.buildQuery(
      path: FirestorePaths.respects,
      conditions: [
        QueryCondition(
          field: 'toUserId',
          isEqualTo: userId,
        ),
      ],
    );

    return _firestore
        .streamCollection(
          path: FirestorePaths.respects,
          query: query,
        )
        .map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => RespectModel.fromMap(
              doc.data(),
              doc.id,
            ),
          )
          .toList();
    });
  }

  // =========================================================
  // STREAM USER FANS
  // =========================================================

  Stream<List<FanModel>> streamUserFans(
    String userId,
  ) {
    final query = _firestore.buildQuery(
      path: FirestorePaths.fans,
      conditions: [
        QueryCondition(
          field: 'targetUserId',
          isEqualTo: userId,
        ),
      ],
    );

    return _firestore
        .streamCollection(
          path: FirestorePaths.fans,
          query: query,
        )
        .map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => FanModel.fromMap(
              doc.data(),
              doc.id,
            ),
          )
          .toList();
    });
  }

  // =========================================================
  // STREAM USERS I AM FAN OF
  // =========================================================

  Stream<List<FanModel>> streamUsersIFollow(
    String userId,
  ) {
    final query = _firestore.buildQuery(
      path: FirestorePaths.fans,
      conditions: [
        QueryCondition(
          field: 'fanUserId',
          isEqualTo: userId,
        ),
      ],
    );

    return _firestore
        .streamCollection(
          path: FirestorePaths.fans,
          query: query,
        )
        .map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => FanModel.fromMap(
              doc.data(),
              doc.id,
            ),
          )
          .toList();
    });
  }
}