import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/authentication/auth_validators.dart';

void main() {
  test('email validator trims and requires a domain', () {
    expect(AuthValidators.email('  fan@example.com  '), isNull);
    expect(AuthValidators.email('not-an-email'), 'Enter a valid email.');
    expect(AuthValidators.email('fan@localhost'), 'Enter a valid email.');
    expect(
      AuthValidators.normalizeEmail('  fan@example.com  '),
      'fan@example.com',
    );
  });

  test('password and username rules stay light-touch', () {
    expect(AuthValidators.password('12345'), isNotNull);
    expect(AuthValidators.password('123456'), isNull);
    expect(AuthValidators.confirmation('secret', 'secret'), isNull);
    expect(AuthValidators.confirmation('secret', 'other'), isNotNull);
    expect(AuthValidators.username(''), isNull);
    expect(AuthValidators.username('ab'), isNotNull);
    expect(AuthValidators.username('fan'), isNull);
  });

  test('password strength increases with length and mix', () {
    expect(AuthValidators.passwordStrength(''), PasswordStrength.empty);
    expect(AuthValidators.passwordStrength('abc'), PasswordStrength.short);
    expect(AuthValidators.passwordStrength('abcdef'), PasswordStrength.fair);
    expect(
      AuthValidators.passwordStrength('abcdefg1'),
      PasswordStrength.strong,
    );
  });
}
