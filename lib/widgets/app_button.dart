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
    final bool isDisabled =
        onPressed == null || isLoading;

    final Widget button = ElevatedButton(
      onPressed: isDisabled ? null : onPressed,

      style: ElevatedButton.styleFrom(
        elevation: 0,

        backgroundColor: isDisabled
            ? AppColors.disabled
            : AppColors.primary,

        foregroundColor: Colors.white,

        disabledBackgroundColor:
            AppColors.disabled,

        disabledForegroundColor:
            Colors.white70,

        // ✅ إصلاح مشاكل الـ constraints
        // ومنع الـ infinite width conflicts
        minimumSize: const Size(0, 50),

        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 20,
        ),

        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),

        tapTargetSize:
            MaterialTapTargetSize.shrinkWrap,
      ),

      child: _buildContent(),
    );

    // ✅ الإصلاح الحقيقي
    // عدم استخدام ConstrainedBox مع infinity
    // لأنه يسبب انهيارات Layout داخل Row
    if (expand) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }

  Widget _buildContent() {
    // =========================
    // LOADING STATE
    // =========================
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

    // =========================
    // BUTTON WITH ICON
    // =========================
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [
          Icon(
            icon,
            size: 20,
          ),

          const SizedBox(width: 8),

          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,

              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    // =========================
    // TEXT ONLY BUTTON
    // =========================
    return Text(
      text,
      overflow: TextOverflow.ellipsis,

      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}