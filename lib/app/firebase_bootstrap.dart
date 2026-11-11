import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_web_options.dart';

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

/// Initializes Firebase from native platform files or verified web build-time
/// configuration. No Firebase client configuration is hard-coded here.
abstract final class FirebaseBootstrap {
  static const unexpectedInitializationMessage =
      'Pubget could not start Firebase on this device.';
  static const webAppCheckSiteKey = String.fromEnvironment(
    'FIREBASE_APP_CHECK_WEB_RECAPTCHA_SITE_KEY',
  );

  /// A release web build must provide its registered reCAPTCHA site key.
  /// Debug web builds use the App Check debug provider instead.
  @visibleForTesting
  static bool canActivateWebAppCheck({
    required bool isDebug,
    required String siteKey,
  }) => isDebug || siteKey.trim().isNotEmpty;

  static Future<FirebaseInitializationState> initialize() async {
    if (kIsWeb) {
      final options = FirebaseWebOptions.current;
      if (options == null) {
        final missing = FirebaseWebOptions.missingEnvironmentKeys.join(', ');
        return FirebaseInitializationState.unavailable(
          'Firebase Web options are not configured for this project.',
          diagnosticMessage: 'Missing build variables: $missing',
        );
      }

      return _initialize(options: options);
    }

    return _initialize();
  }

  static Future<FirebaseInitializationState> _initialize({
    FirebaseOptions? options,
  }) async {
    try {
      final app = Firebase.apps.isNotEmpty
          ? Firebase.app()
          : await Firebase.initializeApp(options: options);
      // App Check is defense-in-depth. A provider/configuration outage must
      // not turn a healthy Firebase initialization into an app-wide outage.
      await _activateAppCheck();
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

  static Future<void> _activateAppCheck() async {
    if (kIsWeb &&
        !canActivateWebAppCheck(
          isDebug: kDebugMode,
          siteKey: webAppCheckSiteKey,
        )) {
      debugPrint(
        'Firebase App Check is not activated: '
        'FIREBASE_APP_CHECK_WEB_RECAPTCHA_SITE_KEY is missing.',
      );
      return;
    }

    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        providerWeb: kIsWeb
            ? (kDebugMode
                ? WebDebugProvider()
                : ReCaptchaV3Provider(webAppCheckSiteKey))
            : null,
      );
    } catch (error, stackTrace) {
      // Do not log tokens or secrets. Keep Firebase available while the
      // staged rollout is being observed and the provider setup is completed.
      debugPrint('Firebase App Check activation failed: $error');
      debugPrint('$stackTrace');
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
