import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../../authentication/models/pubget_user.dart';
import '../models/public_profile.dart';
import '../repositories/profile_repository.dart';

final class ProfileProvider extends ChangeNotifier {
  ProfileProvider({required ProfileRepository repository})
    : _repository = repository;

  final ProfileRepository _repository;
  PubgetUser? _ownProfile;
  PublicProfile? _publicProfile;
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _isOwner = false;
  String? _boundUserId;
  bool _disposed = false;

  PubgetUser? get ownProfile => _ownProfile;
  PublicProfile? get publicProfile => _publicProfile;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get isOwner => _isOwner;

  Future<void> load({
    required String viewerId,
    required String profileId,
  }) async {
    _failure = null;
    _isOwner = viewerId == profileId;
    _setState(LoadingState.loading);
    final result = _isOwner
        ? await _repository.getOwnProfile(profileId)
        : await _repository.getPublicProfile(profileId);
    result.fold(
      onSuccess: (profile) {
        if (_isOwner) {
          _ownProfile = profile as PubgetUser;
        } else {
          _publicProfile = profile as PublicProfile;
        }
        _setState(LoadingState.loaded);
      },
      onFailure: _setFailure,
    );
  }

  Future<Result<PubgetUser>> update(String userId, ProfileUpdate update) async {
    _failure = null;
    _setState(LoadingState.loading);
    final result = await _repository.updateProfile(userId, update);
    result.fold(
      onSuccess: (profile) {
        _ownProfile = profile;
        _setState(LoadingState.loaded);
      },
      onFailure: _setFailure,
    );
    return result;
  }

  Future<Result<String>> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    _failure = null;
    _setState(LoadingState.loading);
    final result = await _repository.uploadAvatar(
      userId: userId,
      bytes: bytes,
      contentType: contentType,
    );
    result.fold(
      onSuccess: (_) => _setState(LoadingState.loaded),
      onFailure: _setFailure,
    );
    return result;
  }

  void clearFailure() {
    if (_failure == null) return;
    _failure = null;
    notifyListeners();
  }

  void resetSession() {
    _ownProfile = null;
    _publicProfile = null;
    _failure = null;
    _isOwner = false;
    _state = LoadingState.initial;
    if (!_disposed) notifyListeners();
  }

  void bindUser(String? userId) {
    if (_boundUserId == userId) return;
    _boundUserId = userId;
    resetSession();
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
