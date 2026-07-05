import 'package:flutter/material.dart';

extension ColorWithValues on Color {
  /// Lightweight compatibility wrapper used across the codebase.
  /// Maps `withValues(alpha: x)` to the standard `withOpacity(x)`.
  Color withValues({required double alpha}) => withOpacity(alpha);
}
