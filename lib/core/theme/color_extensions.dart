import 'package:flutter/material.dart';

extension ColorWithValues on Color {
  /// Lightweight compatibility wrapper used across the codebase.
  /// Maps `withValues(alpha: x)` to the standard `withAlpha` API.
  Color withValues({required double alpha}) => withAlpha((alpha * 255).round());
}
