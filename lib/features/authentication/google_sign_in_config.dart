/// Public Google Sign-In identifiers already present in
/// `android/app/google-services.json`. These are OAuth client IDs, not secrets.
abstract final class GoogleSignInConfig {
  /// Web client ID (`client_type` 3). Android needs this to mint a Firebase
  /// ID token. Copied from the checked-in Google services file so the Flutter
  /// client does not depend on generated XML at runtime.
  static const serverClientId =
      '452313838148-6m1jvpqea9suqn6t14gv98r9h4gacsls.apps.googleusercontent.com';
}
