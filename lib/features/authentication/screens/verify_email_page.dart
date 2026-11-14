import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/errors/result.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../providers/auth_provider.dart';
import 'auth_page_shell.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _sending = false;
  bool _checking = false;
  String? _message;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final busy = _sending || _checking;
    return AuthPageShell(
      title: copy.verifyEmailTitle,
      subtitle: copy.verifyEmailSubtitle(user?.email ?? ''),
      compactBrand: true,
      footer: PubgetTextButton(
        onPressed: busy ? null : _signOut,
        semanticLabel: copy.signOut,
        child: Text(copy.signOut),
      ),
      primaryAction: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PubgetPrimaryButton(
            key: const Key('verify-email-check'),
            onPressed: busy ? null : _checkVerification,
            loading: _checking,
            semanticLabel: copy.checkVerification,
            child: Text(copy.checkVerification),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetTextButton(
            key: const Key('verify-email-resend'),
            onPressed: busy ? null : _resend,
            semanticLabel: copy.resendVerification,
            child: Text(copy.resendVerification),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (user?.email.isNotEmpty == true)
            SelectableText(
              user!.email,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          const SizedBox(height: AppSpacing.md),
          if (_message != null)
            PubgetInlineBanner(
              title: copy.checkYourEmail,
              message: _message!,
              icon: Icons.mark_email_read_outlined,
            ),
          if (_error != null)
            PubgetInlineBanner.error(
              title: copy.registrationFailed,
              message: _error!,
            ),
          if (_message == null && _error == null)
            PubgetInlineBanner(
              title: copy.checkYourEmail,
              message: copy.verificationNotConfirmed,
              icon: Icons.mark_email_unread_outlined,
            ),
        ],
      ),
    );
  }

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _error = null;
      _message = null;
    });
    final result = await context.read<AuthProvider>().sendEmailVerification();
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    if (result is Success) {
      setState(() => _message = AppStrings.of(context).verificationSent);
    } else {
      setState(() => _error = result.failureOrNull?.message);
    }
  }

  Future<void> _checkVerification() async {
    setState(() {
      _checking = true;
      _error = null;
      _message = null;
    });
    final result = await context.read<AuthProvider>().reloadCurrentUser();
    if (!mounted) return;
    setState(() => _checking = false);
    if (result is Success && result.valueOrNull?.emailVerified == true) {
      await AppNavigation.go(context, '/splash');
      return;
    }
    setState(() {
      _message = AppStrings.of(context).verificationNotConfirmed;
      _error = result.failureOrNull?.message;
    });
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    await AppNavigation.go(context, '/login');
  }
}
