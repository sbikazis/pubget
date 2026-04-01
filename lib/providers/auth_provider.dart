import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../services/firebase/auth_service.dart';
import '../models/user_model.dart';
import 'user_provider.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider(this._authService);

  UserModel? _user;
  bool _isLoading = false;
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
    required BuildContext context,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      final user = await _authService.login(
        email: email,
        password: password,
      );

      _user = user;

      // 🔥 تحميل بيانات المستخدم مباشرة
      await context.read<UserProvider>().loadUser(user.id);

    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // GOOGLE LOGIN
  // =========================================================

  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      _setLoading(true);
      _error = null;

      final user = await _authService.signInWithGoogle();
      _user = user;

      // 🔥 نفس الفكرة هنا
      await context.read<UserProvider>().loadUser(user.id);

    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> logout(BuildContext context) async {
    try {
      _setLoading(true);

      await _authService.logout();

      _user = null;

      // 🔥 تنظيف بيانات المستخدم
      context.read<UserProvider>().clearUser();

    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // AUTH STATE LISTENER (🔥 الإصلاح الحقيقي)
  // =========================================================

  void listenToAuthState(BuildContext context) {
    FirebaseAuth.instance.authStateChanges().listen((firebaseUser) async {

      if (firebaseUser == null) {
        _user = null;

        // 🔥 تنظيف
        context.read<UserProvider>().clearUser();

      } else {
        final user = await _authService.getCurrentUser();
        _user = user;

        if (user != null) {
          await context.read<UserProvider>().loadUser(user.id);
        }
      }

      notifyListeners();
    });
  }

  // =========================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> checkAuthState() async {
    try {
      _setLoading(true);
      _error = null;

      final user = await _authService.getCurrentUser();
      _user = user;

    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }
}