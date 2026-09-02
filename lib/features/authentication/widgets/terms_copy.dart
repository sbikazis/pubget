import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';

class TermsCopy extends StatelessWidget {
  const TermsCopy({this.onAccept, super.key});

  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'These are draft community terms. Final legal copy and a privacy '
          'policy will replace this text before public launch.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        const _TermsSection(
          title: 'Your account',
          body:
              'Keep your sign-in details private. You are responsible for '
              'activity on your Pubget account. If you think someone else '
              'used it, reset your password and contact support.',
        ),
        const _TermsSection(
          title: 'The community',
          body:
              'Pubget is for respectful anime conversation, groups, and '
              'events. Do not harass others, share illegal content, or '
              'impersonate people or brands.',
        ),
        const _TermsSection(
          title: 'Your content',
          body:
              'You keep ownership of what you post. By posting, you let '
              'Pubget display that content inside the product so other '
              'members can see it according to your privacy settings.',
        ),
        const _TermsSection(
          title: 'Privacy',
          body:
              'We store the profile details you choose to share, plus the '
              'minimum account data needed to sign you in. A complete '
              'privacy policy will be published before launch.',
        ),
        if (onAccept != null) ...[
          const SizedBox(height: AppSpacing.lg),
          PubgetPrimaryButton(
            onPressed: onAccept,
            semanticLabel: 'Agree to the terms',
            child: const Text('I agree'),
          ),
        ],
      ],
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
