import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firebase/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider(this._authService);

  // =========================================================
  // STATE
  // =========================================================

  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  // =========================================================
  // GETTERS
  // =========================================================

  UserModel? get user => _user;

  bool get isLoading => _isLoading;

  String? get error => _error;

  bool get isLoggedIn => _user != null;


  // =========================================================
  // REGISTER
  // =========================================================

  Future<void> register({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _error = null;

      final user = await _authService.register(
        email: email,
        password: password,
      );

      _user = user;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // LOGIN
  // =========================================================

  Future<void> login({required String email, required String password}) async {
    try {
      _setLoading(true);
      _error = null;

      final user = await _authService.login(email: email, password: password);

      _user = user;
    } catch (e) {
      _error = e.toString();
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
    } catch (e) {
      _error = e.toString();
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

      await _authService.logout();

      _user = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // =========================================================
  // AUTH STATE LISTENER
  // =========================================================

  void listenToAuthState() {
    FirebaseAuth.instance.authStateChanges().listen((firebaseUser) {
      if (firebaseUser == null) {
        _user = null;
      }

      notifyListeners();
    });
  }

  // =========================================================
  // INTERNAL
  // =========================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
