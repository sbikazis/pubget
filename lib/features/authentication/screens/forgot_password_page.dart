import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
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
    final copy = AppStrings.of(context);
    final sending = auth.isResetting;
    final offline = network.isOffline;
    return AuthPageShell(
      title: _sent ? copy.checkYourEmail : copy.resetPassword,
      subtitle: _sent ? copy.resetLinkOnTheWay : copy.resetPasswordSubtitle,
      leading: AuthBackButton(
        onPressed: () => AppNavigation.back(context),
        tooltip: copy.backToSignIn,
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
              semanticLabel: copy.returnToSignIn,
              child: Text(copy.backToSignIn),
            ),
          ] else ...[
            if (offline)
              PubgetInlineBanner(
                title: copy.youAreOffline,
                message: copy.reconnectToReset,
                icon: Icons.cloud_off_outlined,
              ),
            if (offline) const SizedBox(height: AppSpacing.md),
            PubgetTextField(
              key: const Key('forgot-email'),
              controller: _email,
              label: copy.email,
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
              semanticLabel: copy.sendPasswordResetEmail,
              loading: sending,
              child: Text(copy.sendResetLink),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final error = AuthValidators.email(_email.text, AppStrings.of(context));
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
