import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/group_models.dart';
import '../repositories/group_members_repository.dart';

final class GroupMembersProvider extends ChangeNotifier {
  GroupMembersProvider({required GroupMembersRepository repository})
    : _repository = repository;

  final GroupMembersRepository _repository;
  List<GroupMember> _members = const <GroupMember>[];
  List<JoinRequest> _requests = const <JoinRequest>[];
  List<GroupRoleDefinition> _roles = const <GroupRoleDefinition>[];
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  String? _groupId;
  bool _hasMore = true;

  List<GroupMember> get members => _members;
  List<JoinRequest> get requests => _requests;
  List<GroupRoleDefinition> get roles => _roles;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get hasMore => _hasMore;

  Future<void> load(String groupId) async {
    _groupId = groupId;
    _state = LoadingState.loading;
    notifyListeners();
    final result = await _repository.getMembers(groupId);
    result.fold(
      onSuccess: (members) {
        _members = members;
        _hasMore = members.length == 25;
        _state = members.isEmpty ? LoadingState.empty : LoadingState.loaded;
        notifyListeners();
      },
      onFailure: _setFailure,
    );
  }

  Future<void> loadMore() async {
    final groupId = _groupId;
    if (groupId == null || !_hasMore || _members.isEmpty) return;
    _state = LoadingState.loadingMore;
    notifyListeners();
    final result = await _repository.getMembers(
      groupId,
      afterUid: _members.last.uid,
    );
    result.fold(
      onSuccess: (members) {
        _members = <GroupMember>[..._members, ...members];
        _hasMore = members.length == 25;
        _state = LoadingState.loaded;
        notifyListeners();
      },
      onFailure: _setFailure,
    );
  }

  Future<void> loadRequests(String groupId) async {
    _groupId = groupId;
    _state = LoadingState.loading;
    notifyListeners();
    final result = await _repository.getJoinRequests(groupId);
    result.fold(
      onSuccess: (requests) {
        _requests = requests;
        _state = requests.isEmpty ? LoadingState.empty : LoadingState.loaded;
        notifyListeners();
      },
      onFailure: _setFailure,
    );
  }

  Future<void> loadRoles(String groupId) async {
    _groupId = groupId;
    _state = LoadingState.loading;
    notifyListeners();
    final result = await _repository.getRoles(groupId);
    result.fold(
      onSuccess: (roles) {
        _roles = roles;
        _state = roles.isEmpty ? LoadingState.empty : LoadingState.loaded;
        notifyListeners();
      },
      onFailure: _setFailure,
    );
  }

  Future<Result<String>> createInvite(String toUid) async {
    final result = await _repository.createInvite(
      groupId: _groupId!,
      toUid: toUid,
    );
    if (!result.isSuccess) _setFailure(result.failureOrNull!);
    return result;
  }

  Future<Result<void>> updateRolePermissions(
    GroupRole role,
    Set<GroupPermission> permissions,
  ) async {
    final result = await _repository.updateRolePermissions(
      groupId: _groupId!,
      role: role,
      permissions: permissions,
    );
    if (!result.isSuccess) {
      _setFailure(result.failureOrNull!);
    } else {
      await loadRoles(_groupId!);
    }
    return result;
  }

  Future<Result<void>> changeRole(String uid, GroupRole role) => _act(
    () => _repository.changeRole(groupId: _groupId!, uid: uid, role: role),
  );

  Future<Result<void>> kick(String uid) =>
      _act(() => _repository.kickMember(groupId: _groupId!, uid: uid));

  Future<Result<void>> ban(String uid) =>
      _act(() => _repository.banMember(groupId: _groupId!, uid: uid));

  Future<Result<void>> transferOwnership(String uid) async {
    _state = LoadingState.refreshing;
    notifyListeners();
    final prepared = await _repository.prepareOwnershipTransfer(
      groupId: _groupId!,
      uid: uid,
    );
    if (!prepared.isSuccess) {
      _setFailure(prepared.failureOrNull!);
      return FailureResult<void>(prepared.failureOrNull!);
    }
    return _act(
      () => _repository.transferOwnership(
        groupId: _groupId!,
        uid: uid,
        confirmationToken: prepared.valueOrNull!,
      ),
    );
  }

  Future<Result<void>> decideRequest(String uid, {required bool accept}) =>
      _act(
        () => accept
            ? _repository.acceptJoinRequest(groupId: _groupId!, uid: uid)
            : _repository.rejectJoinRequest(groupId: _groupId!, uid: uid),
      );

  Future<Result<void>> _act(Future<Result<void>> Function() action) async {
    _state = LoadingState.refreshing;
    notifyListeners();
    final result = await action();
    if (!result.isSuccess) {
      _setFailure(result.failureOrNull!);
      return result;
    }
    if (_groupId != null) await load(_groupId!);
    return result;
  }

  void _setFailure(Failure failure) {
    _failure = failure;
    _state = failure is NetworkError
        ? LoadingState.offline
        : LoadingState.error;
    notifyListeners();
  }
}
