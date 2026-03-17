import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';

class ThemeSelectorWidget extends StatelessWidget {
  const ThemeSelectorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final bool isDark = settings.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Theme",
          style: Theme.of(context).textTheme.titleMedium,
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _ThemeOption(
                title: "Light",
                icon: Icons.light_mode,
                selected: !isDark,
                onTap: () {
                  settings.setDarkMode(false);
                },
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _ThemeOption(
                title: "Dark",
                icon: Icons.dark_mode,
                selected: isDark,
                onTap: () {
                  settings.setDarkMode(true);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? AppColors.primary : Theme.of(context).dividerColor;

    final backgroundColor = selected
        ? AppColors.primary.withOpacity(0.08)
        : Theme.of(context).cardColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 26,
              color: selected
                  ? AppColors.primary
                  : Theme.of(context).iconTheme.color,
            ),

            const SizedBox(height: 6),

            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.primary
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
