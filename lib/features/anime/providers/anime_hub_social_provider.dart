import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/anime_list_models.dart';
import '../models/anime_rating_models.dart';
import '../repositories/anime_hub_social_repository.dart';

final class AnimeHubSocialProvider extends ChangeNotifier {
  AnimeHubSocialProvider({required AnimeHubSocialRepository repository})
    : _repository = repository;

  final AnimeHubSocialRepository _repository;
  bool _disposed = false;

  AnimeCommunityStats? _stats;
  final Map<String, AnimeCommunityStats> _statsById =
      <String, AnimeCommunityStats>{};
  AnimeReview? _myRating;
  List<AnimeReview> _reviews = const <AnimeReview>[];
  LoadingState _animeState = LoadingState.initial;
  Failure? _animeFailure;
  bool _saving = false;
  String? _animeId;

  List<AnimeCommunityStats> _topRated = const <AnimeCommunityStats>[];
  LoadingState _topState = LoadingState.initial;
  Failure? _topFailure;

  List<CharacterCommunityStats> _popularCharacters =
      const <CharacterCommunityStats>[];
  LoadingState _charactersState = LoadingState.initial;
  Failure? _charactersFailure;

  List<AnimeReview> _userRatings = const <AnimeReview>[];
  List<AnimeListEntry> _userList = const <AnimeListEntry>[];
  List<CharacterFavorite> _userCharacters = const <CharacterFavorite>[];
  LoadingState _userState = LoadingState.initial;
  Failure? _userFailure;
  String? _userId;

  AnimeCommunityStats? get stats => _stats;

  AnimeCommunityStats? statsFor(String animeId) {
    final id = animeId.trim();
    if (id.isEmpty) return null;
    if (_stats?.animeId == id) return _stats;
    return _statsById[id];
  }
  AnimeReview? get myRating => _myRating;
  List<AnimeReview> get reviews => _reviews;
  LoadingState get animeState => _animeState;
  Failure? get animeFailure => _animeFailure;
  bool get saving => _saving;

  List<AnimeCommunityStats> get topRated => _topRated;
  LoadingState get topState => _topState;
  Failure? get topFailure => _topFailure;

  List<CharacterCommunityStats> get popularCharacters => _popularCharacters;
  LoadingState get popularCharactersState => _charactersState;
  Failure? get popularCharactersFailure => _charactersFailure;

  List<AnimeReview> get userRatings => _userRatings;
  List<AnimeListEntry> get userList => _userList;
  List<CharacterFavorite> get userCharacters => _userCharacters;
  LoadingState get userState => _userState;
  Failure? get userFailure => _userFailure;

  Future<void> loadAnime(String animeId) async {
    _animeId = animeId;
    _animeState = LoadingState.loading;
    _animeFailure = null;
    _safeNotify();
    final stats = await _repository.getAnimeStats(animeId);
    final mine = await _repository.getMyRating(animeId);
    final reviews = await _repository.listReviews(animeId);
    if (_disposed || _animeId != animeId) return;
    _stats = stats.valueOrNull;
    final loaded = _stats;
    if (loaded != null) _statsById[loaded.animeId] = loaded;
    _myRating = mine.valueOrNull;
    _reviews = reviews.valueOrNull ?? const <AnimeReview>[];
    _animeFailure =
        stats.failureOrNull ?? mine.failureOrNull ?? reviews.failureOrNull;
    _animeState = LoadingState.loaded;
    _safeNotify();
  }

  Future<Result<void>> saveRating({
    required AnimeCriteriaScores criteria,
    required String title,
    String? imageUrl,
    String comment = '',
  }) async {
    final animeId = _animeId;
    if (animeId == null) {
      return const FailureResult(ValidationError('Anime is required.'));
    }
    _saving = true;
    _safeNotify();
    final result = await _repository.upsertRating(
      animeId: animeId,
      criteria: criteria,
      title: title,
      imageUrl: imageUrl,
      comment: comment,
    );
    if (_disposed) return _asVoid(result);
    result.fold(
      onSuccess: (review) {
        _myRating = review;
        _reviews = <AnimeReview>[
          review,
          ..._reviews.where((item) => item.userId != review.userId),
        ];
      },
      onFailure: (failure) => _animeFailure = failure,
    );
    _saving = false;
    await loadAnime(animeId);
    return _asVoid(result);
  }

  Future<Result<void>> reportReview({
    required String targetUserId,
    required String reason,
  }) async {
    final animeId = _animeId;
    if (animeId == null) {
      return const FailureResult(ValidationError('Anime is required.'));
    }
    return _repository.reportReview(
      animeId: animeId,
      targetUserId: targetUserId,
      reason: reason,
    );
  }

  Future<void> loadTopRated() async {
    _topState = LoadingState.loading;
    _safeNotify();
    final result = await _repository.listTopRated();
    if (_disposed) return;
    result.fold(
      onSuccess: (items) {
        _topRated = items;
        for (final item in items) {
          _statsById[item.animeId] = item;
        }
        _topState = items.isEmpty ? LoadingState.empty : LoadingState.loaded;
        _topFailure = null;
      },
      onFailure: (failure) {
        _topFailure = failure;
        _topState = _topRated.isEmpty ? LoadingState.error : LoadingState.loaded;
      },
    );
    _safeNotify();
  }

  Future<void> loadPopularCharacters() async {
    _charactersState = LoadingState.loading;
    _safeNotify();
    final result = await _repository.listPopularCharacters();
    if (_disposed) return;
    result.fold(
      onSuccess: (items) {
        _popularCharacters = items;
        _charactersState =
            items.isEmpty ? LoadingState.empty : LoadingState.loaded;
        _charactersFailure = null;
      },
      onFailure: (failure) {
        _charactersFailure = failure;
        _charactersState = _popularCharacters.isEmpty
            ? LoadingState.error
            : LoadingState.loaded;
      },
    );
    _safeNotify();
  }

  Future<CharacterCommunityStats?> characterStats(String characterId) async {
    final result = await _repository.getCharacterStats(characterId);
    return result.valueOrNull;
  }

  Future<void> loadUser(String userId) async {
    _userId = userId;
    _userState = LoadingState.loading;
    _safeNotify();
    final ratings = await _repository.listUserRatings(userId);
    final list = await _repository.listUserAnimeList(userId);
    final characters = await _repository.listUserCharacterFavorites(userId);
    if (_disposed || _userId != userId) return;
    _userRatings = ratings.valueOrNull ?? const <AnimeReview>[];
    _userList = list.valueOrNull ?? const <AnimeListEntry>[];
    _userCharacters = characters.valueOrNull ?? const <CharacterFavorite>[];
    _userFailure =
        ratings.failureOrNull ?? list.failureOrNull ?? characters.failureOrNull;
    _userState = LoadingState.loaded;
    _safeNotify();
  }

  Result<void> _asVoid<T>(Result<T> result) {
    return result.fold(
      onSuccess: (_) => const Success<void>(null),
      onFailure: FailureResult<void>.new,
    );
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

AnimeHubSocialProvider? maybeAnimeHubSocial(
  BuildContext context, {
  bool listen = true,
}) {
  try {
    return Provider.of<AnimeHubSocialProvider>(context, listen: listen);
  } on ProviderNotFoundException {
    return null;
  }
}
