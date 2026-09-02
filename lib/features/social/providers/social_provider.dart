import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/social_models.dart';
import '../repositories/social_repository.dart';

final class SocialProvider extends ChangeNotifier {
  SocialProvider({required SocialRepository repository})
    : _repository = repository;

  final SocialRepository _repository;
  SocialSnapshot _snapshot = const SocialSnapshot();
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  String? _userId;
  bool _disposed = false;

  SocialSnapshot get snapshot => _snapshot;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  List<Friendship> get friends => _snapshot.friends;
  Set<String> get blockedUserIds {
    final uid = _userId;
    if (uid == null) return const <String>{};
    return <String>{
      for (final friendship in _snapshot.friendships)
        if (friendship.status == FriendshipStatus.blocked)
          friendship.otherUserId(uid),
    };
  }
  List<Friendship> get incomingRequests =>
      _userId == null ? const <Friendship>[] : _snapshot.pendingFor(_userId!);
  List<Friendship> get outgoingRequests =>
      _userId == null ? const <Friendship>[] : _snapshot.outgoingFor(_userId!);
  List<RespectRelation> get fans =>
      _snapshot.receivedRespect.where((item) => item.value >= 5).toList();

  bool canStartPrivateChatWith(String otherUserId) {
    final userId = _userId;
    if (userId == null) return false;
    return _snapshot.canStartPrivateChat(userId, otherUserId);
  }

  Future<Result<SocialSnapshot>> load(String userId) async {
    _userId = userId;
    _failure = null;
    _setState(LoadingState.loading);
    final result = await _repository.getSnapshot(userId);
    result.fold(
      onSuccess: (snapshot) {
        _snapshot = snapshot;
        _setState(
          snapshot.friendships.isEmpty &&
                  snapshot.givenRespect.isEmpty &&
                  snapshot.receivedRespect.isEmpty
              ? LoadingState.empty
              : LoadingState.loaded,
        );
      },
      onFailure: _setFailure,
    );
    return result;
  }

  Future<Result<void>> giveRespect({
    required String toUserId,
    required int value,
  }) async {
    final userId = _userId;
    if (userId == null) return _validation('Sign in to give Respect.');
    if (userId == toUserId) {
      return _validation('You cannot give Respect to yourself.');
    }
    if (value < 0 || value > 7) {
      return _validation('Respect must be between 0 and 7.');
    }
    return _runAction(
      () => _repository.giveRespect(toUserId: toUserId, value: value),
    );
  }

  Future<Result<void>> sendFriendRequest({required String toUserId}) async {
    final userId = _userId;
    if (userId == null) return _validation('Sign in to add a friend.');
    if (userId == toUserId) {
      return _validation('You cannot add yourself as a friend.');
    }
    return _runAction(() => _repository.sendFriendRequest(toUserId: toUserId));
  }

  Future<Result<void>> respondToFriendRequest({
    required String otherUserId,
    required bool accept,
  }) => _runAction(
    () => _repository.respondToFriendRequest(
      otherUserId: otherUserId,
      response: accept ? 'accept' : 'reject',
    ),
  );

  Future<Result<void>> removeFriend(String otherUserId) =>
      _runAction(() => _repository.removeFriend(otherUserId: otherUserId));

  Future<Result<void>> blockUser(String otherUserId) =>
      _runAction(() => _repository.blockUser(otherUserId: otherUserId));

  Future<Result<void>> unblockUser(String otherUserId) =>
      _runAction(() => _repository.unblockUser(otherUserId: otherUserId));

  Future<Result<void>> _runAction(
    Future<Result<void>> Function() action,
  ) async {
    _failure = null;
    _setState(LoadingState.loading);
    final result = await action();
    if (result.isSuccess && _userId != null) {
      await load(_userId!);
    } else {
      result.fold<void>(onSuccess: (_) {}, onFailure: _setFailure);
    }
    return result;
  }

  FailureResult<void> _validation(String message) {
    final failure = ValidationError(message);
    _setFailure(failure);
    return FailureResult<void>(failure);
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

  void resetSession() {
    _userId = null;
    _snapshot = const SocialSnapshot();
    _failure = null;
    _state = LoadingState.initial;
    if (!_disposed) notifyListeners();
  }

  void bindUser(String? userId) {
    if (_userId == userId) return;
    if (userId == null || (_userId != null && _userId != userId)) {
      resetSession();
    }
    _userId = userId;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
