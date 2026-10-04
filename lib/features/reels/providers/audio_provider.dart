import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart' as result_lib;
import '../../../core/loading/loading_state.dart';
import '../models/audio_models.dart';
import '../repositories/audio_repository.dart';

final class AudioProvider extends ChangeNotifier {
  AudioProvider({required AudioRepository repository}) : _repository = repository;

  final AudioRepository _repository;
  final List<ReelAudio> _items = <ReelAudio>[];
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _disposed = false;

  List<ReelAudio> get items => List.unmodifiable(_items);
  LoadingState get state => _state;
  Failure? get failure => _failure;
  bool get hasMore => _hasMore;

  Future<void> load({bool refresh = false, String type = 'trending'}) async {
    if (_state == LoadingState.loading || _loadingMore) return;
    if (!refresh && _items.isNotEmpty) return;
    _state = refresh ? LoadingState.refreshing : LoadingState.loading;
    _failure = null;
    notifyListeners();

    final result = await _repository.listAudios(limit: 20, type: type);
    if (_disposed) return;
    result.fold(
      onSuccess: (page) {
        _items
          ..clear()
          ..addAll(page.items);
        _hasMore = page.hasMore;
        _state = _items.isEmpty ? LoadingState.empty : LoadingState.loaded;
      },
      onFailure: (failure) {
        _failure = failure;
        _state = _items.isNotEmpty ? LoadingState.offline : LoadingState.error;
      },
    );
    notifyListeners();
  }

  Future<void> loadMore({String type = 'trending'}) async {
    if (!_hasMore || _loadingMore || _items.isEmpty) return;
    _loadingMore = true;
    _state = LoadingState.loadingMore;
    notifyListeners();

    final result = await _repository.listAudios(
      limit: 20,
      afterId: _items.last.audioId,
      type: type,
    );
    if (_disposed) return;
    result.fold(
      onSuccess: (page) {
        final seen = _items.map((a) => a.audioId).toSet();
        _items.addAll(page.items.where((a) => seen.add(a.audioId)));
        _hasMore = page.hasMore;
        _state = LoadingState.loaded;
      },
      onFailure: (failure) {
        _failure = failure;
        _state = LoadingState.loaded;
      },
    );
    _loadingMore = false;
    notifyListeners();
  }

  Future<result_lib.Result<String>> extractAudio({
    required String reelId,
    String? audioName,
    int startMs = 0,
    int durationMs = 15000,
  }) => _repository.extractAudio(
    reelId: reelId,
    audioName: audioName,
    startMs: startMs,
    durationMs: durationMs,
  );

  Future<result_lib.Result<ReelAudio>> getAudio(String audioId) => _repository.getAudio(audioId);

  Future<result_lib.Result<void>> useAudio({required String audioId, required String reelId}) =>
      _repository.useAudio(audioId: audioId, reelId: reelId);

  Future<result_lib.Result<void>> removeAudio(String reelId) => _repository.removeAudio(reelId);

  Future<result_lib.Result<List<ReelAudio>>> searchAudios({
    required String query,
    int limit = 15,
  }) => _repository.searchAudios(query: query, limit: limit);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}