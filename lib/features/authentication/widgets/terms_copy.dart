import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';

class TermsCopy extends StatelessWidget {
  const TermsCopy({this.onAccept, super.key});

  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(copy.termsIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        _TermsSection(title: copy.termsAccountTitle, body: copy.termsAccountBody),
        _TermsSection(
          title: copy.termsCommunityTitle,
          body: copy.termsCommunityBody,
        ),
        _TermsSection(title: copy.termsContentTitle, body: copy.termsContentBody),
        _TermsSection(title: copy.termsPrivacyTitle, body: copy.termsPrivacyBody),
        if (onAccept != null) ...[
          const SizedBox(height: AppSpacing.lg),
          PubgetPrimaryButton(
            onPressed: onAccept,
            semanticLabel: copy.agreeToTheTerms,
            child: Text(copy.iAgree),
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
