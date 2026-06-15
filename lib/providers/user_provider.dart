// lib/providers/user_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/firebase/firestore_service.dart';
import '../core/constants/firestore_paths.dart';
import '../core/constants/subscription_type.dart';
import '../core/constants/limits.dart';

class UserProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  UserProvider({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  void syncUser(UserModel? user) {
    if (user != null) {
      if (_currentUser?.id != user.id ||
          _currentUser?.updatedAt != user.updatedAt) {
        _currentUser = user;
        notifyListeners();
      }
    }
  }

  // =========================================================
  // MIGRATION — يضيف الحقول الجديدة للمستخدمين القدامى تلقائياً
  // =========================================================
  Future<void> _migrateUserFields(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final Map<String, dynamic> missing = {};

      // ← أضف هنا أي حقل جديد في أي تحديث مستقبلي
      if (!data.containsKey('coins'))       missing['coins'] = 0;
      if (!data.containsKey('isPremium'))   missing['isPremium'] = false;
      if (!data.containsKey('totalEdits'))  missing['totalEdits'] = 0;

      if (missing.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update(missing);
        debugPrint(
            "✅ Migration: أضيفت حقول ${missing.keys} للمستخدم $userId");
      }
    } catch (e) {
      debugPrint("⚠️ Migration error: $e");
    }
  }

  // =========================================================
  // LOAD USER
  // =========================================================
  Future<void> loadUser(String userId) async {
    try {
      final data = await _firestoreService
          .getDocument(path: FirestorePaths.users, docId: userId)
          .timeout(const Duration(seconds: 5));
      _currentUser = data == null ? null : UserModel.fromMap(data, userId);
      notifyListeners();

      // تشغيل Migration بعد التحميل بدون تأثير على السرعة
      await _migrateUserFields(userId);
    } catch (e) {
      debugPrint("⚠️ loadUser error: $e");
      _currentUser = null;
      notifyListeners();
    }
  }

  // =========================================================
  // RELOAD USER — تحديث الرصيد فوراً بعد المكافأة
  // =========================================================
  Future<void> reloadUser() async {
    if (_currentUser == null) return;
    try {
      final data = await _firestoreService.getDocument(
        path: FirestorePaths.users,
        docId: _currentUser!.id,
      );
      if (data != null) {
        _currentUser = UserModel.fromMap(data, _currentUser!.id);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('reloadUser error: $e');
    }
  }

  // =========================================================
  // PREMIUM
  // =========================================================
  Future<void> activatePremiumSubscription() async {
    if (_currentUser == null) return;
    final updatedUser = _currentUser!.copyWith(
      subscriptionType: SubscriptionType.premium,
      premiumSince: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await updateUser(updatedUser);
  }

  bool get canCreateMoreGroups {
    if (_currentUser == null) return false;
    return true;
  }

  int get maxAllowedMembers {
    if (_currentUser == null) return Limits.maxMembersFree;
    return _currentUser!.isPremium
        ? Limits.maxMembersPremium
        : Limits.maxMembersFree;
  }

  // =========================================================
  // CREATE / UPDATE
  // =========================================================
  Future<void> createUser(UserModel user) async {
    await _firestoreService.createDocument(
        path: FirestorePaths.users, docId: user.id, data: user.toMap());
    _currentUser = user;
    notifyListeners();
  }

  Future<void> updateUser(UserModel user) async {
    await _firestoreService.updateDocument(
        path: FirestorePaths.users, docId: user.id, data: user.toMap());
    _currentUser = user;
    notifyListeners();
  }

  Future<void> updateProfile({
    String? username,
    String? nickname,
    String? avatarUrl,
    String? bio,
    List<String>? favoriteAnimes,
    int? age,
    String? country,
    String? nameColor,
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
      nameColor: nameColor,
      updatedAt: DateTime.now(),
    );
    await updateUser(updatedUser);
  }

  // =========================================================
  // STREAM / GET
  // =========================================================
  Stream<UserModel> streamUser(String userId) {
    return _firestoreService
        .streamDocument(path: FirestorePaths.users, docId: userId)
        .map((snapshot) {
      final data = snapshot.data();
      return UserModel.fromMap(data!, snapshot.id);
    });
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      final data = await _firestoreService.getDocument(
          path: FirestorePaths.users, docId: userId);
      if (data == null) return null;
      return UserModel.fromMap(data, userId);
    } catch (e) {
      debugPrint("Error fetching user: $e");
      return null;
    }
  }

  // =========================================================
  // CLEAR
  // =========================================================
  void clearUser() {
    _currentUser = null;
    notifyListeners();
  }
}
