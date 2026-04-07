// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firebase/auth_service.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart'; // 🔥 مضاف لربط الحالة

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final UserProvider _userProvider; // 🔥 إضافة مرجع للـ UserProvider

  // 🔥 التعديل: استقبال UserProvider وتشغيل المستمع فور الإنشاء
  AuthProvider(this._authService, this._userProvider) {
    listenToAuthState();
  }

  UserModel? _user;
  // 🔥 التعديل: جعل الحالة الابتدائية true لمنع القفز لصفحة تسجيل الدخول قبل الفحص
  bool _isLoading = true; 
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  // =========================================================
  // LOGIN 
  // =========================================================

  Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      final user = await _authService.login(email: email, password: password);
      _user = user;
      
      // 🔥 مزامنة البيانات فور تسجيل الدخول الناجح
      if (user != null) {
        await _userProvider.loadUser(user.id);
      }
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // GOOGLE LOGIN
  // =========================================================

  Future<void> signInWithGoogle() async {
    try {
      _setLoading(true);
      _error = null;

      final user = await _authService.signInWithGoogle();
      _user = user;

      // 🔥 مزامنة البيانات فور تسجيل الدخول الناجح عبر جوجل
      if (user != null) {
        await _userProvider.loadUser(user.id);
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> logout() async {
    try {
      _setLoading(true);
      _error = null;

      await _authService.logout();
      _user = null;
      
      // 🔥 تنظيف بيانات المستخدم من الـ UserProvider عند الخروج
      _userProvider.clearUser();

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // AUTH STATE LISTENER (🔥 التعديل: إضافة المزامنة التلقائية مع UserProvider)
  // =========================================================

  void listenToAuthState() {
    FirebaseAuth.instance.authStateChanges().listen((firebaseUser) async {
      _setLoading(true); // ابدأ الفحص عند تغير حالة Firebase
      
      if (firebaseUser == null) {
        _user = null;
        _userProvider.clearUser(); // تنظيف البيانات في حال عدم وجود جلسة
      } else {
        final user = await _authService.getCurrentUser();
        _user = user;
        
        // 🔥 النقطة الجوهرية: تحميل بيانات المستخدم في الـ UserProvider تلقائياً
        if (user != null) {
          await _userProvider.loadUser(user.id);
        }
      }
      
      _setLoading(false); // انتهى الفحص والمزامنة
    });
  }

  // =========================================================
  // CHECK AUTH STATE
  // =========================================================

  Future<void> checkAuthState() async {
    try {
      _setLoading(true);
      _error = null;

      final user = await _authService.getCurrentUser();
      _user = user;

      if (user != null) {
        await _userProvider.loadUser(user.id);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // HELPER METHODS
  // =========================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}