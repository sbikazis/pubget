import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_theme.dart';

class DarkTheme {
  DarkTheme._();

  static ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // =========================
    // COLOR SCHEME
    // =========================
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,

      primary: AppColors.primary,
      onPrimary: Colors.white,

      primaryContainer: AppColors.primaryDark,
      onPrimaryContainer: Colors.white,

      secondary: AppColors.primaryLight,
      onSecondary: Colors.white,

      secondaryContainer: AppColors.darkCard,
      onSecondaryContainer: Colors.white,

      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,

      surfaceContainer: AppColors.darkBackground,
      onSurfaceVariant: AppColors.darkTextPrimary,

      error: AppColors.error,
      onError: Colors.white,
    ),

    // =========================
    // GLOBAL BACKGROUNDS
    // =========================
    scaffoldBackgroundColor: AppColors.darkBackground,
    canvasColor: AppColors.darkBackground,

    // =========================
    // TEXT THEME
    // =========================
    textTheme: AppTextTheme.darkTextTheme,

    // =========================
    // LIST TILE THEME
    // =========================
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.darkTextPrimary,
      textColor: AppColors.darkTextPrimary,

      titleTextStyle:
          AppTextTheme.darkTextTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppColors.darkTextPrimary,
      ),

      subtitleTextStyle:
          AppTextTheme.darkTextTheme.bodyMedium?.copyWith(
        color: AppColors.darkTextSecondary,
      ),
    ),

    // =========================
    // APP BAR
    // =========================
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,

      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
      ),
    ),

    // =========================
    // ELEVATED BUTTON
    // =========================
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,

        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,

        disabledBackgroundColor: AppColors.disabled,
        disabledForegroundColor: Colors.white70,

        // ✅ الإصلاح الحقيقي
        // إزالة الـ double.infinity الذي كان يسبب
        // مشاكل constraints داخل Rows و Cards
        minimumSize: const Size(0, 50),

        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),

        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          fontSize: 14,
        ),
      ),
    ),

    // =========================
    // OUTLINED BUTTON
    // =========================
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,

        side: const BorderSide(
          color: AppColors.primary,
        ),

        // ✅ نفس الإصلاح هنا
        minimumSize: const Size(0, 50),

        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),

    // =========================
    // INPUT FIELDS
    // =========================
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkCard,

      hintStyle: const TextStyle(
        color: AppColors.darkTextHint,
      ),

      labelStyle: const TextStyle(
        color: AppColors.darkTextSecondary,
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.darkBorder,
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.darkBorder,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.error,
        ),
      ),
    ),

    // =========================
    // CARD THEME
    // =========================
    cardTheme: CardThemeData(
      color: AppColors.darkCard,
      elevation: 0,
      surfaceTintColor: Colors.transparent,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),

        side: const BorderSide(
          color: AppColors.darkBorder,
        ),
      ),
    ),

    // =========================
    // DIVIDER
    // =========================
    dividerTheme: const DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 0.6,
    ),

    // =========================
    // DIALOG
    // =========================
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 10,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),

        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),

      titleTextStyle: const TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),

      contentTextStyle: const TextStyle(
        color: AppColors.darkTextSecondary,
        fontSize: 16,
      ),
    ),

    // =========================
    // BOTTOM SHEET
    // =========================
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
    ),

    // =========================
    // SWITCH
    // =========================
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }

          return AppColors.darkBorder;
        },
      ),

      trackColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: 0.4);
          }

          return AppColors.darkCard;
        },
      ),
    ),

    // =========================
    // CHAT BUBBLE EXTENSION
    // =========================
    extensions: const <ThemeExtension<dynamic>>[
      ChatBubbleTheme(
        myBubbleColor: AppColors.myMessageBubble,
        otherBubbleColor: AppColors.otherMessageBubbleDark,
      ),
    ],
  );
}

// =========================
// CUSTOM CHAT BUBBLE THEME
// =========================
class ChatBubbleTheme
    extends ThemeExtension<ChatBubbleTheme> {
  final Color myBubbleColor;
  final Color otherBubbleColor;

  const ChatBubbleTheme({
    required this.myBubbleColor,
    required this.otherBubbleColor,
  });

  @override
  ChatBubbleTheme copyWith({
    Color? myBubbleColor,
    Color? otherBubbleColor,
  }) {
    return ChatBubbleTheme(
      myBubbleColor:
          myBubbleColor ?? this.myBubbleColor,

      otherBubbleColor:
          otherBubbleColor ?? this.otherBubbleColor,
    );
  }

  @override
  ChatBubbleTheme lerp(
    ThemeExtension<ChatBubbleTheme>? other,
    double t,
  ) {
    if (other is! ChatBubbleTheme) {
      return this;
    }

    return ChatBubbleTheme(
      myBubbleColor: Color.lerp(
        myBubbleColor,
        other.myBubbleColor,
        t,
      )!,

      otherBubbleColor: Color.lerp(
        otherBubbleColor,
        other.otherBubbleColor,
        t,
      )!,
    );
  }
}