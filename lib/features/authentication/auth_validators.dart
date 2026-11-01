import '../../core/l10n/app_strings.dart';

abstract final class AuthValidators {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _letter = RegExp(r'^\p{L}$', unicode: true);
  static final _usernameChars = RegExp(r'^[\p{L}\p{N}._-]+$', unicode: true);

  static const usernameMinLength = 3;
  static const usernameMaxLength = 20;

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

  /// Local username format validation (spec §3.2). Empty input is considered
  /// valid (`null`) so screens can distinguish "not entered" from "invalid".
  static String? username(String value, [AppStrings copy = AppStrings.english]) {
    final username = value.trim();
    if (username.isEmpty) return null;
    if (username.length < usernameMinLength) return copy.usernameTooShort;
    if (username.length > usernameMaxLength) return copy.usernameTooLong;
    if (!_letter.hasMatch(username.substring(0, 1))) {
      return copy.usernameInvalidStart;
    }
    if (!_usernameChars.hasMatch(username)) return copy.usernameInvalidCharacters;
    return null;
  }

  /// Server-side canonical form used for uniqueness comparisons. Keeps the
  /// user's casing for display; a lowercased key is what the registry claims.
  static String canonicalUsername(String value) => value.trim().toLowerCase();

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
