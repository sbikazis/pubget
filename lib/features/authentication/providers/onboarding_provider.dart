import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/auth_user.dart';
import '../../social/models/profile_section_privacy.dart';
import '../models/pubget_user.dart';
import '../models/username_status.dart';
import '../repositories/user_repository.dart';

final class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider({required UserRepository repository})
    : _repository = repository;

  final UserRepository _repository;
  PubgetUser? _profile;
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  String? _boundUserId;
  bool _disposed = false;

  PubgetUser? get profile => _profile;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get isProfileCompleted => _profile?.isProfileCompleted == true;
  bool get canEnterHome => _profile?.isProfileCompleted == true;

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
    int? age,
    bool clearAge = false,
    String? gender,
    bool clearGender = false,
    String? country,
    List<String> favoriteAnimes = const <String>[],
    List<String> favoriteAnimeIds = const <String>[],
    required bool isProfileCompleted,
  }) async {
    _failure = null;
    _setState(LoadingState.loading);
    final cleanUsername = _clean(username) ?? _profile?.username;
    final cleanDisplayName =
        _clean(displayName) ?? _clean(authUser.displayName) ?? _profile?.displayName;
    final cleanAvatarUrl =
        _clean(avatarUrl) ?? _profile?.avatarUrl ?? _clean(authUser.avatarUrl);
    if (isProfileCompleted &&
        (cleanUsername == null ||
            cleanDisplayName == null ||
            cleanAvatarUrl == null)) {
      const failure = ValidationError(
        'A username, display name, and profile photo are required.',
      );
      _setFailure(failure);
      return const FailureResult<PubgetUser>(failure);
    }
    final profile = PubgetUser(
      id: authUser.id,
      email: authUser.email,
      username: cleanUsername,
      displayName: cleanDisplayName,
      avatarUrl: cleanAvatarUrl,
      coverUrl: _profile?.coverUrl,
      bio: bio == null ? _profile?.bio : _clean(bio),
      age: clearAge ? null : (age ?? _profile?.age),
      gender: clearGender ? null : (gender == null ? _profile?.gender : _clean(gender)),
      country: country == null ? _profile?.country : _clean(country),
      favoriteQuote: _profile?.favoriteQuote,
      animeTwin: _profile?.animeTwin,
      socialLinks: _profile?.socialLinks ?? const [],
      favoriteAnimes: List<String>.unmodifiable(favoriteAnimes),
      favoriteAnimeIds: List<String>.unmodifiable(favoriteAnimeIds),
      profileVisibility: _profile?.profileVisibility ?? 'public',
      activityVisibility: _profile?.activityVisibility ?? 'public',
      whoCanMessageMe: _profile?.whoCanMessageMe ?? 'related',
      sectionPrivacy: _profile?.sectionPrivacy ?? ProfileSectionPrivacy.public,
      totalRespect: _profile?.totalRespect ?? 0,
      fansCount: _profile?.fansCount ?? 0,
      language: _profile?.language,
      createdAt: _profile?.createdAt ?? DateTime.now(),
      isProfileCompleted: isProfileCompleted,
      hasSkippedOnboarding: false,
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
    int? age,
    String? gender,
    String? country,
    List<String> favoriteAnimes = const <String>[],
    List<String> favoriteAnimeIds = const <String>[],
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
        age: age,
        clearAge: clearAge,
        gender: gender,
        clearGender: clearGender,
        country: country,
        favoriteAnimes: favoriteAnimes,
        favoriteAnimeIds: favoriteAnimeIds,
        isProfileCompleted: isProfileCompleted,
      ),
      onFailure: (failure) {
        _setFailure(failure);
        return FailureResult<PubgetUser>(failure);
      },
    );
  }

  void applyFavoriteAnimeIds(List<String> ids) {
    if (_profile == null) return;
    _profile = _profile!.copyWith(
      favoriteAnimeIds: List<String>.unmodifiable(ids),
    );
    if (!_disposed) notifyListeners();
  }

  void clearFailure() {
    if (_failure == null) return;
    _failure = null;
    notifyListeners();
  }

  /// Instant server-side availability check (spec §3.2). Read-only, so it does
  /// not flip the onboarding loading state.
  Future<Result<UsernameStatus>> checkUsernameAvailable(String username) =>
      _repository.checkUsernameAvailable(username);

  /// Server-side claim before the direct profile write. Idempotent for the
  /// same owner. Failure means the username was taken between check and save.
  Future<Result<String>> reserveUsername(String username) =>
      _repository.reserveUsername(username);

  /// Mirrors the chosen language to the server (spec §1.4).
  Future<Result<void>> updateLanguage(String language) =>
      _repository.updateLanguage(language);

  void clearSession() {
    _profile = null;
    _failure = null;
    _state = LoadingState.initial;
    if (!_disposed) notifyListeners();
  }

  void bindUser(String? userId) {
    if (_boundUserId == userId) return;
    final previous = _boundUserId;
    _boundUserId = userId;
    if (userId == null || (previous != null && previous != userId)) {
      clearSession();
    }
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
