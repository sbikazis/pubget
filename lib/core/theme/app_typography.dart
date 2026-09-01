import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static TextTheme forBrightness(Brightness brightness) {
    final color = brightness == Brightness.dark
        ? AppColors.darkText
        : AppColors.lightText;
    final mutedColor = brightness == Brightness.dark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;

    return TextTheme(
      displayLarge: _style(32, FontWeight.w700, color, -0.4),
      displayMedium: _style(28, FontWeight.w700, color, -0.25),
      displaySmall: _style(24, FontWeight.w700, color),
      headlineLarge: _style(22, FontWeight.w700, color),
      headlineMedium: _style(20, FontWeight.w700, color),
      headlineSmall: _style(18, FontWeight.w700, color),
      titleLarge: _style(18, FontWeight.w600, color),
      titleMedium: _style(16, FontWeight.w600, color),
      titleSmall: _style(14, FontWeight.w600, color),
      bodyLarge: _style(16, FontWeight.w400, color, 0.1, 1.45),
      bodyMedium: _style(14, FontWeight.w400, color, 0.1, 1.4),
      bodySmall: _style(12, FontWeight.w400, mutedColor, 0.2, 1.35),
      labelLarge: _style(14, FontWeight.w700, color, 0.1),
      labelMedium: _style(12, FontWeight.w700, color, 0.3),
      labelSmall: _style(11, FontWeight.w700, mutedColor, 0.4),
    );
  }

  static TextStyle _style(
    double size,
    FontWeight weight,
    Color color, [
    double letterSpacing = 0,
    double? height,
  ]) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}
