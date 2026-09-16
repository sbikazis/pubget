import 'package:flutter/material.dart';

import '../../../core/branding/pubget_logo.dart';

/// Official torii mark. The painted fallback stays for tests that do not
/// load assets, but product chrome uses [PubgetLogoMark].
class PubgetToriiMark extends StatelessWidget {
  const PubgetToriiMark({
    this.size = 72,
    this.color,
    this.accentColor,
    super.key,
  });

  final double size;
  final Color? color;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return PubgetLogoMark(size: size, semanticLabel: 'Pubget torii gate');
  }
}
