import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../settings_provider.dart';
import '../settings_store.dart';

/// Compact login-bar control and the Settings language radios share one source:
/// [SettingsProvider.setLocaleOption].
class AuthLanguagePicker extends StatelessWidget {
  const AuthLanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final copy = AppStrings.of(context);
    final selected = copy.isArabic
        ? AppLocaleOption.arabic
        : AppLocaleOption.english;
    return Semantics(
      label: copy.chooseLanguage,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.royalNight.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: AppColors.goldSheen.withValues(alpha: 0.45),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _LanguageChip(
                key: const Key('auth-language-arabic'),
                label: copy.languageArabic,
                selected: selected == AppLocaleOption.arabic,
                onTap: () => settings.setLocaleOption(AppLocaleOption.arabic),
              ),
              _LanguageChip(
                key: const Key('auth-language-english'),
                label: copy.languageEnglish,
                selected: selected == AppLocaleOption.english,
                onTap: () => settings.setLocaleOption(AppLocaleOption.english),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsLanguageRadios extends StatelessWidget {
  const SettingsLanguageRadios({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final copy = AppStrings.of(context);
    return Column(
      children: <Widget>[
        for (final option in AppLocaleOption.values)
          RadioListTile<AppLocaleOption>(
            key: Key('settings-language-${option.name}'),
            contentPadding: EdgeInsets.zero,
            title: Text(_label(copy, option)),
            value: option,
            groupValue: settings.localeOption,
            onChanged: (value) {
              if (value != null) settings.setLocaleOption(value);
            },
          ),
      ],
    );
  }

  static String _label(AppStrings copy, AppLocaleOption option) =>
      switch (option) {
        AppLocaleOption.system => copy.languageSystem,
        AppLocaleOption.english => copy.languageEnglish,
        AppLocaleOption.arabic => copy.languageArabic,
      };
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.goldSheen : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? AppColors.royalNight : AppColors.goldPale,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
