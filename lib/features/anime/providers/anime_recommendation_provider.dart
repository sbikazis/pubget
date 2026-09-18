import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../models/anime_list_models.dart';
import '../models/anime_models.dart';
import '../models/anime_rating_models.dart';
import 'anime_hub_social_provider.dart';
import '../repositories/anime_hub_social_repository.dart';
import '../repositories/anime_repository.dart';

final class AnimeRecommendationProvider extends ChangeNotifier {
  AnimeRecommendationProvider({
    required AnimeHubSocialProvider social,
    required AnimeRepository repository,
    required String userId,
  }) : _social = social,
       _repository = repository,
       _userId = userId;

  final AnimeHubSocialProvider _social;
  final AnimeRepository _repository;
  String _userId;
  LoadingState _state = LoadingState.initial;
  Failure? _failure;
  List<AnimeRecommendation> _recommendations = const <AnimeRecommendation>[];

  LoadingState get state => _state;
  Failure? get failure => _failure;
  List<AnimeRecommendation> get recommendations =>
      List<AnimeRecommendation>.unmodifiable(_recommendations);

  void bindUser(String userId) {
    if (_userId == userId) return;
    _userId = userId;
    unawaited(load());
  }

  Future<void> load() async {
    if (_userId.isEmpty) {
      _state = LoadingState.empty;
      notifyListeners();
      return;
    }
    _state = LoadingState.loading;
    _failure = null;
    notifyListeners();

    try {
      await _social.loadUser(_userId);

      final userLists = _social.userList;
      final userRatings = _social.userRatings;
      final userFavorites = <String>{};

      final favoriteGenres = _extractFavoriteGenres(userLists, userFavorites);
      final ratedGenres = _extractRatedGenres(userRatings);
      final allPreferredGenres = <String>{
        ...favoriteGenres,
        ...ratedGenres,
      };

      final candidateResult = await _repository.getPopular(limit: 50);
      final candidates = candidateResult.fold(
        onSuccess: (page) => page.items,
        onFailure: (_) => <Anime>[],
      );

      final scored = <AnimeRecommendation>[];
      for (final anime in candidates) {
        if (userLists.any((e) => e.animeId == anime.id)) continue;

        final score = _scoreAnime(
          anime,
          favoriteGenres,
          ratedGenres,
          allPreferredGenres,
        );
        if (score > 0) {
          scored.add(AnimeRecommendation(anime: anime, score: score));
        }
      }

      scored.sort((a, b) => b.score.compareTo(a.score));
      _recommendations = scored.take(20).toList(growable: false);
      _state = LoadingState.loaded;
    } on Object catch (error) {
      _failure = UnknownError(error.toString());
      _state = LoadingState.error;
    }
    notifyListeners();
  }

  Set<String> _extractFavoriteGenres(
    List<AnimeListEntry> lists,
    Set<String> favoriteIds,
  ) {
    final genres = <String>{};
    for (final entry in lists) {
      if (favoriteIds.contains(entry.animeId)) {
        // We'd need anime details for genres; simplified for now
      }
    }
    return genres;
  }

  Set<String> _extractRatedGenres(List<AnimeReview> ratings) {
    // Would need anime details; placeholder
    return <String>{};
  }

  int _scoreAnime(
    Anime anime,
    Set<String> favoriteGenres,
    Set<String> ratedGenres,
    Set<String> allPreferredGenres,
  ) {
    var score = 0;
    final animeGenres = anime.genres.map((g) => g.name).toSet();

    final genreOverlap = animeGenres.intersection(allPreferredGenres).length;
    score += genreOverlap * 10;

    if (anime.score != null && anime.score! > 0) {
      score += (anime.score! * 2).round();
    }

    return score;
  }
}

final class AnimeRecommendation {
  const AnimeRecommendation({
    required this.anime,
    required this.score,
  });

  final Anime anime;
  final int score;
}