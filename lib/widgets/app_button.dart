import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;

    final button = ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor:
            isDisabled ? AppColors.disabled : AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.disabled,
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 20,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: _buildContent(),
    );

    // ✅ التعديل المعتمد: استخدام ConstrainedBox بدلاً من SizedBox العادي
    // هذا يسمح للزر بالتمدد فقط في حدود ما يسمح به الأب (Parent Constraints)
    // ويمنع حدوث خطأ Infinite Width داخل الـ Rows
    if (expand) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: double.infinity),
        child: button,
      );
    }

    return button;
  }

  Widget _buildContent() {
    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min, // أضفنا هذا لضمان عدم تمدد الـ Row داخلياً للمالانهاية
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}