import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/l10n/app_strings.dart';
import 'package:pubget/features/events/models/event_errors.dart';

void main() {
  final ar = AppStrings.forLocale(const Locale('ar'));
  final en = AppStrings.forLocale(const Locale('en'));

  test('a null failure renders nothing', () {
    expect(eventFailureMessage(ar, null), isEmpty);
  });

  test('non-validation failures map to localized copy, never English message', () {
    final cases = <Failure>[
      const NetworkError(),
      const PermissionError(),
      const RateLimitedError(),
      const NotFoundError(),
      const UnknownError(),
      const TimeoutError(),
    ];
    for (final failure in cases) {
      final arabic = eventFailureMessage(ar, failure);
      expect(arabic, isNotEmpty);
      expect(
        arabic,
        isNot(equals(failure.message)),
        reason: '${failure.runtimeType} leaked the English Failure.message',
      );
      expect(
        arabic,
        isNot(equals(eventFailureMessage(en, failure))),
        reason: '${failure.runtimeType} stayed English under Arabic',
      );
    }
  });

  test('validation failures keep the server ev.* key but translate it', () {
    final arabic = eventFailureMessage(ar, const ValidationError('ev.titleRequired'));
    expect(arabic, ar.eventValidationMessage('ev.titleRequired'));
    expect(arabic, 'العنوان مطلوب.');
  });
}
