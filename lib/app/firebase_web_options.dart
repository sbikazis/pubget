import 'package:firebase_core/firebase_core.dart';

/// Firebase Web configuration supplied at build time by Replit.
///
/// Firebase client configuration is embedded in every web build by design, but
/// keeping it out of source control prevents this repository from becoming the
/// configuration source of truth. The Replit workflow passes these values with
/// `--dart-define`.
abstract final class FirebaseWebOptions {
  static const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_WEB_MESSAGING_SENDER_ID',
  );
  static const projectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
  static const authDomain = String.fromEnvironment(
    'FIREBASE_WEB_AUTH_DOMAIN',
  );
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_WEB_STORAGE_BUCKET',
  );
  static const measurementId = String.fromEnvironment(
    'FIREBASE_WEB_MEASUREMENT_ID',
  );

  static const requiredEnvironmentKeys = <String>[
    'FIREBASE_WEB_API_KEY',
    'FIREBASE_WEB_APP_ID',
    'FIREBASE_WEB_MESSAGING_SENDER_ID',
    'FIREBASE_WEB_PROJECT_ID',
    'FIREBASE_WEB_AUTH_DOMAIN',
  ];

  static List<String> get missingEnvironmentKeys {
    const values = <String>[
      apiKey,
      appId,
      messagingSenderId,
      projectId,
      authDomain,
    ];

    return [
      for (var index = 0; index < values.length; index++)
        if (values[index].trim().isEmpty) requiredEnvironmentKeys[index],
    ];
  }

  static FirebaseOptions? get current {
    if (missingEnvironmentKeys.isNotEmpty) return null;

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      measurementId: measurementId.isEmpty ? null : measurementId,
    );
  }
}