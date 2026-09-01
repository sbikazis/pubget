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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final network = context.watch<NetworkService>();
    final loading = auth.state == LoadingState.loading;
    return AuthPageShell(
      title: 'Welcome back',
      subtitle: 'Sign in to continue your Pubget story.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!network.isOnline) ...[
            const PubgetOfflineState(
              title: 'You are offline',
              message: 'Reconnect before signing in.',
            ),
            const SizedBox(height: AppSpacing.md),
          ] else if (auth.failure != null) ...[
            PubgetErrorState(
              title: 'Sign-in failed',
              message: auth.failure!.message,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          PubgetTextField(
            key: const Key('login-email'),
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            errorText: _emailError,
            enabled: !loading,
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextField(
            key: const Key('login-password'),
            controller: _password,
            label: 'Password',
            obscureText: _hidePassword,
            textInputAction: TextInputAction.done,
            errorText: _passwordError,
            enabled: !loading,
            onSubmitted: (_) => _submit(),
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
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: PubgetTextButton(
              onPressed: loading ? null : _resetPassword,
              semanticLabel: 'Reset forgotten password',
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PubgetPrimaryButton(
            key: const Key('login-submit'),
            onPressed: !network.isOnline || loading ? null : _submit,
            semanticLabel: 'Sign in with email',
            loading: loading,
            child: const Text('Sign in'),
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetSecondaryButton(
            onPressed: !network.isOnline || loading ? null : _signInWithGoogle,
            semanticLabel: 'Continue with Google',
            leadingIcon: Icons.account_circle_outlined,
            child: const Text('Continue with Google'),
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetTextButton(
            onPressed: loading
                ? null
                : () => AppNavigation.go(context, '/register'),
            semanticLabel: 'Create a new account',
            child: const Text('New to Pubget? Create an account'),
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
    });
    return _emailError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    final result = await context.read<AuthProvider>().signInWithEmail(
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (result is Success) await AppNavigation.go(context, '/splash');
  }

  Future<void> _signInWithGoogle() async {
    final result = await context.read<AuthProvider>().signInWithGoogle();
    if (!mounted) return;
    if (result is Success) await AppNavigation.go(context, '/splash');
  }

  Future<void> _resetPassword() async {
    if (!_email.text.contains('@')) {
      setState(() => _emailError = 'Enter your email first.');
      return;
    }
    final result = await context.read<AuthProvider>().sendPasswordResetEmail(
      email: _email.text,
    );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) =>
          PubgetSnackbars.showSuccess(context, 'Password reset email sent.'),
      onFailure: (failure) =>
          PubgetSnackbars.showError(context, failure.message),
    );
  }
}
