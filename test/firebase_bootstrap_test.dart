import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/firebase_bootstrap.dart';

void main() {
  test('unavailable Firebase state is explicit and non-ready', () {
    const state = FirebaseInitializationState.unavailable('missing config');

    expect(state.status, FirebaseInitializationStatus.unavailable);
    expect(state.isReady, isFalse);
    expect(state.message, 'missing config');
  });
}
