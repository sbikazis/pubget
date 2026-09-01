import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/network/network_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../auth_validators.dart';
import '../providers/auth_draft_store.dart';
import '../providers/auth_provider.dart';
import 'auth_page_shell.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final TextEditingController _email;
  String? _emailError;
  var _sent = false;
  var _seededEmail = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededEmail) return;
    _seededEmail = true;
    final draft = context.read<AuthDraftStore>().email;
    if (_email.text.isEmpty && draft.isNotEmpty) {
      _email.text = draft;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final network = context.watch<NetworkService>();
    final sending = auth.isResetting;
    final offline = network.isOffline;
    return AuthPageShell(
      title: _sent ? 'Check your email' : 'Reset your password',
      subtitle: _sent
          ? 'If an account exists for that address, a reset link is on its way.'
          : 'Enter the email you use for Pubget. We will send a reset link.',
      leading: AuthBackButton(
        onPressed: () => AppNavigation.go(context, '/login'),
        tooltip: 'Back to sign in',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_sent) ...[
            const Icon(Icons.mark_email_read_outlined, size: 48),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AuthValidators.normalizeEmail(_email.text),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            PubgetPrimaryButton(
              onPressed: () => AppNavigation.go(context, '/login'),
              semanticLabel: 'Return to sign in',
              child: const Text('Back to sign in'),
            ),
          ] else ...[
            if (offline)
              const PubgetInlineBanner(
                title: 'You are offline',
                message: 'Reconnect to send a reset link.',
                icon: Icons.cloud_off_outlined,
              ),
            if (offline) const SizedBox(height: AppSpacing.md),
            PubgetTextField(
              key: const Key('forgot-email'),
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              errorText: _emailError,
              enabled: !sending,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const <String>[AutofillHints.email],
              onSubmitted: (_) => _submit(),
              onChanged: (value) =>
                  context.read<AuthDraftStore>().setEmail(value),
            ),
            const SizedBox(height: AppSpacing.lg),
            PubgetPrimaryButton(
              key: const Key('forgot-submit'),
              onPressed: offline || sending ? null : _submit,
              semanticLabel: 'Send password reset email',
              loading: sending,
              child: const Text('Send reset link'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final error = AuthValidators.email(_email.text);
    setState(() => _emailError = error);
    if (error != null) return;
    final email = AuthValidators.normalizeEmail(_email.text);
    final result = await context.read<AuthProvider>().sendPasswordResetEmail(
      email: email,
    );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => setState(() => _sent = true),
      onFailure: (failure) =>
          PubgetSnackbars.showError(context, failure.message),
    );
  }
}
