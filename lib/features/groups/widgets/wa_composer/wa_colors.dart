import 'package:flutter/material.dart';

/// WhatsApp-faithful chat composer palette (dark / light).
abstract final class WaColors {
  static const darkPill = Color(0xFF202C33);
  static const lightPill = Color(0xFFFFFFFF);
  static const darkPanel = Color(0xFF111B21);
  static const iconMuted = Color(0xFF8696A0);
  static const textPrimary = Color(0xFFD1D7DB);
  static const cursorGreen = Color(0xFF00A884);
  static const sendDark = Color(0xFF00A884);
  static const sendLight = Color(0xFF25D366);
  static const pulseRed = Color(0xFFF15C6D);
  static const recordRed = Color(0xFFE53935);
  static const handle = Color(0xFF3B4A54);
  static const segmentIdle = Color(0xFF202C33);
  static const segmentActive = Color(0xFF2A3942);
  static const createStickerBg = Color(0xFF1F2C34);
  static const dimScrim = Color(0x66000000);
  static const cameraBlue = Color(0xFF0EABF5);
  static const galleryPurple = Color(0xFFBF59CF);
  static const gamesGreen = Color(0xFF00C851);
  static const eventOrange = Color(0xFFFF8C00);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color pill(BuildContext context) =>
      isDark(context) ? darkPill : lightPill;

  static Color send(BuildContext context) =>
      isDark(context) ? sendDark : sendLight;

  static Color attachmentSheet(BuildContext context) =>
      isDark(context) ? darkPill : lightPill;

  static Color hint(BuildContext context) => iconMuted;

  static Color fieldText(BuildContext context) =>
      isDark(context) ? textPrimary : const Color(0xFF111B21);
}
