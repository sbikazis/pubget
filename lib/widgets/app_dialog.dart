// lib/widgets/app_dialog.dart
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_theme.dart';
import 'app_button.dart';
import 'app_textfield.dart';
import 'package:pubget/widgets/shiny_coin_widget.dart';
import 'package:pubget/features/store/screens/store_screen.dart';

class AppDialog extends StatelessWidget {
  final String? title;
  final String? content;
  final String confirmText;
  final VoidCallback? onConfirm;
  final String? cancelText;
  final VoidCallback? onCancel;
  final bool isLoading;
  final bool barrierDismissible;
  final Widget? extraContent;
  final Widget? icon;

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
    this.icon,
  });

  /// ديالوج عام
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

  /// ديالوج مع حقل نصي
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

  /// ديالوج تجاوز الحد — يوجّه للمتجر لشراء توسعة
  static Future<void> showLimitReachedDialog(
    BuildContext context, {
    String? customTitle,
    String? customContent,
    bool isLimitExceeded = true,
  }) {
    return showDialog(
      context: context,
      builder: (dialogContext) {
        return AppDialog(
          title: customTitle ??
              (isLimitExceeded
                  ? '⚠️ تخطي قفل المجال التقني'
                  : '💎 رصيد عملات غير كافٍ'),
          content: customContent ??
              (isLimitExceeded
                  ? 'لقد وصلت للحد المسموح به في نسختك الحالية. تفضل بزيارة المتجر لتوسيع المجال ورفع القيود!'
                  : 'لا تملك رصيداً كافياً من العملات المشعة لإتمام هذه العملية. توجه لشحن العملات الآن!'),
          confirmText: isLimitExceeded ? 'زيارة المتجر' : 'شحن العملات',
          icon: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLimitExceeded
                  ? Colors.amber.withOpacity(0.1)
                  : const Color(0xFFB800FF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: isLimitExceeded
                ? const Icon(Icons.gpp_maybe_rounded,
                    color: Colors.amber, size: 40)
                : const ShinyCoinWidget(size: 40),
          ),
          onConfirm: () {
            Navigator.pop(dialogContext);
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const StoreScreen(),
            );
          },
          cancelText: 'ربما لاحقاً',
        );
      },
    );
  }

  /// ✅ ديالوج جديد: وصل للحد الأقصى النهائي — لا يوجد ما يُشترى
  static Future<void> showMaxLimitDialog(
    BuildContext context, {
    String? customContent,
  }) {
    return showDialog(
      context: context,
      builder: (dialogContext) {
        return AppDialog(
          title: '🚧 الحد الأقصى النهائي',
          content: customContent ??
              'لقد وصلت للحد الأقصى المتاح. لا توجد توسعات إضافية متاحة حالياً.',
          confirmText: 'حسناً',
          icon: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.block_rounded,
              color: Colors.redAccent,
              size: 40,
            ),
          ),
          onConfirm: () => Navigator.pop(dialogContext),
          // ✅ لا cancelText — زر واحد فقط "حسناً"
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      surfaceTintColor: Colors.transparent,
      elevation: isDark ? 8 : 2,
      shadowColor:
          isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black26,
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: isDark
            ? BorderSide(
                color: AppColors.primary.withValues(alpha: 0.15), width: 0.8)
            : BorderSide.none,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) icon!,
              if (title != null)
                Text(
                  title!,
                  style: (isDark
                          ? AppTextTheme.darkTextTheme.headlineLarge
                          : AppTextTheme.lightTextTheme.headlineLarge)
                      ?.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
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
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.5,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (extraContent != null) extraContent!,
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (cancelText != null)
                    Flexible(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4.0),
                        child: AppButton(
                          text: cancelText!,
                          onPressed:
                              onCancel ?? () => Navigator.pop(context),
                          expand: true,
                        ),
                      ),
                    ),
                  Flexible(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4.0),
                      child: AppButton(
                        text: confirmText,
                        onPressed: onConfirm,
                        isLoading: isLoading,
                        expand: true,
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
