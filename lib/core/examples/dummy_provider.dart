import 'package:flutter/foundation.dart';

import '../errors/result.dart';
import '../loading/loading_state.dart';
import 'dummy_repository.dart';

/// Small, domain-free example of a Provider consuming a Repository.
class DummyProvider extends ChangeNotifier {
  DummyProvider({required DummyRepository repository})
    : _repository = repository;

  final DummyRepository _repository;
  LoadingState _state = LoadingState.initial;
  String? _greeting;
  Result<String>? _lastResult;

  LoadingState get state => _state;
  String? get greeting => _greeting;
  Result<String>? get lastResult => _lastResult;

  Future<void> load() async {
    _state = LoadingState.loading;
    notifyListeners();

    final result = await _repository.loadGreeting();
    _lastResult = result;
    result.fold(
      onSuccess: (value) {
        _greeting = value;
        _state = value.isEmpty ? LoadingState.empty : LoadingState.loaded;
      },
      onFailure: (_) => _state = LoadingState.error,
    );
    notifyListeners();
  }
}
