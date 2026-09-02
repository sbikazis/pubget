import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/features/authentication/providers/auth_draft_store.dart';
import 'package:pubget/features/authentication/screens/forgot_password_page.dart';
import 'package:pubget/features/authentication/screens/login_page.dart';
import 'package:pubget/features/authentication/screens/onboarding_page.dart';
import 'package:pubget/features/authentication/screens/register_page.dart';
import 'package:pubget/features/authentication/screens/terms_page.dart';
import 'package:pubget/features/authentication/widgets/pubget_torii_mark.dart';

import 'authentication_test_support.dart';

void main() {
  testWidgets('login validates before calling authentication', (tester) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.close);
    await pumpAuthScreen(
      tester,
      child: const LoginPage(),
      repository: repository,
    );

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();

    expect(find.text('Enter a valid email.'), findsOneWidget);
    expect(
      find.text('Password must be at least 6 characters.'),
      findsOneWidget,
    );
    expect(repository.user, isNull);
  });

  testWidgets('login does not treat unresolved network as offline', (
    tester,
  ) async {
    final network = NetworkService(probe: () async => false);
    addTearDown(network.dispose);
    await pumpAuthScreen(tester, child: const LoginPage(), network: network);

    expect(find.text('You are offline'), findsNothing);
    final signIn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(signIn.onPressed, isNotNull);
  });

  testWidgets('registration requires confirmation and terms', (tester) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.close);
    await pumpAuthScreen(
      tester,
      child: const RegisterPage(),
      repository: repository,
    );

    await tester.enterText(
      find.byKey(const Key('register-email')),
      'fan@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register-password')),
      'password',
    );
    await tester.enterText(
      find.byKey(const Key('register-confirmation')),
      'different',
    );
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(find.text('Accept the terms to continue.'), findsOneWidget);
    expect(repository.user, isNull);
  });

  testWidgets('terms sheet can accept without leaving registration', (
    tester,
  ) async {
    await pumpAuthScreen(tester, child: const RegisterPage());

    await tester.ensureVisible(find.text('Read the terms'));
    await tester.tap(find.text('Read the terms'));
    await tester.pumpAndSettle();

    expect(find.text('Your account'), findsOneWidget);
    await tester.ensureVisible(find.text('I agree'));
    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('forgot password validates email before sending', (tester) async {
    await pumpAuthScreen(tester, child: const ForgotPasswordPage());

    await tester.tap(find.byKey(const Key('forgot-submit')));
    await tester.pump();

    expect(find.text('Enter a valid email.'), findsOneWidget);
  });

  testWidgets('forgot password shows sent state', (tester) async {
    final draft = AuthDraftStore()..setEmail('fan@example.com');
    await pumpAuthScreen(
      tester,
      child: const ForgotPasswordPage(),
      draft: draft,
    );

    await tester.tap(find.byKey(const Key('forgot-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsOneWidget);
    expect(find.text('fan@example.com'), findsOneWidget);
  });

  testWidgets('terms page shows draft community copy', (tester) async {
    await pumpAuthScreen(tester, child: const TermsPage());
    expect(find.text('Your account'), findsOneWidget);
    expect(find.textContaining('before public launch'), findsWidgets);
  });

  testWidgets('onboarding continue validates a short username', (tester) async {
    await pumpAuthScreen(tester, child: const OnboardingPage());

    await tester.enterText(find.byKey(const Key('onboarding-username')), 'ab');
    await tester.ensureVisible(find.byKey(const Key('onboarding-continue')));
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pump();

    expect(find.text('Use at least 3 characters.'), findsOneWidget);
    expect(find.text('What do you love?'), findsNothing);
  });

  testWidgets('onboarding continue opens interests without a username', (
    tester,
  ) async {
    await pumpAuthScreen(tester, child: const OnboardingPage());

    await tester.ensureVisible(find.byKey(const Key('onboarding-continue')));
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();

    expect(find.text('What do you love?'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-save')), findsOneWidget);
  });

  testWidgets('login and register show the torii brand mark', (tester) async {
    await pumpAuthScreen(tester, child: const LoginPage());
    expect(find.byType(PubgetToriiMark), findsWidgets);
  });

  testWidgets('login surfaces a compact auth failure', (tester) async {
    final repository = FakeAuthRepository(
      authFailure: const ValidationError('The email or password is incorrect.'),
    );
    addTearDown(repository.close);
    await pumpAuthScreen(
      tester,
      child: const LoginPage(),
      repository: repository,
    );

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'fan@example.com',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'password');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Sign-in failed'), findsOneWidget);
    expect(find.text('The email or password is incorrect.'), findsOneWidget);
  });

  testWidgets('login does not show a RangeError as the user-facing message', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      authFailure: const UnknownError('Unexpected authentication error.'),
    );
    addTearDown(repository.close);
    await pumpAuthScreen(
      tester,
      child: const LoginPage(),
      repository: repository,
    );

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'fan@example.com',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'password');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('RangeError'), findsNothing);
    expect(find.text('Unexpected authentication error.'), findsOneWidget);
  });

  testWidgets('login ignores duplicate submits while loading', (tester) async {
    final repository = FakeAuthRepository()
      ..authDelay = const Duration(milliseconds: 400);
    addTearDown(repository.close);
    await pumpAuthScreen(
      tester,
      child: const LoginPage(),
      repository: repository,
    );

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'fan@example.com',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'password');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(repository.emailSignInCalls, 1);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('login and register keep the Pubget identity in dark mode', (
    tester,
  ) async {
    await pumpAuthScreen(
      tester,
      child: const LoginPage(),
      themeMode: ThemeMode.dark,
    );
    expect(find.text('PUBGET'), findsOneWidget);
    expect(find.text('Premium Anime Community'), findsOneWidget);
    expect(find.byType(PubgetToriiMark), findsWidgets);

    await pumpAuthScreen(
      tester,
      child: const RegisterPage(),
      themeMode: ThemeMode.dark,
    );
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.byType(PubgetToriiMark), findsWidgets);
  });

  testWidgets('login supports RTL layout', (tester) async {
    await pumpAuthScreen(
      tester,
      child: const LoginPage(),
      textDirection: TextDirection.rtl,
    );
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
  });
}
