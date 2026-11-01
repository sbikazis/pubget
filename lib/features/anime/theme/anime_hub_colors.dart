import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';

/// Anime Hub identity.
///
/// The hub owns its own royal purple / gold pair so the rest of the app keeps
/// its existing palette untouched. [AnimeHubColors.of] falls back to the app
/// palette when a widget renders outside an Anime Hub subtree.
@immutable
final class AnimeHubColors extends ThemeExtension<AnimeHubColors> {
  const AnimeHubColors({
    required this.royalPurple,
    required this.gold,
    required this.surfaceTint,
    required this.gradient,
  });

  /// The Anime Hub signature purple.
  final Color royalPurple;

  /// The Anime Hub signature gold, used for ratings, favourites and accents.
  final Color gold;

  /// Slightly lifted purple used for cards and sheets inside the hub.
  final Color surfaceTint;

  /// Backdrop for the hub header and hero.
  final List<Color> gradient;

  static const signaturePurple = Color(0xFF4A1A8B);
  static const signatureGold = Color(0xFFFFD700);

  static const dark = AnimeHubColors(
    royalPurple: signaturePurple,
    gold: signatureGold,
    surfaceTint: Color(0xFF241542),
    gradient: <Color>[Color(0xFF1B0E33), Color(0xFF130A24), Color(0xFF1B0E33)],
  );

  static const light = AnimeHubColors(
    royalPurple: signaturePurple,
    gold: Color(0xFFD9B400),
    surfaceTint: Color(0xFFF3ECFF),
    gradient: <Color>[Color(0xFFFFFFFF), Color(0xFFFAF5FF), Color(0xFFF3ECFF)],
  );

  static AnimeHubColors of(BuildContext context) =>
      Theme.of(context).extension<AnimeHubColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  /// The gold that stays legible on light surfaces.
  Color get readableGold =>
      ThemeData.estimateBrightnessForColor(gold) == Brightness.dark
      ? gold
      : const Color(0xFF8A6A00);

  @override
  AnimeHubColors copyWith({
    Color? royalPurple,
    Color? gold,
    Color? surfaceTint,
    List<Color>? gradient,
  }) => AnimeHubColors(
    royalPurple: royalPurple ?? this.royalPurple,
    gold: gold ?? this.gold,
    surfaceTint: surfaceTint ?? this.surfaceTint,
    gradient: gradient ?? this.gradient,
  );

  @override
  AnimeHubColors lerp(ThemeExtension<AnimeHubColors>? other, double t) {
    if (other is! AnimeHubColors) return this;
    return AnimeHubColors(
      royalPurple: Color.lerp(royalPurple, other.royalPurple, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      surfaceTint: Color.lerp(surfaceTint, other.surfaceTint, t)!,
      gradient: <Color>[
        Color.lerp(gradient.first, other.gradient.first, t)!,
        Color.lerp(gradient[1], other.gradient[1], t)!,
        Color.lerp(gradient.last, other.gradient.last, t)!,
      ],
    );
  }
}

/// The hub's poster shape: a 3:4 cover with a generous radius.
const animeHubPosterRadius = BorderRadius.all(Radius.circular(AppRadius.xl));

/// Character portraits are square with a softer, larger radius.
const animeHubPortraitRadius = BorderRadius.all(Radius.circular(32));

/// Character portrait edge length mandated by the hub spec.
const animeHubPortraitSize = 220.0;
