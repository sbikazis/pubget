import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_theme.dart';

class LightTheme {
  LightTheme._();

  static final ThemeData theme = ThemeData(
    useMaterial3: true,

    brightness: Brightness.light,


    // COLOR SCHEME (Material 3 Core)


    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primaryLight,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      background: AppColors.lightBackground,
      onBackground: AppColors.lightTextPrimary,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
    ),

    scaffoldBackgroundColor: AppColors.lightBackground,


    // TEXT THEME


    textTheme: AppTextTheme.lightTextTheme,


    // APP BAR


    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(
        color: AppColors.lightTextPrimary,
      ),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.lightTextPrimary,
      ),
    ),


    // CARD


    cardTheme: CardThemeData(
      color: AppColors.lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: AppColors.lightBorder,
        ),
      ),
    ),


    // INPUT FIELD


    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.lightBorder,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.lightBorder,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
      hintStyle: const TextStyle(
        color: AppColors.lightTextHint,
      ),
    ),


    // BUTTONS


    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),


    // DIVIDER


    dividerTheme: const DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 0.8,
    ),


    // DIALOG


    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),


    // BOTTOM SHEET


    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
    ),


    // SNACKBAR


    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.lightCard,
      contentTextStyle: const TextStyle(
        color: AppColors.lightTextPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}