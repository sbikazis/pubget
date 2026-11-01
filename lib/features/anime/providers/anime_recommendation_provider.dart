import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/errors/failure.dart';
import '../../../core/loading/loading_state.dart';
import '../models/anime_list_models.dart';
import '../models/anime_models.dart';
import '../models/anime_rating_models.dart';
import 'anime_hub_social_provider.dart';
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

      // Fetch full anime details for user's list entries to extract genres
      final listAnimeIds = userLists.map((e) => e.animeId).toSet();
      final ratingAnimeIds = userRatings.map((e) => e.animeId).toSet();
      final allUserAnimeIds = <String>{...listAnimeIds, ...ratingAnimeIds};

      final animeDetails = await _fetchAnimeDetails(allUserAnimeIds);

      final favoriteGenres = _extractFavoriteGenres(userLists, animeDetails);
      final ratedGenres = _extractRatedGenres(userRatings, animeDetails);
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

  Future<Map<String, Anime>> _fetchAnimeDetails(Set<String> animeIds) async {
    if (animeIds.isEmpty) return <String, Anime>{};
    final details = <String, Anime>{};
    // Fetch in batches of 10 to avoid rate limits
    final batches = <List<String>>[];
    final buffer = <String>[];
    for (final id in animeIds) {
      buffer.add(id);
      if (buffer.length >= 10) {
        batches.add(List.from(buffer));
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty) batches.add(buffer);

    for (final batch in batches) {
      final results = await Future.wait([
        for (final id in batch) _repository.getAnimeDetails(id),
      ]);
      for (final (index, result) in results.indexed) {
        final id = batch[index];
        result.fold(
          onSuccess: (anime) => details[id] = anime,
          onFailure: (_) {},
        );
      }
      // Small delay between batches to be respectful to the API
      if (batches.length > 1) await Future.delayed(const Duration(milliseconds: 200));
    }
    return details;
  }

  Set<String> _extractFavoriteGenres(
    List<AnimeListEntry> lists,
    Map<String, Anime> animeDetails,
  ) {
    final genres = <String>{};
    for (final entry in lists) {
      if (entry.rating != null && entry.rating! >= 8) {
        // Consider high-rated entries as "favorites"
        final anime = animeDetails[entry.animeId];
        if (anime != null) {
          for (final genre in anime.genres) {
            genres.add(genre.name);
          }
        }
      }
    }
    return genres;
  }

  Set<String> _extractRatedGenres(
    List<AnimeReview> ratings,
    Map<String, Anime> animeDetails,
  ) {
    final genres = <String>{};
    for (final rating in ratings) {
      if (rating.overall >= 7) {
        final anime = animeDetails[rating.animeId];
        if (anime != null) {
          for (final genre in anime.genres) {
            genres.add(genre.name);
          }
        }
      }
    }
    return genres;
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

    // Bonus for highly rated by community
    if (anime.popularity != null && anime.popularity! < 1000) {
      score += 5;
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