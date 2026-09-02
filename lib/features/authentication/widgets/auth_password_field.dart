import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../auth_validators.dart';

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    required this.controller,
    required this.label,
    this.errorText,
    this.enabled = true,
    this.onSubmitted,
    this.onChanged,
    this.textInputAction = TextInputAction.done,
    this.autofillHints = const <String>[AutofillHints.password],
    this.showStrength = false,
    this.helperText,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final bool showStrength;
  final String? helperText;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final strength = AuthValidators.passwordStrength(widget.controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PubgetTextField(
          controller: widget.controller,
          label: widget.label,
          obscureText: _hidden,
          errorText: widget.errorText,
          helperText: widget.helperText,
          enabled: widget.enabled,
          textInputAction: widget.textInputAction,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: widget.autofillHints,
          onSubmitted: widget.onSubmitted,
          onChanged: (value) {
            setState(() {});
            widget.onChanged?.call(value);
          },
          suffixIcon: PubgetIconButton(
            icon: _hidden
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            tooltip: _hidden ? 'Show password' : 'Hide password',
            onPressed: widget.enabled
                ? () => setState(() => _hidden = !_hidden)
                : null,
          ),
        ),
        if (widget.showStrength && widget.controller.text.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _PasswordStrengthMeter(strength: strength),
        ],
      ],
    );
  }
}

class _PasswordStrengthMeter extends StatelessWidget {
  const _PasswordStrengthMeter({required this.strength});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final filled = switch (strength) {
      PasswordStrength.empty => 0,
      PasswordStrength.short => 1,
      PasswordStrength.fair => 2,
      PasswordStrength.strong => 3,
    };
    final label = switch (strength) {
      PasswordStrength.empty => '',
      PasswordStrength.short => 'Too short',
      PasswordStrength.fair => 'Good',
      PasswordStrength.strong => 'Strong',
    };
    final color = switch (strength) {
      PasswordStrength.empty => AppColors.lightOutline,
      PasswordStrength.short => AppColors.warning,
      PasswordStrength.fair => AppColors.gold,
      PasswordStrength.strong => AppColors.success,
    };
    return Row(
      children: <Widget>[
        for (var i = 0; i < 3; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 4,
              decoration: BoxDecoration(
                color: i < filled
                    ? color
                    : AppColors.lightOutline.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          if (i < 2) const SizedBox(width: AppSpacing.xs),
        ],
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
