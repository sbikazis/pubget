abstract final class AuthValidators {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String normalizeEmail(String value) => value.trim();

  static String? email(String value) {
    final email = normalizeEmail(value);
    if (email.isEmpty || !_emailPattern.hasMatch(email)) {
      return 'Enter a valid email.';
    }
    return null;
  }

  static String? password(String value) {
    if (value.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  static String? confirmation(String password, String confirmation) {
    if (password != confirmation) {
      return 'Passwords do not match.';
    }
    return null;
  }

  static String? username(String value) {
    final username = value.trim();
    if (username.isEmpty) return null;
    if (username.length < 3) {
      return 'Use at least 3 characters.';
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
