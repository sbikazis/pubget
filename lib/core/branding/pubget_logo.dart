import 'package:flutter/material.dart';

/// Official Pubget torii mark (user-supplied brand asset).
abstract final class PubgetLogo {
  static const asset = 'assets/branding/pubget_torii.png';
}

class PubgetLogoMark extends StatelessWidget {
  const PubgetLogoMark({
    this.size = 40,
    this.semanticLabel = 'Pubget',
    super.key,
  });

  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Image.asset(
        PubgetLogo.asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => Icon(
          Icons.temple_buddhist,
          size: size * 0.86,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}
