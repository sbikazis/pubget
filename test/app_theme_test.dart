import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/theme/app_colors.dart';
import 'package:pubget/core/theme/app_theme.dart';

void main() {
  test('themes expose the Pubget palette for both brightness modes', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.light.colorScheme.primary, AppColors.royalPurple);
    expect(AppTheme.dark.colorScheme.primary, AppColors.royalPurpleLight);
    expect(AppTheme.light.colorScheme.secondary, AppColors.gold);
    expect(AppTheme.dark.colorScheme.secondary, AppColors.goldLight);
  });

  test('typography keeps readable body metrics', () {
    final lightBody = AppTheme.light.textTheme.bodyLarge;
    final darkBody = AppTheme.dark.textTheme.bodyLarge;

    expect(lightBody?.fontSize, 16);
    expect(lightBody?.height, greaterThanOrEqualTo(1.4));
    expect(darkBody?.fontSize, lightBody?.fontSize);
    expect(darkBody?.height, lightBody?.height);
  });

  test('primary and showcase color pairs meet normal-text AA contrast', () {
    for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      final scheme = theme.colorScheme;
      expect(
        _contrastRatio(scheme.primary, scheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(scheme.primaryContainer, scheme.onPrimaryContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          scheme.surfaceContainerHighest,
          scheme.onPrimaryContainer,
        ),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
