// lib/providers/user_provider.dart
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/firebase/firestore_service.dart';
import '../core/constants/firestore_paths.dart';

class UserProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  UserProvider({
    required FirestoreService firestoreService,
  }) : _firestoreService = firestoreService;

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  // =========================================================
  // SYNC USER (🔥 التعديل الجديد للمزامنة السريعة مع Auth)
  // =========================================================
  
  /// تستخدم لتحديث البيانات مباشرة في الـ Provider دون إعادة الطلب من قاعدة البيانات 
  /// إذا كانت البيانات متوفرة مسبقاً في الـ AuthProvider
  void syncUser(UserModel? user) {
    if (user != null) {
      _currentUser = user;
      notifyListeners();
    }
  }

  // =========================================================
  // LOAD USER
  // =========================================================

  Future<void> loadUser(String userId) async {
    try {
      // ✅ حماية من تعليق التطبيق مع timeout
      final data = await _firestoreService
          .getDocument(
            path: FirestorePaths.users,
            docId: userId,
          )
          .timeout(const Duration(seconds: 5));

      if (data == null) {
        _currentUser = null;
      } else {
        _currentUser = UserModel.fromMap(data, userId);
      }

      notifyListeners();
    } catch (e) {
      debugPrint("⚠️ loadUser error: $e");
      _currentUser = null; // fallback لضمان عدم تعليق الشاشة
      notifyListeners();
    }
  }

  // =========================================================
  // CREATE USER
  // =========================================================

  Future<void> createUser(UserModel user) async {
    await _firestoreService.createDocument(
      path: FirestorePaths.users,
      docId: user.id,
      data: user.toMap(),
    );

    _currentUser = user;
    notifyListeners();
  }

  // =========================================================
  // UPDATE USER
  // =========================================================

  Future<void> updateUser(UserModel user) async {
    await _firestoreService.updateDocument(
      path: FirestorePaths.users,
      docId: user.id,
      data: user.toMap(),
    );

    _currentUser = user;
    notifyListeners();
  }

  // =========================================================
  // UPDATE PROFILE
  // =========================================================

  Future<void> updateProfile({
    String? username,
    String? nickname,
    String? avatarUrl,
    String? bio,
    List<String>? favoriteAnimes,
    int? age,
    String? country,
  }) async {
    if (_currentUser == null) return;

    final updatedUser = _currentUser!.copyWith(
      username: username,
      nickname: nickname,
      avatarUrl: avatarUrl,
      bio: bio,
      favoriteAnimes: favoriteAnimes,
      age: age,
      country: country,
      updatedAt: DateTime.now(),
    );

    await updateUser(updatedUser);
  }

  // =========================================================
  // STREAM USER
  // =========================================================

  Stream<UserModel> streamUser(String userId) {
    return _firestoreService
        .streamDocument(
          path: FirestorePaths.users,
          docId: userId,
        )
        .map((snapshot) {
      final data = snapshot.data();
      return UserModel.fromMap(
        data!,
        snapshot.id,
      );
    });
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  void clearUser() {
    _currentUser = null;
    notifyListeners();
  }

  // ✅ دالة جديدة لجلب بيانات أي مستخدم بالـ ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final data = await _firestoreService.getDocument(
        path: FirestorePaths.users,
        docId: userId,
      );
      if (data == null) return null;
      return UserModel.fromMap(data, userId);
    } catch (e) {
      debugPrint("Error fetching user: $e");
      return null;
    }
  }
}