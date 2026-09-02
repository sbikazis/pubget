import 'package:flutter/material.dart';

/// Shared motion used across Pubget surfaces.
abstract final class AppMotion {
  static const instant = Duration(milliseconds: 120);
  static const fast = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 480);

  static const curve = Curves.easeOutCubic;
}
