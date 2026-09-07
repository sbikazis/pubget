import '../../core/l10n/app_strings.dart';

abstract final class AuthValidators {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String normalizeEmail(String value) => value.trim();

  static String? email(String value, [AppStrings copy = AppStrings.english]) {
    final email = normalizeEmail(value);
    if (email.isEmpty || !_emailPattern.hasMatch(email)) {
      return copy.emailInvalid;
    }
    return null;
  }

  static String? password(String value, [AppStrings copy = AppStrings.english]) {
    if (value.length < 6) {
      return copy.passwordTooShort;
    }
    return null;
  }

  static String? confirmation(
    String password,
    String confirmation, [
    AppStrings copy = AppStrings.english,
  ]) {
    if (password != confirmation) {
      return copy.passwordsDoNotMatch;
    }
    return null;
  }

  static String? username(String value, [AppStrings copy = AppStrings.english]) {
    final username = value.trim();
    if (username.isEmpty) return null;
    if (username.length < 3) {
      return copy.usernameTooShort;
    }
    return null;
  }

  static PasswordStrength passwordStrength(String value) {
    if (value.isEmpty) return PasswordStrength.empty;
    if (value.length < 6) return PasswordStrength.short;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    if (value.length >= 8 && hasLetter && hasDigit) {
      return PasswordStrength.strong;
    }
    return PasswordStrength.fair;
  }
}

enum PasswordStrength { empty, short, fair, strong }
