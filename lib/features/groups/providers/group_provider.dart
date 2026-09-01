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
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  LeaveState _leaveState = LeaveState.idle;
  Future<void>? _leaveOperation;
  bool _disposed = false;

  Group? get group => _group;
  GroupMember? get membership => _membership;
  List<Group> get searchResults => _searchResults;
  LoadingState get state => _state;
  Failure? get failure => _failure;
  LeaveState get leaveState => _leaveState;
  Future<void>? get leaveOperation => _leaveOperation;
  bool get isMember => _membership != null;
  bool get isFounder => _membership?.role == GroupRole.founder;

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

  Future<Result<void>> join(String groupId, {String? inviteId}) async {
    _start();
    final result = await _repository.joinGroup(
      groupId: groupId,
      inviteId: inviteId,
    );
    result.fold(
      onSuccess: (_) {
        _membership = const GroupMember(uid: '', role: GroupRole.member);
        _state = LoadingState.loaded;
        notifyListeners();
      },
      onFailure: _setFailure,
    );
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
    super.dispose();
  }
}
