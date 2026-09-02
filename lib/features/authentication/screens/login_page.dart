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
import 'auth_page_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _email;
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final network = context.watch<NetworkService>();
    final loading = auth.isBusy;
    final offline = network.isOffline;
    return AuthPageShell(
      title: 'Welcome back',
      subtitle:
          'Sign in to continue your story in the premium anime community.',
      footer: PubgetTextButton(
        onPressed: loading
            ? null
            : () => AppNavigation.go(context, '/register'),
        semanticLabel: 'Create a new account',
        child: const Text('New to Pubget? Create an account'),
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (offline)
              const PubgetInlineBanner(
                title: 'You are offline',
                message: 'Reconnect before signing in.',
                icon: Icons.cloud_off_outlined,
              )
            else if (auth.failure != null)
              PubgetInlineBanner.error(
                title: 'Sign-in failed',
                message: auth.failure!.message,
              ),
            if (offline || auth.failure != null)
              const SizedBox(height: AppSpacing.md),
            PubgetTextField(
              key: const Key('login-email'),
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
              key: const Key('login-password'),
              controller: _password,
              label: 'Password',
              errorText: _passwordError,
              enabled: !loading,
              onSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: PubgetTextButton(
                onPressed: loading ? null : _openReset,
                semanticLabel: 'Reset forgotten password',
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            PubgetPrimaryButton(
              key: const Key('login-submit'),
              onPressed: offline || loading ? null : _submit,
              semanticLabel: 'Sign in with email',
              loading: loading,
              child: const Text('Sign in'),
            ),
            const SizedBox(height: AppSpacing.lg),
            const AuthOrDivider(),
            const SizedBox(height: AppSpacing.lg),
            AuthGoogleButton(
              onPressed: offline || loading ? null : _signInWithGoogle,
              semanticLabel: 'Continue with Google',
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'You stay signed in on this device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  bool _validate() {
    setState(() {
      _emailError = AuthValidators.email(_email.text);
      _passwordError = AuthValidators.password(_password.text);
    });
    return _emailError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    final result = await context.read<AuthProvider>().signInWithEmail(
      email: AuthValidators.normalizeEmail(_email.text),
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

  Future<void> _openReset() async {
    context.read<AuthDraftStore>().setEmail(_email.text);
    await AppNavigation.go(context, '/forgot-password');
  }
}
