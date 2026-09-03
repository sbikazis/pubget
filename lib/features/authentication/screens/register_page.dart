import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/errors/result.dart';
import '../../../core/network/network_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../auth_validators.dart';
import '../providers/auth_draft_store.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_google_button.dart';
import '../widgets/auth_or_divider.dart';
import '../widgets/auth_password_field.dart';
import '../widgets/terms_copy.dart';
import 'auth_page_shell.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  late final TextEditingController _email;
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _confirmationError;
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
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final draft = context.watch<AuthDraftStore>();
    final network = context.watch<NetworkService>();
    final loading = auth.isBusy;
    final offline = network.isOffline;
    return AuthPageShell(
      title: 'Create your account',
      subtitle: 'Join Pubget. You can finish your profile after registration.',
      compactBrand: true,
      footer: PubgetTextButton(
        onPressed: loading ? null : () => AppNavigation.go(context, '/login'),
        semanticLabel: 'Return to sign in',
        child: const Text('Already have an account? Sign in'),
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (offline)
              const PubgetInlineBanner(
                title: 'You are offline',
                message: 'Reconnect before creating an account.',
                icon: Icons.cloud_off_outlined,
              )
            else if (auth.failure != null)
              PubgetInlineBanner.error(
                title: 'Registration failed',
                message: auth.failure!.message,
              ),
            if (offline || auth.failure != null)
              const SizedBox(height: AppSpacing.md),
            PubgetTextField(
              key: const Key('register-email'),
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              errorText: _emailError,
              enabled: !loading,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const <String>[AutofillHints.email],
              onChanged: (value) =>
                  context.read<AuthDraftStore>().setEmail(value),
            ),
            const SizedBox(height: AppSpacing.md),
            AuthPasswordField(
              key: const Key('register-password'),
              controller: _password,
              label: 'Password',
              errorText: _passwordError,
              enabled: !loading,
              showStrength: true,
              helperText: 'At least 6 characters.',
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
            ),
            const SizedBox(height: AppSpacing.md),
            AuthPasswordField(
              key: const Key('register-confirmation'),
              controller: _confirmation,
              label: 'Confirm password',
              errorText: _confirmationError,
              enabled: !loading,
              autofillHints: const <String>[AutofillHints.newPassword],
            ),
            const SizedBox(height: AppSpacing.sm),
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: draft.acceptedTerms,
                onChanged: loading
                    ? null
                    : (value) => draft.setAcceptedTerms(value ?? false),
                title: const Text('I agree to the terms'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: PubgetTextButton(
                onPressed: () => _openTerms(draft),
                semanticLabel: 'Read the terms',
                child: const Text('Read the terms'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PubgetPrimaryButton(
              key: const Key('register-submit'),
              onPressed: offline || loading ? null : _submit,
              semanticLabel: 'Create account with email',
              loading: loading,
              child: const Text('Create account'),
            ),
            const SizedBox(height: AppSpacing.lg),
            const AuthOrDivider(),
            const SizedBox(height: AppSpacing.lg),
            AuthGoogleButton(
              onPressed: offline || loading ? null : _google,
              semanticLabel: 'Create account with Google',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTerms(AuthDraftStore draft) async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height * 0.86;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              bottom:
                  MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.xl,
            ),
            child: SizedBox(
              height: height,
              child: SingleChildScrollView(
                child: TermsCopy(
                  onAccept: () => Navigator.of(sheetContext).pop(true),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (accepted == true) draft.setAcceptedTerms(true);
  }

  bool _validate() {
    setState(() {
      _emailError = AuthValidators.email(_email.text);
      _passwordError = AuthValidators.password(_password.text);
      _confirmationError = AuthValidators.confirmation(
        _password.text,
        _confirmation.text,
      );
    });
    if (!context.read<AuthDraftStore>().acceptedTerms) {
      PubgetSnackbars.showError(context, 'Accept the terms to continue.');
    }
    return _emailError == null &&
        _passwordError == null &&
        _confirmationError == null &&
        context.read<AuthDraftStore>().acceptedTerms;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    final result = await context.read<AuthProvider>().signUpWithEmail(
      email: AuthValidators.normalizeEmail(_email.text),
      password: _password.text,
    );
    if (!mounted) return;
    if (result is Success) await AppNavigation.go(context, '/splash');
  }

  Future<void> _google() async {
    if (!context.read<AuthDraftStore>().acceptedTerms) {
      PubgetSnackbars.showError(context, 'Accept the terms to continue.');
      return;
    }
    final result = await context.read<AuthProvider>().signInWithGoogle();
    if (!mounted) return;
    if (result is Success) await AppNavigation.go(context, '/splash');
  }
}
