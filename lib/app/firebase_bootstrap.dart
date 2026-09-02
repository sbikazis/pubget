import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

enum FirebaseInitializationStatus { initialized, unavailable }

final class FirebaseInitializationState {
  const FirebaseInitializationState._({
    required this.status,
    this.app,
    this.message,
    this.diagnosticMessage,
  });

  const FirebaseInitializationState.initialized(FirebaseApp app)
    : this._(status: FirebaseInitializationStatus.initialized, app: app);

  const FirebaseInitializationState.unavailable(
    String message, {
    String? diagnosticMessage,
  }) : this._(
         status: FirebaseInitializationStatus.unavailable,
         message: message,
         diagnosticMessage: diagnosticMessage,
       );

  /// Test-only ready state that does not require a live [FirebaseApp].
  @visibleForTesting
  const FirebaseInitializationState.initializedForTests()
    : this._(status: FirebaseInitializationStatus.initialized);

  final FirebaseInitializationStatus status;
  final FirebaseApp? app;
  final String? message;
  final String? diagnosticMessage;

  bool get isReady => status == FirebaseInitializationStatus.initialized;
}

/// Initializes Firebase using the native platform configuration already
/// checked into the project. There is intentionally no invented environment
/// switch or hard-coded Firebase configuration in the new application.
abstract final class FirebaseBootstrap {
  static const unexpectedInitializationMessage =
      'Pubget could not start Firebase on this device.';

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
    } on FirebaseException catch (error, stackTrace) {
      _logInitializationFailure(error, stackTrace);
      return FirebaseInitializationState.unavailable(
        unexpectedInitializationMessage,
        diagnosticMessage: '${error.code}: ${error.message}',
      );
    } catch (error, stackTrace) {
      _logInitializationFailure(error, stackTrace);
      return FirebaseInitializationState.unavailable(
        userFacingInitializationMessage(error),
        diagnosticMessage: error.toString(),
      );
    }
  }

  /// Maps the known FlutterFire CoreFirebaseOptions pigeon mismatch
  /// (`RangeError` reading index 14 from a 14-field native list) and any other
  /// unexpected init failure into a clean user-facing sentence.
  static String userFacingInitializationMessage(Object error) {
    if (isCoreFirebaseOptionsRangeError(error)) {
      return unexpectedInitializationMessage;
    }
    return unexpectedInitializationMessage;
  }

  /// The production Android APK showed:
  /// `RangeError (length): Invalid value: Not in inclusive range 0..13: 14`
  /// while decoding native `CoreFirebaseOptions` (14 fields, Dart expected 15).
  static bool isCoreFirebaseOptionsRangeError(Object error) {
    if (error is! RangeError) return false;
    final text = error.toString();
    return text.contains('0..13') && text.contains(': 14');
  }

  static void _logInitializationFailure(Object error, StackTrace stackTrace) {
    debugPrint('Firebase initialization failed: $error');
    debugPrint('$stackTrace');
  }
}
