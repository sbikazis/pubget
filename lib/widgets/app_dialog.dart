import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_theme.dart';
import 'app_button.dart';

/// A reusable dialog widget for Pubget
class AppDialog extends StatelessWidget {
  final String? title;
  final String? content;
  final String confirmText;
  final VoidCallback? onConfirm;
  final String? cancelText;
  final VoidCallback? onCancel;
  final bool isLoading;
  final bool barrierDismissible;

  const AppDialog({
    super.key,
    this.title,
    this.content,
    required this.confirmText,
    this.onConfirm,
    this.cancelText,
    this.onCancel,
    this.isLoading = false,
    this.barrierDismissible = true,
  });

  /// Show the dialog easily from anywhere
  static Future<void> show(
    BuildContext context, {
    String? title,
    String? content,
    required String confirmText,
    VoidCallback? onConfirm,
    String? cancelText,
    VoidCallback? onCancel,
    bool isLoading = false,
    bool barrierDismissible = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AppDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        onConfirm: onConfirm,
        cancelText: cancelText,
        onCancel: onCancel,
        isLoading: isLoading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Text(
                title!,
                style: isDark
                    ? AppTextTheme.darkTextTheme.headlineLarge
                    : AppTextTheme.lightTextTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
            if (content != null) ...[
              const SizedBox(height: 12),
              Text(
                content!,
                style: isDark
                    ? AppTextTheme.darkTextTheme.bodyLarge
                    : AppTextTheme.lightTextTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (cancelText != null && onCancel != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: AppButton(
                      text: cancelText!,
                      onPressed: onCancel,
                      expand: false,
                    ),
                  ),
                AppButton(
                  text: confirmText,
                  onPressed: onConfirm,
                  isLoading: isLoading,
                  expand: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}