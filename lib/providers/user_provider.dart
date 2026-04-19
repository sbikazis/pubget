// lib/providers/user_provider.dart
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/firebase/firestore_service.dart';
import '../core/constants/firestore_paths.dart';
import '../core/constants/subscription_type.dart'; // ✅ إضافة المستورد
import '../core/constants/limits.dart'; // ✅ إضافة المستورد للقيود

class UserProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  UserProvider({
    required FirestoreService firestoreService,
  }) : _firestoreService = firestoreService;

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  // =========================================================
  // SYNC USER (🔥 التعديل الجديد لمنع الـ Rebuild اللانهائي)
  // =========================================================
 
  void syncUser(UserModel? user) {
    if (user != null) {
      // ✅ تصحيح: لا نحدث الحالة إلا إذا كان المستخدم المسجل مختلفاً عن الحالي
      // هذا يمنع HomeScreen من الدخول في حلقة إعادة بناء لانهائية
      if (_currentUser?.id != user.id || _currentUser?.updatedAt != user.updatedAt) {
        _currentUser = user;
        notifyListeners();
      }
    }
  }

  // =========================================================
  // LOAD USER
  // =========================================================

  Future<void> loadUser(String userId) async {
    try {
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
      _currentUser = null;
      notifyListeners();
    }
  }

  // =========================================================
  // PREMIUM SUBSCRIPTION LOGIC (🔥 التعديل الجديد)
  // =========================================================

  /// تفعيل اشتراك البريميوم وتحديث قاعدة البيانات والمحلي فوراً
  Future<void> activatePremiumSubscription() async {
    if (_currentUser == null) return;

    final updatedUser = _currentUser!.copyWith(
      subscriptionType: SubscriptionType.premium,
      premiumSince: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await updateUser(updatedUser);
    // بمجرد استدعاء updateUser يتم تحديث _currentUser محلياً وإخطار الواجهات
  }

  // =========================================================
  // LIMITS CHECKERS (🔥 دوال فحص القيود الذكية)
  // =========================================================

  bool get canCreateMoreGroups {
    if (_currentUser == null) return false;
    // هنا نفترض وجود حقل أو طريقة لجلب عدد مجموعات المستخدم، سأضع المنطق العام:
    // int currentCount = ...;
    // int maxAllowed = _currentUser!.isPremium ? Limits.maxGroupsPremium : Limits.maxGroupsFree;
    // return currentCount < maxAllowed;
    return true; // سيتم ربطها لاحقاً بعدد المجموعات الفعلي
  }

  int get maxAllowedMembers {
    if (_currentUser == null) return Limits.maxMembersFree;
    return _currentUser!.isPremium ? Limits.maxMembersPremium : Limits.maxMembersFree;
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
    String? nameColor, // ✅ إضافة دعم لون الاسم الجديد
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
      nameColor: nameColor, // ✅ تحديث اللون
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

  // ✅ جلب بيانات أي مستخدم بالـ ID
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