import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class PubgetConfirmationDialog extends StatelessWidget {
  const PubgetConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String? cancelLabel;

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String? cancelLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => PubgetConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actions: <Widget>[
        if (cancelLabel != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel!),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

class PubgetAlertDialog extends StatelessWidget {
  const PubgetAlertDialog({
    required this.title,
    required this.message,
    required this.closeLabel,
    this.icon,
    super.key,
  });

  final String title;
  final String message;
  final String closeLabel;
  final IconData? icon;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    required String closeLabel,
    IconData? icon,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => PubgetAlertDialog(
        title: title,
        message: message,
        closeLabel: closeLabel,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: icon == null ? null : Icon(icon, color: scheme.primary),
      title: Text(title),
      content: Text(message),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(closeLabel),
        ),
      ],
    );
  }
}
