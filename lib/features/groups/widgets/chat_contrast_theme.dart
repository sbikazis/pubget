import 'package:flutter/material.dart';

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
  });

  final BoxDecoration background;
  final Color scrim;
  final Color incomingBubble;
  final Color outgoingBubble;
  final Color incomingText;
  final Color outgoingText;
  final Color border;
  final Color shadow;

  factory ChatContrastTheme.fromBackground(String? value) {
    final colors = switch (value) {
      'pubget://midnight' => const <Color>[
        Color(0xFF100B1A),
        Color(0xFF312056),
      ],
      'pubget://dawn' => const <Color>[Color(0xFFFFE6C7), Color(0xFFE7CBFF)],
      'pubget://forest' => const <Color>[Color(0xFF14352A), Color(0xFF2E6655)],
      _ => const <Color>[Color(0xFF4B258C), Color(0xFF171021)],
    };
    final average = Color.lerp(colors.first, colors.last, 0.5)!;
    final backgroundIsDark = average.computeLuminance() < 0.35;
    final incoming = backgroundIsDark
        ? const Color(0xEE241B30)
        : const Color(0xF7FFFFFF);
    final outgoing = backgroundIsDark
        ? const Color(0xF06C3FC5)
        : const Color(0xF0EDE5FF);
    return ChatContrastTheme(
      background: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      // Unknown/custom images receive this scrim before bubbles are drawn.
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
}

const pubgetChatBackgrounds = <(String?, String, List<Color>)>[
  (null, 'Pubget Royal', <Color>[Color(0xFF4B258C), Color(0xFF171021)]),
  (
    'pubget://midnight',
    'Midnight',
    <Color>[Color(0xFF100B1A), Color(0xFF312056)],
  ),
  ('pubget://dawn', 'Dawn', <Color>[Color(0xFFFFE6C7), Color(0xFFE7CBFF)]),
  ('pubget://forest', 'Forest', <Color>[Color(0xFF14352A), Color(0xFF2E6655)]),
];
