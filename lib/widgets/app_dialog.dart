import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_theme.dart';
import 'app_button.dart';
import 'app_textfield.dart'; // تأكد من استيراد حقل النص الخاص بك

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
  final Widget? extraContent; // حقل إضافي للمحتوى المخصص مثل TextField

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
    this.extraContent,
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

  /// ✅ ميزة مضافة: إظهار ديالوج مع حقل نصي (TextField) لرسائل الوداع أو غيرها
  static Future<void> showWithTextField(
    BuildContext context, {
    String? title,
    String? content,
    required String confirmText,
    required TextEditingController controller,
    String? placeholder,
    required VoidCallback onConfirm,
    String? cancelText,
    VoidCallback? onCancel,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AppDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        onConfirm: onConfirm,
        cancelText: cancelText,
        onCancel: onCancel ?? () => Navigator.pop(context),
        extraContent: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: AppTextField(
            controller: controller,
            label: placeholder ?? '',
            placeholder: placeholder ?? '',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      surfaceTintColor: Colors.transparent,
      elevation: isDark ? 8 : 2,
      shadowColor: isDark ? Colors.black.withOpacity(0.5) : Colors.black26,
      backgroundColor: isDark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDark 
            ? BorderSide(color: AppColors.primary.withOpacity(0.15), width: 0.8)
            : BorderSide.none,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Text(
                  title!,
                  style: (isDark
                          ? AppTextTheme.darkTextTheme.headlineLarge
                          : AppTextTheme.lightTextTheme.headlineLarge)
                      ?.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20, 
                  ),
                  textAlign: TextAlign.center,
                ),
              if (content != null) ...[
                const SizedBox(height: 12),
                Text(
                  content!,
                  style: (isDark
                          ? AppTextTheme.darkTextTheme.bodyLarge
                          : AppTextTheme.lightTextTheme.bodyLarge)
                      ?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    height: 1.5, 
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              // ✅ عرض المحتوى الإضافي (مثل TextField) إن وجد
              if (extraContent != null) extraContent!,

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (cancelText != null)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: AppButton(
                          text: cancelText!,
                          onPressed: onCancel ?? () => Navigator.pop(context),
                          expand: false,
                        ),
                      ),
                    ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: AppButton(
                        text: confirmText,
                        onPressed: onConfirm,
                        isLoading: isLoading,
                        expand: false,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}