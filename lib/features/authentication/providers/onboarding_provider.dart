import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/auth_user.dart';
import '../models/pubget_user.dart';
import '../repositories/user_repository.dart';

final class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider({required UserRepository repository})
    : _repository = repository;

  final UserRepository _repository;
  PubgetUser? _profile;
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _disposed = false;

  PubgetUser? get profile => _profile;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get isProfileCompleted => _profile?.isProfileCompleted == true;
  bool get canEnterHome =>
      _profile?.isProfileCompleted == true ||
      _profile?.hasSkippedOnboarding == true;

  Future<Result<PubgetUser?>> loadProfile(String userId) async {
    _failure = null;
    _setState(LoadingState.loading);
    final result = await _repository.getUserProfile(userId);
    result.fold(
      onSuccess: (profile) {
        _profile = profile;
        _setState(LoadingState.loaded);
      },
      onFailure: _setFailure,
    );
    return result;
  }

  Future<Result<PubgetUser>> saveProfile({
    required AuthUser authUser,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    List<String> favoriteAnimes = const <String>[],
    required bool isProfileCompleted,
  }) async {
    _failure = null;
    _setState(LoadingState.loading);
    final profile = PubgetUser(
      id: authUser.id,
      email: authUser.email,
      username: _clean(username),
      displayName: _clean(displayName) ?? authUser.displayName,
      avatarUrl: _clean(avatarUrl) ?? authUser.avatarUrl,
      bio: _clean(bio),
      favoriteAnimes: List<String>.unmodifiable(favoriteAnimes),
      createdAt: _profile?.createdAt ?? DateTime.now(),
      isProfileCompleted: isProfileCompleted,
      hasSkippedOnboarding: !isProfileCompleted,
    );
    final result = _profile == null
        ? await _repository.createUserProfile(profile)
        : await _repository.updateUserProfile(profile);
    result.fold(
      onSuccess: (saved) {
        _profile = saved;
        _setState(LoadingState.loaded);
      },
      onFailure: _setFailure,
    );
    return result;
  }

  Future<Result<PubgetUser>> saveProfileWithAvatar({
    required AuthUser authUser,
    required Uint8List avatarBytes,
    required String contentType,
    String? username,
    String? displayName,
    String? bio,
    List<String> favoriteAnimes = const <String>[],
    required bool isProfileCompleted,
  }) async {
    _failure = null;
    _setState(LoadingState.loading);
    final avatarResult = await _repository.uploadAvatar(
      userId: authUser.id,
      bytes: avatarBytes,
      contentType: contentType,
    );
    return avatarResult.fold(
      onSuccess: (avatarUrl) => saveProfile(
        authUser: authUser,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        bio: bio,
        favoriteAnimes: favoriteAnimes,
        isProfileCompleted: isProfileCompleted,
      ),
      onFailure: (failure) {
        _setFailure(failure);
        return FailureResult<PubgetUser>(failure);
      },
    );
  }

  Future<Result<PubgetUser>> skip(
    AuthUser authUser, {
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    List<String> favoriteAnimes = const <String>[],
  }) async {
    final result = await saveProfile(
      authUser: authUser,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      bio: bio,
      favoriteAnimes: favoriteAnimes,
      isProfileCompleted: false,
    );
    if (result is FailureResult<PubgetUser> && result.failure is NetworkError) {
      final local = PubgetUser(
        id: authUser.id,
        email: authUser.email,
        username: _clean(username) ?? _profile?.username,
        displayName:
            _clean(displayName) ??
            _profile?.displayName ??
            authUser.displayName,
        avatarUrl:
            _clean(avatarUrl) ?? _profile?.avatarUrl ?? authUser.avatarUrl,
        bio: _clean(bio) ?? _profile?.bio,
        favoriteAnimes: List<String>.unmodifiable(
          favoriteAnimes.isEmpty
              ? _profile?.favoriteAnimes ?? const <String>[]
              : favoriteAnimes,
        ),
        createdAt: _profile?.createdAt ?? DateTime.now(),
        isProfileCompleted: false,
        hasSkippedOnboarding: true,
      );
      _profile = local;
      _failure = null;
      _setState(LoadingState.loaded);
      return Success<PubgetUser>(local);
    }
    return result;
  }

  void clearFailure() {
    if (_failure == null) return;
    _failure = null;
    notifyListeners();
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

  static String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
