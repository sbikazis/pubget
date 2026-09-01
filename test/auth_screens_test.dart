import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/features/authentication/providers/auth_provider.dart';
import 'package:pubget/features/authentication/screens/login_page.dart';
import 'package:pubget/features/authentication/screens/register_page.dart';

import 'authentication_test_support.dart';

void main() {
  testWidgets('login validates before calling authentication', (tester) async {
    final network = NetworkService(probe: () async => true);
    await network.refresh();
    final repository = FakeAuthRepository();
    addTearDown(repository.close);
    addTearDown(network.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NetworkService>.value(value: network),
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(repository: repository),
          ),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
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

  testWidgets('registration requires confirmation and terms', (tester) async {
    final network = NetworkService(probe: () async => true);
    await network.refresh();
    final repository = FakeAuthRepository();
    addTearDown(repository.close);
    addTearDown(network.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NetworkService>.value(value: network),
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(repository: repository),
          ),
        ],
        child: const MaterialApp(home: RegisterPage()),
      ),
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
}
