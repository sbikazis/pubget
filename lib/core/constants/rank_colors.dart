import 'package:flutter/material.dart';

/// Central rank name colors + badge assets (MIKADO edition).
///
/// Keys use storage ids without diacritics (`RONIN`, `SHOGUN`, …).
final class RankColors {
  RankColors._();

  static const Color shogunGold = Color(0xFFC9A227);

  static const Map<String, Color> nameColor = <String, Color>{
    'RONIN': Color(0xFF0A2A6B),
    'GOKENIN': Color(0xFF0F3D2E),
    'SAMURAI': Color(0xFF8B1A1A),
    'HATAMOTO': Color(0xFF14A092),
    'DAIMYO': Color(0xFF0E8FB8),
    'SHOGUN': Color(0xFF9C1225),
    'MIKADO': Color(0xFF7A1FFF),
  };

  static const Map<String, String> badgeAsset = <String, String>{
    'RONIN': 'assets/images/ranks/ronin.png',
    'GOKENIN': 'assets/images/ranks/gokenin.png',
    'SAMURAI': 'assets/images/ranks/samurai.png',
    'HATAMOTO': 'assets/images/ranks/hatamoto.png',
    'DAIMYO': 'assets/images/ranks/daimyo.png',
    'SHOGUN': 'assets/images/ranks/shogun.png',
    'MIKADO': 'assets/images/ranks/mikado.png',
  };

  static Color colorForKey(String key) =>
      nameColor[key.toUpperCase()] ?? nameColor['RONIN']!;

  static String? assetForKey(String key) => badgeAsset[key.toUpperCase()];

  /// Username text style — MIKADO gets a radiant purple glow.
  static TextStyle nameTextStyleForKey(
    String key, {
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w700,
    double height = 1.15,
  }) {
    final normalized = key.toUpperCase();
    final color = colorForKey(normalized);
    return TextStyle(
      color: color,
      fontWeight: fontWeight,
      fontSize: fontSize,
      height: height,
      shadows: normalized == 'MIKADO'
          ? <Shadow>[
              Shadow(
                color: const Color(0xFF7A1FFF).withValues(alpha: 0.8),
                blurRadius: 12,
              ),
            ]
          : null,
    );
  }
}
