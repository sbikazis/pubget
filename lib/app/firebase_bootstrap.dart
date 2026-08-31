import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

enum FirebaseInitializationStatus { initialized, unavailable }

final class FirebaseInitializationState {
  const FirebaseInitializationState._({
    required this.status,
    this.app,
    this.message,
  });

  const FirebaseInitializationState.initialized(FirebaseApp app)
    : this._(status: FirebaseInitializationStatus.initialized, app: app);

  const FirebaseInitializationState.unavailable(String message)
    : this._(
        status: FirebaseInitializationStatus.unavailable,
        message: message,
      );

  final FirebaseInitializationStatus status;
  final FirebaseApp? app;
  final String? message;

  bool get isReady =>
      status == FirebaseInitializationStatus.initialized && app != null;
}

/// Initializes Firebase using the native platform configuration already
/// checked into the project. There is intentionally no invented environment
/// switch or hard-coded Firebase configuration in the new application.
abstract final class FirebaseBootstrap {
  static Future<FirebaseInitializationState> initialize() async {
    if (kIsWeb) {
      return const FirebaseInitializationState.unavailable(
        'Firebase Web options are not configured for this project.',
      );
    }

    try {
      final app = Firebase.apps.isNotEmpty
          ? Firebase.app()
          : await Firebase.initializeApp();
      return FirebaseInitializationState.initialized(app);
    } on FirebaseException catch (error) {
      return FirebaseInitializationState.unavailable(
        '${error.code}: ${error.message ?? 'Firebase initialization failed.'}',
      );
    } catch (error) {
      return FirebaseInitializationState.unavailable(error.toString());
    }
  }
}
