// lib/widgets/app_dialog.dart
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_theme.dart';
import 'app_button.dart';
import 'app_textfield.dart'; 
import 'package:pubget/widgets/shiny_coin_widget.dart';
import 'package:pubget/features/store/screens/store_screen.dart';

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
  final Widget? extraContent; 
  final Widget? icon; // إضافة دعم الأيقونات العلوية الفخمة

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

  /// ✅ إظهار ديالوج مع حقل نصي
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

  /// ✅ التطوير الشامل: إظهار ديالوج الوصول للحدود ونقص العملات والتوجيه للمتجر
  /// [isLimitExceeded] يحدد ما إذا كان التنبيه بسبب قفل المجال (true) أو نقص رصيد العملات (false)
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
          title: customTitle ?? (isLimitExceeded ? "⚠️ تخطي قفل المجال التقني" : "💎 رصيد عملات غير كافٍ"),
          content: customContent ?? (isLimitExceeded 
              ? "لقد وصلت للحد المسموح به في نسختك الحالية. تفضل بزيارة المتجر لتوسيع المجال ورفع القيود!"
              : "لا تملك رصيداً كافياً من العملات المشعة لإتمام هذه العملية. توجه لشحن العملات الآن!"),
          confirmText: isLimitExceeded ? "زيارة المتجر" : "شحن العملات",
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
                ? const Icon(Icons.gpp_maybe_rounded, color: Colors.amber, size: 40)
                : const ShinyCoinWidget(size: 40),
          ),
          onConfirm: () {
            // 1. إغلاق الديالوج
            Navigator.pop(dialogContext); 
            
            // 2. التوجيه الذكي إلى صفحة المتجر الشاملة (أو صفحة كسب العملات)
            // سيتم استخدام هذا المسار الموحد عند بناء واجهة المتجر في المرحلة القادمة
            showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const StoreScreen(),
          );
          },
          cancelText: "ربما لاحقاً",
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
      shadowColor: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black26,
      backgroundColor: isDark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24), // تعديل الحواف لتصبح ناعمة ومتناسقة
        side: isDark 
            ? BorderSide(color: AppColors.primary.withValues(alpha: 0.15), width: 0.8)
            : BorderSide.none,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // عرض الأيقونة العلوية البراقة إن وجدت
              if (icon != null) icon!,
              
              if (title != null)
                Text(
                  title!,
                  style: (isDark
                          ? AppTextTheme.darkTextTheme.headlineLarge
                          : AppTextTheme.lightTextTheme.headlineLarge)
                      ?.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
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
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: AppButton(
                          text: cancelText!,
                          onPressed: onCancel ?? () => Navigator.pop(context),
                          expand: true, // تفعيل التمدد المتناسق داخل السطر
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