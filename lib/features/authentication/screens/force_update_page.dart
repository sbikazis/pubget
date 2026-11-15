import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app/app_version_gate.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';

class ForceUpdatePage extends StatelessWidget {
  const ForceUpdatePage({required this.status, super.key});

  final AppVersionStatus status;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Icon(
                      Icons.system_update_rounded,
                      size: 76,
                      color: colors.primary,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      copy.forceUpdateTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      copy.forceUpdateMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (status.updateUrl.isEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      PubgetInlineBanner.error(
                        title: copy.forceUpdateTitle,
                        message: copy.updateLinkUnavailable,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    PubgetPrimaryButton(
                      onPressed: status.updateUrl.isEmpty
                          ? null
                          : () => _openUpdate(context),
                      semanticLabel: copy.updateNow,
                      child: Text(copy.updateNow),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${status.currentVersion} → ${status.minimumVersion}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUpdate(BuildContext context) async {
    final uri = Uri.tryParse(status.updateUrl);
    if (uri == null || !await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      if (context.mounted) {
        PubgetSnackbars.showError(
          context,
          AppStrings.of(context).updateLinkUnavailable,
        );
      }
    }
  }
}
