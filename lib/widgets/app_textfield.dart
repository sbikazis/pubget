import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

typedef Validator = String? Function(String? value);

class AppTextField extends StatefulWidget {
  final String? label;
  final String? placeholder;
  final bool isPassword;
  final bool isMultiline;
  final TextEditingController? controller;
  final Validator? validator;
  final int? maxLength;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final void Function(String)? onChanged;

  const AppTextField({
    Key? key,
    this.label,
    this.placeholder,
    this.isPassword = false,
    this.isMultiline = false,
    this.controller,
    this.validator,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
  }) : super(key: key);

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.brightness == Brightness.dark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    final hintColor = theme.brightness == Brightness.dark
        ? AppColors.textHintDark
        : AppColors.textHintLight;

    final borderColor = theme.brightness == Brightness.dark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Text(
              widget.label!,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.isPassword ? _obscureText : false,
          maxLines: widget.isMultiline ? null : 1,
          maxLength: widget.maxLength,
          validator: widget.validator,
          onChanged: widget.onChanged,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            prefixIcon:
                widget.prefixIcon != null ? Icon(widget.prefixIcon, color: hintColor) : null,
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                        color: hintColor),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  )
                : (widget.suffixIcon != null ? Icon(widget.suffixIcon, color: hintColor) : null),
            hintText: widget.placeholder,
            hintStyle: TextStyle(color: hintColor),
            filled: true,
            fillColor: theme.brightness == Brightness.dark
                ? AppColors.darkCard
                : AppColors.lightCard,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.error),
            ),
            counterText: '',
          ),
        ),
      ],
    );
  }
}