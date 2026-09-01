import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import 'auth_page_shell.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      title: 'Terms of use',
      subtitle: 'A clear summary before you create your account.',
      leading: PubgetIconButton(
        icon: Icons.arrow_back,
        tooltip: 'Back to registration',
        onPressed: () => AppNavigation.go(context, '/register'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'This temporary text explains that Pubget accounts must be used '
            'respectfully and lawfully. The final legal terms and privacy '
            'policy will replace this placeholder before public launch.',
          ),
          const SizedBox(height: AppSpacing.xl),
          PubgetPrimaryButton(
            onPressed: () => AppNavigation.go(context, '/register'),
            semanticLabel: 'Return to registration',
            child: const Text('Back to registration'),
          ),
        ],
      ),
    );
  }
}
