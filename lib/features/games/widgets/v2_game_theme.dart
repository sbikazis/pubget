import 'package:flutter/material.dart';
import '../models/games_schema_v2.dart';

const _ink = Color(0xFF171225);
const _paper = Color(0xFFF7F3FA);
const _purple = Color(0xFF6D3FA5);
const _violet = Color(0xFF9A6BC7);
const _gold = Color(0xFFD8A84E);

ThemeData gamesV2Theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: _purple,
    brightness: brightness,
    primary: _purple,
    secondary: _gold,
    surface: dark ? const Color(0xFF211A30) : _paper,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF120E1A) : _paper,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF120E1A) : _paper,
      foregroundColor: dark ? Colors.white : _ink,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF211A30) : Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF2A203B) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class GameV2Palette {
  static const ink = _ink;
  static const purple = _purple;
  static const violet = _violet;
  static const gold = _gold;
  static const paper = _paper;
}

String gameTypeArabic(GameTypeV2 type) => switch (type) {
  GameTypeV2.guessCharacter => 'خمن الشخصية',
  GameTypeV2.animeChain => 'سلسلة الأنمي',
  GameTypeV2.emojiAnimeGuess => 'خمن الأنمي',
};

String gameStatusArabic(GameLifecycleStatusV2 status) => switch (status) {
  GameLifecycleStatusV2.created || GameLifecycleStatusV2.waiting => 'في الانتظار',
  GameLifecycleStatusV2.starting => 'يستعد للبدء',
  GameLifecycleStatusV2.inProgress => 'مباشر الآن',
  GameLifecycleStatusV2.completed => 'مكتملة',
  GameLifecycleStatusV2.cancelled => 'ملغاة',
};
