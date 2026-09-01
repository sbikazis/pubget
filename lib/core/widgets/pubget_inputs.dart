import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class PubgetTextField extends StatelessWidget {
  const PubgetTextField({
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.suffixIcon,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      textAlign: TextAlign.start,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        helperText: helperText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class PubgetTextArea extends StatelessWidget {
  const PubgetTextArea({
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.onChanged,
    this.enabled = true,
    this.minLines = 3,
    this.maxLines = 6,
    super.key,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return PubgetTextField(
      controller: controller,
      label: label,
      hint: hint,
      errorText: errorText,
      onChanged: onChanged,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
    );
  }
}

class PubgetSearchField extends StatelessWidget {
  const PubgetSearchField({
    this.controller,
    this.hint,
    this.onChanged,
    this.onClear,
    this.enabled = true,
    super.key,
  });

  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return PubgetTextField(
      controller: controller,
      hint: hint,
      onChanged: onChanged,
      enabled: enabled,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.search,
      prefixIcon: const Icon(Icons.search),
      suffixIcon: onClear == null
          ? null
          : IconButton(
              onPressed: enabled ? onClear : null,
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              icon: const Icon(Icons.clear),
            ),
    );
  }
}

class PubgetFieldGroup extends StatelessWidget {
  const PubgetFieldGroup({
    required this.label,
    required this.child,
    this.description,
    super.key,
  });

  final String label;
  final Widget child;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label, style: textTheme.titleSmall),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(description!, style: textTheme.bodySmall),
        ],
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}
