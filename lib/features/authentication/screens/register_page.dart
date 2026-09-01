import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/network/network_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../providers/auth_provider.dart';
import 'auth_page_shell.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _confirmationError;
  bool _acceptedTerms = false;
  bool _hidePassword = true;

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
    final network = context.watch<NetworkService>();
    final loading = auth.state == LoadingState.loading;
    return AuthPageShell(
      title: 'Create your account',
      subtitle: 'Start quickly. You can finish your profile later.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!network.isOnline)
            const PubgetOfflineState(
              title: 'You are offline',
              message: 'Reconnect before creating an account.',
            )
          else if (auth.failure != null)
            PubgetErrorState(
              title: 'Registration failed',
              message: auth.failure!.message,
            ),
          PubgetTextField(
            key: const Key('register-email'),
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            errorText: _emailError,
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            key: const Key('register-password'),
            controller: _password,
            label: 'Password',
            obscureText: _hidePassword,
            errorText: _passwordError,
            enabled: !loading,
            suffixIcon: PubgetIconButton(
              icon: _hidePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              tooltip: _hidePassword ? 'Show password' : 'Hide password',
              onPressed: loading
                  ? null
                  : () => setState(() => _hidePassword = !_hidePassword),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            key: const Key('register-confirmation'),
            controller: _confirmation,
            label: 'Confirm password',
            obscureText: true,
            errorText: _confirmationError,
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.sm),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _acceptedTerms,
            onChanged: loading
                ? null
                : (value) => setState(() => _acceptedTerms = value ?? false),
            title: const Text('I agree to the terms'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          PubgetTextButton(
            onPressed: () => AppNavigation.go(context, '/terms'),
            semanticLabel: 'Read the terms',
            child: const Text('Read the terms'),
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetPrimaryButton(
            key: const Key('register-submit'),
            onPressed: !network.isOnline || loading ? null : _submit,
            semanticLabel: 'Create account with email',
            loading: loading,
            child: const Text('Create account'),
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetSecondaryButton(
            onPressed: !network.isOnline || loading ? null : _google,
            semanticLabel: 'Create account with Google',
            leadingIcon: Icons.account_circle_outlined,
            child: const Text('Continue with Google'),
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextButton(
            onPressed: loading
                ? null
                : () => AppNavigation.go(context, '/login'),
            semanticLabel: 'Return to sign in',
            child: const Text('Already have an account? Sign in'),
          ),
        ],
      ),
    );
  }

  bool _validate() {
    final email = _email.text.trim();
    final password = _password.text;
    setState(() {
      _emailError = !email.contains('@') ? 'Enter a valid email.' : null;
      _passwordError = password.length < 6
          ? 'Password must be at least 6 characters.'
          : null;
      _confirmationError = password != _confirmation.text
          ? 'Passwords do not match.'
          : null;
    });
    if (!_acceptedTerms) {
      PubgetSnackbars.showError(context, 'Accept the terms to continue.');
    }
    return _emailError == null &&
        _passwordError == null &&
        _confirmationError == null &&
        _acceptedTerms;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    final result = await context.read<AuthProvider>().signUpWithEmail(
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (result is Success) await AppNavigation.go(context, '/onboarding');
  }

  Future<void> _google() async {
    if (!_acceptedTerms) {
      PubgetSnackbars.showError(context, 'Accept the terms to continue.');
      return;
    }
    final result = await context.read<AuthProvider>().signInWithGoogle();
    if (!mounted) return;
    if (result is Success) await AppNavigation.go(context, '/splash');
  }
}
