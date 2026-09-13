import 'package:flutter/material.dart';

/// Official default group-chat wallpaper shipped with Pubget (WhatsApp-style).
const kPubgetDefaultChatWallpaperAsset =
    'assets/chat/pubget_default_wallpaper.png';

const kPubgetDefaultChatBackgroundId = 'pubget://default';

final class ChatContrastTheme {
  const ChatContrastTheme({
    required this.background,
    required this.scrim,
    required this.incomingBubble,
    required this.outgoingBubble,
    required this.incomingText,
    required this.outgoingText,
    required this.border,
    required this.shadow,
    this.isImageBackground = false,
  });

  final BoxDecoration background;
  final Color scrim;
  final Color incomingBubble;
  final Color outgoingBubble;
  final Color incomingText;
  final Color outgoingText;
  final Color border;
  final Color shadow;
  final bool isImageBackground;

  /// Resolves a stored `chatBackgroundUrl` (null / preset / remote) into
  /// bubble colors that stay readable on busy anime wallpapers.
  factory ChatContrastTheme.fromBackground(String? value) {
    final raw = value?.trim();
    if (raw == null ||
        raw.isEmpty ||
        raw == kPubgetDefaultChatBackgroundId) {
      return ChatContrastTheme._image(
        image: const AssetImage(kPubgetDefaultChatWallpaperAsset),
        // Official collage is dark navy with purple/gold line art.
        backgroundIsDark: true,
      );
    }

    final preset = switch (raw) {
      'pubget://midnight' => (
        const <Color>[Color(0xFF100B1A), Color(0xFF312056)],
        true,
      ),
      'pubget://dawn' => (
        const <Color>[Color(0xFFFFE6C7), Color(0xFFE7CBFF)],
        false,
      ),
      'pubget://forest' => (
        const <Color>[Color(0xFF14352A), Color(0xFF2E6655)],
        true,
      ),
      'pubget://royal' => (
        const <Color>[Color(0xFF4B258C), Color(0xFF171021)],
        true,
      ),
      _ => null,
    };

    if (preset != null) {
      return ChatContrastTheme._gradient(
        colors: preset.$1,
        backgroundIsDark: preset.$2,
      );
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return ChatContrastTheme._image(
        image: NetworkImage(raw),
        // Unknown remote wallpapers: assume busy/dark and lean on a stronger scrim.
        backgroundIsDark: true,
      );
    }

    // Unknown scheme — fall back to the official default wallpaper.
    return ChatContrastTheme.fromBackground(null);
  }

  factory ChatContrastTheme._gradient({
    required List<Color> colors,
    required bool backgroundIsDark,
  }) {
    final incoming = backgroundIsDark
        ? const Color(0xFF202C33)
        : const Color(0xFFFFFFFF);
    final outgoing = backgroundIsDark
        ? const Color(0xFF5B2F9E)
        : const Color(0xFFE9D9FF);
    return ChatContrastTheme(
      background: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      scrim: backgroundIsDark
          ? Colors.black.withValues(alpha: 0.18)
          : Colors.white.withValues(alpha: 0.14),
      incomingBubble: incoming,
      outgoingBubble: outgoing,
      incomingText: _highestContrast(incoming),
      outgoingText: _highestContrast(outgoing),
      border: backgroundIsDark
          ? Colors.white.withValues(alpha: 0.22)
          : Colors.black.withValues(alpha: 0.16),
      shadow: backgroundIsDark
          ? Colors.black.withValues(alpha: 0.55)
          : Colors.black.withValues(alpha: 0.22),
    );
  }

  factory ChatContrastTheme._image({
    required ImageProvider image,
    required bool backgroundIsDark,
  }) {
    final incoming = backgroundIsDark
        ? const Color(0xFF202C33)
        : const Color(0xFFFFFFFF);
    final outgoing = backgroundIsDark
        ? const Color(0xFF5B2F9E)
        : const Color(0xFFE9D9FF);
    return ChatContrastTheme(
      background: BoxDecoration(
        image: DecorationImage(
          image: image,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
        ),
        color: const Color(0xFF0B1020),
      ),
      // Stronger overlay so dense anime line-art never fights bubble text.
      scrim: backgroundIsDark
          ? Colors.black.withValues(alpha: 0.42)
          : Colors.white.withValues(alpha: 0.28),
      incomingBubble: incoming,
      outgoingBubble: outgoing,
      incomingText: _highestContrast(incoming),
      outgoingText: _highestContrast(outgoing),
      border: backgroundIsDark
          ? Colors.white.withValues(alpha: 0.28)
          : Colors.black.withValues(alpha: 0.18),
      shadow: Colors.black.withValues(alpha: 0.55),
      isImageBackground: true,
    );
  }

  static Color _highestContrast(Color background) {
    final whiteRatio = _contrast(background, Colors.white);
    final blackRatio = _contrast(background, const Color(0xFF171021));
    return whiteRatio >= blackRatio ? Colors.white : const Color(0xFF171021);
  }

  static double _contrast(Color a, Color b) {
    final lighter = a.computeLuminance() > b.computeLuminance() ? a : b;
    final darker = identical(lighter, a) ? b : a;
    return (lighter.computeLuminance() + 0.05) /
        (darker.computeLuminance() + 0.05);
  }

  /// WCAG-adjacent readability check used by acceptance tests.
  bool get bubblesAreReadable {
    return _contrast(incomingBubble, incomingText) >= 4.5 &&
        _contrast(outgoingBubble, outgoingText) >= 4.5;
  }
}

/// Picker catalog: official wallpaper first, then named Pubget presets.
const pubgetChatBackgrounds = <(String?, String, List<Color>?)>[
  (null, 'Pubget Classic', null),
  (
    'pubget://royal',
    'Royal Gradient',
    <Color>[Color(0xFF4B258C), Color(0xFF171021)],
  ),
  (
    'pubget://midnight',
    'Midnight',
    <Color>[Color(0xFF100B1A), Color(0xFF312056)],
  ),
  ('pubget://dawn', 'Dawn', <Color>[Color(0xFFFFE6C7), Color(0xFFE7CBFF)]),
  ('pubget://forest', 'Forest', <Color>[Color(0xFF14352A), Color(0xFF2E6655)]),
];
