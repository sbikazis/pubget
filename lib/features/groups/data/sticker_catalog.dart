import 'package:flutter/material.dart';

/// Original Pubget sticker set (CustomPaint). Not a third-party pack.
/// Swap these keys later if a licensed library is added.
const stickerCatalog = <StickerItem>[
  StickerItem(key: 'reactions/heart', category: 'Reactions', name: 'Heart'),
  StickerItem(key: 'reactions/laugh', category: 'Reactions', name: 'Laugh'),
  StickerItem(key: 'reactions/wow', category: 'Reactions', name: 'Wow'),
  StickerItem(key: 'reactions/sad', category: 'Reactions', name: 'Sad'),
  StickerItem(key: 'reactions/fire', category: 'Reactions', name: 'Fire'),
  StickerItem(key: 'gestures/wave', category: 'Gestures', name: 'Wave'),
  StickerItem(
    key: 'gestures/thumbsup',
    category: 'Gestures',
    name: 'Thumbs up',
  ),
  StickerItem(key: 'gestures/clap', category: 'Gestures', name: 'Clap'),
  StickerItem(key: 'gestures/bow', category: 'Gestures', name: 'Bow'),
  StickerItem(key: 'pubget/torii', category: 'Pubget', name: 'Torii'),
  StickerItem(key: 'pubget/spark', category: 'Pubget', name: 'Spark'),
  StickerItem(key: 'pubget/moon', category: 'Pubget', name: 'Moon'),
];

const stickerCategories = <String>[
  'Recent',
  'Favorites',
  'Reactions',
  'Gestures',
  'Pubget',
];

final class StickerItem {
  const StickerItem({
    required this.key,
    required this.category,
    required this.name,
  });

  final String key;
  final String category;
  final String name;
}

StickerItem? stickerByKey(String? key) {
  if (key == null) return null;
  for (final item in stickerCatalog) {
    if (item.key == key) return item;
  }
  return null;
}

class StickerMark extends StatelessWidget {
  const StickerMark({required this.stickerKey, this.size = 88, super.key});

  final String stickerKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: stickerByKey(stickerKey)?.name ?? 'Sticker',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _StickerPainter(stickerKey)),
      ),
    );
  }
}

class _StickerPainter extends CustomPainter {
  const _StickerPainter(this.keyName);

  final String keyName;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2.2;
    paint.color = switch (keyName) {
      'reactions/heart' => const Color(0xFFE85D75),
      'reactions/laugh' => const Color(0xFFF4C15D),
      'reactions/wow' => const Color(0xFF7C6BFF),
      'reactions/sad' => const Color(0xFF5C8DFF),
      'reactions/fire' => const Color(0xFFFF7A3C),
      'gestures/wave' => const Color(0xFF4EB7D8),
      'gestures/thumbsup' => const Color(0xFF6DCB91),
      'gestures/clap' => const Color(0xFFE06B86),
      'gestures/bow' => const Color(0xFFD8A838),
      'pubget/torii' => const Color(0xFFC23B4A),
      'pubget/spark' => const Color(0xFF9B75E8),
      _ => const Color(0xFF6B7C99),
    };
    canvas.drawCircle(center, radius, paint);
    final inner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.08
      ..strokeCap = StrokeCap.round;
    if (keyName == 'pubget/torii') {
      canvas.drawLine(
        Offset(center.dx - radius * 0.55, center.dy - radius * 0.15),
        Offset(center.dx + radius * 0.55, center.dy - radius * 0.15),
        inner,
      );
      canvas.drawLine(
        Offset(center.dx - radius * 0.35, center.dy - radius * 0.45),
        Offset(center.dx - radius * 0.35, center.dy + radius * 0.4),
        inner,
      );
      canvas.drawLine(
        Offset(center.dx + radius * 0.35, center.dy - radius * 0.45),
        Offset(center.dx + radius * 0.35, center.dy + radius * 0.4),
        inner,
      );
      return;
    }
    canvas.drawArc(
      Rect.fromCircle(
        center: center.translate(0, radius * 0.08),
        radius: radius * 0.45,
      ),
      0.2,
      2.7,
      false,
      inner,
    );
  }

  @override
  bool shouldRepaint(covariant _StickerPainter oldDelegate) =>
      oldDelegate.keyName != keyName;
}
