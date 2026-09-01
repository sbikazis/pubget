import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import 'auth_google_mark.dart';

class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({
    required this.onPressed,
    required this.semanticLabel,
    this.label = 'Continue with Google',
    super.key,
  });

  final VoidCallback? onPressed;
  final String semanticLabel;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PubgetSecondaryButton(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const AuthGoogleMark(),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}
