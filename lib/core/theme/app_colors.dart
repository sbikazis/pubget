import 'package:flutter/material.dart';

class AppColors {
  AppColors._();


  //  BRAND COLORS – Royal Purple Identity


  /// Primary brand color – deep royal purple (not feminine)
  static const Color primary = Color(0xFF5B2EFF);

  /// Slightly darker for pressed states
  static const Color primaryDark = Color(0xFF4A25CC);

  /// Light variation for subtle backgrounds
  static const Color primaryLight = Color(0xFF7A57FF);

  /// Optional elegant golden accent (used carefully)
  static const Color goldAccent = Color(0xFFFFC857);


  //  DARK MODE BASE


  static const Color darkBackground = Color(0xFF0F0F14);
  static const Color darkSurface = Color(0xFF1A1A22);
  static const Color darkCard = Color(0xFF22222B);

  static const Color darkBorder = Color(0xFF2E2E38);

  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFFB3B3C2);
  static const Color darkTextHint = Color(0xFF7C7C8A);


  //  LIGHT MODE BASE


  static const Color lightBackground = Color(0xFFF5F6FA);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Color(0xFFF0F1F7);

  static const Color lightBorder = Color(0xFFE0E0EA);

  static const Color lightTextPrimary = Color(0xFF1A1A1F);
  static const Color lightTextSecondary = Color(0xFF5F5F6B);
  static const Color lightTextHint = Color(0xFF9C9CA8);


  //   STANDARDIZED TEXT ALIASES (Used by AppTextTheme)


  static const Color textPrimaryLight = lightTextPrimary;
  static const Color textSecondaryLight = lightTextSecondary;
  static const Color textHintLight = lightTextHint;

  static const Color textPrimaryDark = darkTextPrimary;
  static const Color textSecondaryDark = darkTextSecondary;
  static const Color textHintDark = darkTextHint;


  //  STATUS COLORS


  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);


  //  CHAT SPECIFIC


  static const Color myMessageBubble = primary;
  static const Color otherMessageBubbleDark = Color(0xFF2A2A35);
  static const Color otherMessageBubbleLight = Color(0xFFE7E8F3);


  //  RESPECT SYSTEM


  static const Color respectBarBackground = Color(0xFF2D2D3A);
  static const Color respectBarFill = primary;


  //  PREMIUM / PROMOTION


  static const Color premiumBadgeBackground = goldAccent;
  static const Color premiumText = Color(0xFF1A1A1A);

  static const Color promotedBorder = goldAccent;


  //  DISABLED STATES


  static const Color disabled = Color(0xFF9CA3AF);
}