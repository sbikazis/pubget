import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/firebase_bootstrap.dart';
import 'package:pubget/app/firebase_web_options.dart';

void main() {
  test('unavailable Firebase state is explicit and non-ready', () {
    const state = FirebaseInitializationState.unavailable('missing config');

    expect(state.status, FirebaseInitializationStatus.unavailable);
    expect(state.isReady, isFalse);
    expect(state.message, 'missing config');
  });

  test('initializedForTests is a normal ready state, not an error', () {
    const state = FirebaseInitializationState.initializedForTests();

    expect(state.status, FirebaseInitializationStatus.initialized);
    expect(state.isReady, isTrue);
    expect(state.message, isNull);
  });

  test('web configuration names every required build variable', () {
    expect(
      FirebaseWebOptions.requiredEnvironmentKeys,
      containsAll(<String>[
        'FIREBASE_WEB_API_KEY',
        'FIREBASE_WEB_APP_ID',
        'FIREBASE_WEB_MESSAGING_SENDER_ID',
        'FIREBASE_WEB_PROJECT_ID',
        'FIREBASE_WEB_AUTH_DOMAIN',
      ]),
    );
  });

  test(
    'CoreFirebaseOptions RangeError is mapped away from raw exception text',
    () {
      final error = RangeError.range(14, 0, 13, 'length');

      expect(FirebaseBootstrap.isCoreFirebaseOptionsRangeError(error), isTrue);
      expect(
        FirebaseBootstrap.userFacingInitializationMessage(error),
        FirebaseBootstrap.unexpectedInitializationMessage,
      );
      expect(
        FirebaseBootstrap.userFacingInitializationMessage(error),
        isNot(contains('RangeError')),
      );
    },
  );
}
