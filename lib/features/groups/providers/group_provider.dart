import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/group_models.dart';
import '../repositories/group_repository.dart';

enum LeaveState { idle, pending, confirmed, reverted }

final class GroupProvider extends ChangeNotifier {
  GroupProvider({required GroupRepository repository})
    : _repository = repository;

  final GroupRepository _repository;
  Group? _group;
  GroupMember? _membership;
  List<Group> _searchResults = const <Group>[];
  List<Group> _joinedGroups = const <Group>[];
  StreamSubscription<Result<List<Group>>>? _joinedSubscription;
  String? _joinedUserId;
  LoadingState _state = LoadingState.initial;
  LoadingState _joinedState = LoadingState.initial;
  Failure? _failure;
  Failure? _joinedFailure;
  LeaveState _leaveState = LeaveState.idle;
  Future<void>? _leaveOperation;
  bool _disposed = false;

  Group? get group => _group;
  GroupMember? get membership => _membership;
  List<Group> get searchResults => _searchResults;
  List<Group> get joinedGroups => _joinedGroups;
  LoadingState get state => _state;
  LoadingState get joinedState => _joinedState;
  Failure? get failure => _failure;
  Failure? get joinedFailure => _joinedFailure;
  LeaveState get leaveState => _leaveState;
  Future<void>? get leaveOperation => _leaveOperation;
  bool get isMember => _membership != null;
  bool get isFounder => _membership?.role == GroupRole.founder;
  bool get canManageEvents => memberCanManageEvents(_membership);
  bool get canManageSettings => memberCanManageSettings(_membership);
  bool get canManageMembers => memberCanManageMembers(_membership);
  int get unreadCount =>
      _joinedGroups.where((group) => group.hasUnread).length;

  Future<Result<Group>> create(GroupDraft draft) async {
    _start();
    final result = await _repository.createGroup(draft);
    result.fold(
      onSuccess: (group) {
        _group = group;
        _membership = GroupMember(
          uid: group.founderId,
          role: GroupRole.founder,
        );
        _state = LoadingState.loaded;
        notifyListeners();
      },
      onFailure: _setFailure,
    );
    return result;
  }

  Future<void> load({required String groupId, required String userId}) async {
    _start();
    final results = await Future.wait<Object>([
      _repository.getGroup(groupId),
      _repository.getMembership(groupId, userId),
    ]);
    final groupResult = results[0] as Result<Group>;
    final membershipResult = results[1] as Result<GroupMember?>;
    if (!groupResult.isSuccess) {
      _setFailure(groupResult.failureOrNull!);
      return;
    }
    if (!membershipResult.isSuccess) {
      _setFailure(membershipResult.failureOrNull!);
      return;
    }
    _group = groupResult.valueOrNull;
    _membership = membershipResult.valueOrNull;
    _state = LoadingState.loaded;
    notifyListeners();
  }

  Future<void> search(String query) async {
    _start();
    final result = await _repository.searchGroups(query);
    result.fold(
      onSuccess: (groups) {
        _searchResults = groups;
        _state = groups.isEmpty ? LoadingState.empty : LoadingState.loaded;
        notifyListeners();
      },
      onFailure: _setFailure,
    );
  }

  Future<void> loadJoined(String userId) => openJoined(userId);

  Future<void> openJoined(String userId) async {
    if (_joinedUserId == userId && _joinedSubscription != null) return;
    await _joinedSubscription?.cancel();
    _joinedUserId = userId;
    _joinedFailure = null;
    _joinedState = LoadingState.loading;
    notifyListeners();
    final first = Completer<void>();
    _joinedSubscription = _repository.watchJoinedGroups(userId).listen(
      (result) {
        if (_disposed) return;
        result.fold(
          onSuccess: (groups) {
            _joinedGroups = groups;
            _joinedFailure = null;
            _joinedState =
                groups.isEmpty ? LoadingState.empty : LoadingState.loaded;
          },
          onFailure: (failure) {
            _joinedFailure = failure;
            _joinedState = failure is NetworkError
                ? LoadingState.offline
                : LoadingState.error;
          },
        );
        if (!first.isCompleted) first.complete();
        notifyListeners();
      },
      onError: (_) {
        if (!first.isCompleted) first.complete();
      },
    );
    await first.future;
  }

  Future<void> closeJoined() async {
    await _joinedSubscription?.cancel();
    _joinedSubscription = null;
    _joinedUserId = null;
    _joinedGroups = const <Group>[];
    _joinedFailure = null;
    _joinedState = LoadingState.initial;
    if (!_disposed) notifyListeners();
  }

  Future<Result<void>> join(
    String groupId, {
    required String userId,
    String? inviteId,
  }) async {
    _start();
    final result = await _repository.joinGroup(
      groupId: groupId,
      inviteId: inviteId,
    );
    if (!result.isSuccess) {
      _setFailure(result.failureOrNull!);
      return result;
    }
    // joinGroup returns {ok: true} only. Read the real membership document.
    final membershipResult = await _repository.getMembership(groupId, userId);
    if (!membershipResult.isSuccess) {
      _setFailure(membershipResult.failureOrNull!);
      return FailureResult<void>(membershipResult.failureOrNull!);
    }
    final membership = membershipResult.valueOrNull;
    if (membership == null) {
      const failure = UnknownError(
        'Membership was not available after joining.',
      );
      _setFailure(failure);
      return const FailureResult<void>(failure);
    }
    _membership = membership;
    final groupResult = await _repository.getGroup(groupId);
    if (groupResult.isSuccess) {
      _group = groupResult.valueOrNull;
    }
    _state = LoadingState.loaded;
    notifyListeners();
    return result;
  }

  Future<Result<void>> requestToJoin(String groupId) async {
    _start();
    final result = await _repository.requestToJoin(groupId: groupId);
    result.fold(
      onSuccess: (_) {
        _state = LoadingState.loaded;
        notifyListeners();
      },
      onFailure: _setFailure,
    );
    return result;
  }

  Future<Result<void>> updateSettings({
    required String groupId,
    required GroupSettingsUpdate settings,
  }) async {
    _failure = null;
    _state = LoadingState.refreshing;
    notifyListeners();
    final result = await _repository.updateGroupSettings(
      groupId: groupId,
      settings: settings,
    );
    if (!result.isSuccess) {
      _setFailure(result.failureOrNull!);
      return result;
    }
    final groupResult = await _repository.getGroup(groupId);
    if (groupResult.isSuccess && groupResult.valueOrNull != null) {
      _group = groupResult.valueOrNull;
    } else {
      final current = _group;
      if (current != null && current.id == groupId) {
        _group = current.copyWith(
          name: settings.name,
          description: settings.description,
          rules: settings.rules,
          joinPolicy: settings.joinPolicy,
          isSearchable: settings.isSearchable,
        );
      }
    }
    _state = LoadingState.loaded;
    notifyListeners();
    return result;
  }

  Future<Result<void>> disband(String groupId) async {
    _start();
    final result = await _repository.disbandGroup(groupId);
    result.fold(
      onSuccess: (_) {
        _group = null;
        _membership = null;
        _state = LoadingState.empty;
        notifyListeners();
      },
      onFailure: _setFailure,
    );
    return result;
  }

  void leaveOptimistically(String groupId) {
    if (_membership == null || _leaveState == LeaveState.pending) return;
    final previous = _membership;
    _membership = null;
    _leaveState = LeaveState.pending;
    notifyListeners();
    final operation = _confirmLeave(groupId, previous!);
    _leaveOperation = operation;
    unawaited(operation);
  }

  Future<void> _confirmLeave(String groupId, GroupMember previous) async {
    final result = await _repository.leaveGroup(groupId);
    if (_disposed) return;
    result.fold(
      onSuccess: (_) {
        _leaveState = LeaveState.confirmed;
        _failure = null;
        notifyListeners();
      },
      onFailure: (failure) {
        _membership = previous;
        _leaveState = LeaveState.reverted;
        _failure = failure;
        _state = failure is NetworkError
            ? LoadingState.offline
            : LoadingState.error;
        notifyListeners();
      },
    );
  }

  void _start() {
    _failure = null;
    _state = LoadingState.loading;
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

  @override
  void dispose() {
    _disposed = true;
    unawaited(_joinedSubscription?.cancel());
    super.dispose();
  }
}
