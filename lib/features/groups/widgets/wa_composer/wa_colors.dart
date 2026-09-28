import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Chat composer palette.
///
/// Layout and interaction follow the WhatsApp model the spec adopts
/// (axis 09.5 / 09.6), but every colour is a Pubget brand token — the chat is
/// Pubget, not WhatsApp. The accent is royal purple, so the mic, the send
/// affordance, the waveform, the emoji tab and the sticker actions all read as
/// one surface instead of borrowing WhatsApp green. Recording and destructive
/// affordances stay red: red is the universal "this is being recorded / this
/// will be discarded" signal and never carries brand meaning here.
///
/// The composer chrome (holding bar, locked bar, emoji panel, sticker sheet) is
/// an unconditionally dark surface, so [onDark] is the correct accent for
/// anything painted on those. [accent] is the context-aware variant for widgets
/// that sit on the themed composer pill.
abstract final class WaColors {
  static const darkPill = Color(0xFF2A2135);
  static const lightPill = Color(0xFFFFFFFF);
  static const darkPanel = Color(0xFF1E1826);
  static const iconMuted = Color(0xFF9B8DA6);
  static const textPrimary = Color(0xFFF5EFFB);
  static const darkAccent = AppColors.royalPurple;
  static const lightAccent = AppColors.royalPurpleLight;
  static const pulseRed = Color(0xFFF15C6D);
  static const recordRed = Color(0xFFE53935);
  static const handle = Color(0xFF3B2D4B);
  static const segmentIdle = Color(0xFF2A2135);
  static const segmentActive = Color(0xFF3B2D4B);
  static const createStickerBg = Color(0xFF2A2135);
  static const dimScrim = Color(0x66000000);
  static const cameraBlue = Color(0xFF0EABF5);
  static const galleryPurple = Color(0xFFBF59CF);
  static const gamesGreen = Color(0xFF00C851);
  static const eventOrange = Color(0xFFFF8C00);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Accent for the always-dark composer panels.
  static const Color onDark = lightAccent;

  /// Accent for widgets sitting on the themed composer pill. Matches the app
  /// [ColorScheme.primary] so the composer never disagrees with the shell.
  static Color accent(BuildContext context) =>
      isDark(context) ? lightAccent : darkAccent;

  static Color pill(BuildContext context) =>
      isDark(context) ? darkPill : lightPill;

  static Color send(BuildContext context) => accent(context);

  static Color attachmentSheet(BuildContext context) =>
      isDark(context) ? darkPill : lightPill;

  static Color hint(BuildContext context) => iconMuted;

  static Color fieldText(BuildContext context) =>
      isDark(context) ? textPrimary : const Color(0xFF231D2B);
}
