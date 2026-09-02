import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/authentication/google_sign_in_config.dart';

void main() {
  test(
    'Google server client ID matches the checked-in Google services file',
    () {
      final services = File(
        'android/app/google-services.json',
      ).readAsStringSync();
      expect(services, contains(GoogleSignInConfig.serverClientId));
      expect(
        GoogleSignInConfig.serverClientId,
        contains('apps.googleusercontent.com'),
      );
      expect(
        GoogleSignInConfig.serverClientId.toLowerCase(),
        isNot(contains('secret')),
      );
      expect(
        GoogleSignInConfig.serverClientId.toLowerCase(),
        isNot(contains('private')),
      );
    },
  );
}
