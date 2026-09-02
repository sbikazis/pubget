import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/auth_user.dart';
import '../repositories/auth_repository.dart';

final class AuthProvider extends ChangeNotifier {
  AuthProvider({required AuthRepository repository}) : _repository = repository;

  final AuthRepository _repository;
  StreamSubscription<AuthUser?>? _subscription;
  AuthUser? _currentUser;
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _initialized = false;
  bool _disposed = false;
  bool _resetting = false;

  AuthUser? get currentUser => _currentUser;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _initialized;
  bool get isBusy => _state == LoadingState.loading;
  bool get isResetting => _resetting;
  Stream<AuthUser?> get authStateChanges => _repository.authStateChanges;

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    _setState(LoadingState.loading);
    try {
      _subscription = _repository.authStateChanges.listen(
        _handleAuthState,
        onError: (Object error, StackTrace stackTrace) {
          _setFailure(const UnknownError('We could not check your session.'));
        },
      );
      _handleAuthState(_repository.currentUser);
    } catch (error) {
      _setFailure(_failureFrom(error));
    }
  }

  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) => _runAuthAction(
    () => _repository.signInWithEmail(email: email, password: password),
  );

  Future<Result<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
  }) => _runAuthAction(
    () => _repository.signUpWithEmail(email: email, password: password),
  );

  Future<Result<AuthUser>> signInWithGoogle() =>
      _runAuthAction(_repository.signInWithGoogle);

  Future<Result<void>> sendPasswordResetEmail({required String email}) async {
    _resetting = true;
    notifyListeners();
    final result = await _repository.sendPasswordResetEmail(email: email);
    _resetting = false;
    notifyListeners();
    return result;
  }

  Future<Result<void>> signOut() async {
    _setState(LoadingState.loading);
    final result = await _repository.signOut();
    result.fold(
      onSuccess: (_) {
        _currentUser = null;
        _setState(LoadingState.loaded);
      },
      onFailure: _setFailure,
    );
    return result;
  }

  void clearFailure() {
    if (_failure == null) return;
    _failure = null;
    notifyListeners();
  }

  Future<Result<AuthUser>> _runAuthAction(
    Future<Result<AuthUser>> Function() action,
  ) async {
    _failure = null;
    _setState(LoadingState.loading);
    final result = await action();
    result.fold(
      onSuccess: (user) {
        _currentUser = user;
        _setState(LoadingState.loaded);
      },
      onFailure: (failure) {
        if (failure is CancelledError) {
          _setState(LoadingState.loaded);
          return;
        }
        _setFailure(failure);
      },
    );
    return result;
  }

  void _handleAuthState(AuthUser? user) {
    if (_disposed) return;
    _currentUser = user;
    _failure = null;
    _setState(LoadingState.loaded);
  }

  void _setFailure(Failure failure) {
    if (_disposed) return;
    _failure = failure;
    _state = failure is NetworkError
        ? LoadingState.offline
        : LoadingState.error;
    notifyListeners();
  }

  void _setState(LoadingState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  static Failure _failureFrom(Object error) {
    return error is Failure
        ? error
        : const UnknownError('We could not check your session.');
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
