import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colors = isDark
        ? (
            background: AppColors.darkBackground,
            surface: AppColors.darkSurface,
            mutedSurface: AppColors.darkSurfaceMuted,
            strongSurface: AppColors.darkSurfaceStrong,
            text: AppColors.darkText,
            mutedText: AppColors.darkTextMuted,
            outline: AppColors.darkOutline,
            primary: AppColors.royalPurpleLight,
            onPrimary: AppColors.darkBackground,
            primaryContainer: AppColors.royalPurpleDark,
            onPrimaryContainer: AppColors.royalPurplePale,
            secondary: AppColors.goldLight,
            onSecondary: AppColors.royalPurpleDark,
            secondaryContainer: AppColors.goldDark,
            onSecondaryContainer: AppColors.goldPale,
          )
        : (
            background: AppColors.lightBackground,
            surface: AppColors.lightSurface,
            mutedSurface: AppColors.lightSurfaceMuted,
            strongSurface: AppColors.lightSurfaceStrong,
            text: AppColors.lightText,
            mutedText: AppColors.lightTextMuted,
            outline: AppColors.lightOutline,
            primary: AppColors.royalPurple,
            onPrimary: AppColors.white,
            primaryContainer: AppColors.royalPurplePale,
            onPrimaryContainer: AppColors.royalPurpleDark,
            secondary: AppColors.gold,
            onSecondary: AppColors.royalPurpleDark,
            secondaryContainer: AppColors.goldPale,
            onSecondaryContainer: AppColors.goldDark,
          );

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.royalPurple,
          brightness: brightness,
        ).copyWith(
          primary: colors.primary,
          onPrimary: colors.onPrimary,
          primaryContainer: colors.primaryContainer,
          onPrimaryContainer: colors.onPrimaryContainer,
          secondary: colors.secondary,
          onSecondary: colors.onSecondary,
          secondaryContainer: colors.secondaryContainer,
          onSecondaryContainer: colors.onSecondaryContainer,
          surface: colors.surface,
          onSurface: colors.text,
          surfaceContainerHighest: colors.strongSurface,
          outline: colors.outline,
          error: isDark ? AppColors.error : AppColors.errorDark,
          onError: AppColors.white,
        );

    final typography = AppTypography.forBrightness(brightness);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: colors.outline),
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      useMaterial3: true,
      textTheme: typography,
      dividerTheme: DividerThemeData(
        color: colors.outline.withValues(alpha: 0.25),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: typography.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.mutedSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        hintStyle: typography.bodyMedium?.copyWith(color: colors.mutedText),
        labelStyle: typography.bodyMedium,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: colors.strongSurface,
          disabledForegroundColor: colors.mutedText,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          side: BorderSide(color: scheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.strongSurface,
        contentTextStyle: typography.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.strongSurface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: typography.bodySmall?.copyWith(color: colors.text),
      ),
    );
  }
}
