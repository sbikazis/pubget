// lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase/auth_service.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final UserProvider _userProvider;

  AuthProvider(this._authService, this._userProvider) {
    listenToAuthState();
  }

  UserModel? _user;
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
  // REGISTER (تم تحديثها لتمرير معرف الداعي)
  // =========================================================
  Future<void> register({
    required String email,
    required String password,
    String? referrerId,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      final user = await _authService.register(
        email: email, 
        password: password,
        referrerId: referrerId,
      );
      _user = user;

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
  // GOOGLE LOGIN (تم تحديثها لتمرير معرف الداعي)
  // =========================================================
  Future<void> signInWithGoogle({String? referrerId}) async {
    try {
      _setLoading(true);
      _error = null;

      final user = await _authService.signInWithGoogle(referrerId: referrerId);
      _user = user;

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
  // AUTH STATE LISTENER
  // =========================================================
  void listenToAuthState() {
    FirebaseAuth.instance.authStateChanges().listen((firebaseUser) async {
      _setLoading(true);

      if (firebaseUser == null) {
        _user = null;
        _userProvider.clearUser();
      } else {
        final user = await _authService.getCurrentUser();
        _user = user;

        if (user != null) {
          await _userProvider.loadUser(user.id);
        }
      }

      _setLoading(false);
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
